#!/usr/bin/perl

# SVN ID: $Id$

package MrVoice::XMLRPC::Server;
use warnings;
use strict;

use DBI;
use Digest::MD5 qw(md5_hex);
use File::Spec::Functions;
use File::Basename;

my $db_name = "mrvoice";
my $db_user = "mrvoice";
my $db_pass = "mrvoice";

my $upload_path = "/usr/www/mrvoice.net/htdocs/online/mp3";

sub check_version
{
    my $class = shift;
    my $args  = shift;

    die "ERROR: Must supply your current version"  unless $args->{version};
    die "ERROR: Must supply your operating system" unless $args->{os};

    my %versions;

    open( my $fh, "<", "versiontbl.txt" )
      or die "Couldn't open the version table";
    while ( my $line = <$fh> )
    {
        chomp $line;
        my ( $key, $val ) = split( /::/, $line );
        $versions{$key} = $val;
    }

    my $os = $args->{os};
    if ( $versions{$os} gt $args->{version} )
    {
        return {
            needupgrade => 1,
            message     =>
              "The latest version of Mr. Voice for $os is $versions{$os}.  You can upgrade from http://www.mrvoice.net/"
        };
    }
    else
    {
        return { needupgrade => 0 };
    }

}

sub check_upload
{

    # Checks to see if you would be able to upload the associated file
    my $class = shift;
    my $args  = shift;
    die "ERROR: Must have an authorization key to upload\n"
      unless $args->{online_key};
    die "ERROR: Must supply a title\n"          unless $args->{title};
    die "ERROR: Must supply a filename\n"       unless $args->{filename};
    die "ERROR: Could not write to upload path" unless ( -w $upload_path );

    my $dbh = DBI->connect( "DBI:mysql:$db_name", $db_user, $db_pass )
      or die "ERROR: Couldn't connect to database\n";

    check_key( $args->{online_key}, $dbh );

    my $query = "SELECT * FROM mrvoice WHERE md5 = '$args->{md5sum}'";
    my $sth   = $dbh->prepare($query)
      or die "ERROR: Could not prepare query $query\n";
    $sth->execute;

    my $numrows = $sth->rows;

    die
      "ERROR: A file with MD5 sum $args->{md5sum} already exists in the database\n"
      if $numrows > 0;

    return 1;
}

sub upload_song
{
    my $class = shift;
    my $args  = shift;

    # Check for error conditions
    eval { check_upload( undef, $args ) };
    die "ERROR: Upload check failed with error: $@\n" if $@;
    die "ERROR: Must supply file\n" unless $args->{file};

    my $bindata = $args->{file};

    die "ERROR: MD5 sums do not match for file"
      unless ( md5_hex($bindata) eq $args->{md5sum} );

    my $dbh = DBI->connect( "DBI:mysql:$db_name", $db_user, $db_pass )
      or die "ERROR: Couldn't connect to database\n";

    my $keyinfo = check_key( $args->{online_key}, $dbh );

    # We've made it this far - let's upload the song.
    my $file_bin = $args->{file}
      or die "ERROR: Could not decode encoded file";

    my $sth =
      $dbh->prepare(
        "INSERT INTO mrvoice VALUES (NULL,?,?,'UPLD',?,?,?,NULL,?,?,?)")
      or die "ERROR: Could not prepare database query: " . $dbh->errstr;

    my $filename =
      build_filename( $args->{filename}, $args->{title}, $args->{artist} );

    open( my $out_fh, ">", "$upload_path/$filename" )
      or die "ERROR: Couldn't open new file for writing\n";
    print $out_fh $bindata;
    close($out_fh);

    $ENV{PATH} = "/bin:/usr/bin";
    my $time =
      `/usr/www/mrvoice.net/htdocs/online/get-time.pl $upload_path/$filename`;

    $sth->execute( $args->{title}, $args->{artist}, $args->{info}, $filename,
        $time, $keyinfo->{id}, $args->{md5sum}, $args->{publisher} )
      or die "ERROR: Could not execute query: " . $dbh->errstr;

    return $dbh->{'mysql_insertid'};

}

sub search_songs
{
    open( my $fh, ">", "/tmp/xmlrpc.log" ) or die;
    my $class = shift;
    my $args  = shift;

    my @results;

    my $dbh = DBI->connect( "DBI:mysql:$db_name", $db_user, $db_pass )
      or die "ERROR: Couldn't connect to database\n";

    check_key( $args->{online_key}, $dbh );

    my $search_key = $args->{search_term};

    my $query =
      "SELECT mrvoice.id,categories.description,mrvoice.info,mrvoice.artist,mrvoice.title,mrvoice.filename,mrvoice.time,mrvoice.publisher,mrvoice.md5 FROM mrvoice,categories WHERE mrvoice.category=categories.code ";
    $query .=
      "AND ( info LIKE '%$search_key%' OR title LIKE '%$search_key%' OR artist LIKE '%$search_key%') "
      if $search_key;

    $query .= "AND mrvoice.person = '$args->{person}' "
      if ( $args->{person} && $args->{person} ne "any" );
    $query .= "AND mrvoice.category = '$args->{category}' "
      if ( $args->{category} && $args->{category} ne "any" );
    $query .= "ORDER BY category,info,title";

    print $fh "QUERY IS $query\n";

    my $sth = $dbh->prepare($query) or die "ERROR: Could not prepare query\n";
    $sth->execute or die "Couldn't execute query\n";

    while ( my $row_hashref = $sth->fetchrow_hashref )
    {
        my $string = "($row_hashref->{description}";
        $string = $string . " - $row_hashref->{info}"
          if ( $row_hashref->{info} );
        $string = $string . ") - \"$row_hashref->{title}\"";
        $string = $string . " by $row_hashref->{artist}"
          if ( $row_hashref->{artist} );
        $string = $string . " $row_hashref->{time}";
        $string = $string . " ($row_hashref->{publisher})"
          if ( $args->{show_publisher} == 1 );
        print $fh "Got id $row_hashref->{id} and string $string\n";

        push(
            @results,
            {
                id     => $row_hashref->{id},
                md5    => $row_hashref->{md5},
                string => $string
            }
        );
    }

    print $fh "Results are @results\n";
    return \@results;

}

sub download_song
{
    my $class = shift;
    my $args  = shift;

    my $dbh = DBI->connect( "DBI:mysql:$db_name", $db_user, $db_pass )
      or die "ERROR: Couldn't connect to database\n";

    check_key( $args->{online_key}, $dbh );

    my $query = "SELECT * FROM mrvoice WHERE id=$args->{song_id}";
    my $sth = $dbh->prepare($query) or die "Could not prepare query\n";
    $sth->execute
      or die "Could not execute query -->$query<--: ", $dbh->errstr, "\n";

    my $ref = $sth->fetchrow_hashref
      or die "No data returned for id $args->{song_id}\n";

    die "Cannot find the file on disk\n"
      unless ( -r "$upload_path/$ref->{filename}" );

    my $bindata;

    {
        open( my $in_fh, "<", "$upload_path/$ref->{filename}" ) or die;
        binmode($in_fh);
        local $/ = undef;
        $bindata = <$in_fh>;
    }

    $ref->{encoded_data} = $bindata;

    return $ref;
}

sub get_people
{
    my $class = shift;
    my $args  = shift;

    open( my $fh, ">", "/tmp/debug.log" ) or die;

    print $fh "My class is $class\n";

    my @people = ( { id => 'any', name => 'Anyone' } );

    my $dbh = DBI->connect( "DBI:mysql:$db_name", $db_user, $db_pass )
      or die "ERROR: Couldn't connect to database\n";

    check_key( $args->{online_key}, $dbh );

    my $query = "SELECT * FROM online_keys ORDER BY name";
    my $people_hashref = $dbh->selectall_hashref( $query, "id" )
      or die "ERROR: Couldn't selectall_hashref on query $query\n";

    $people_hashref->{any} = { id => 'any', name => 'Any Person' };
    return $people_hashref;
}

sub get_categories
{
    my $class = shift;
    my $args  = shift;

    my @categories = ( { code => 'any', description => 'Any Category' } );

    my $dbh = DBI->connect( "DBI:mysql:$db_name", $db_user, $db_pass )
      or die "ERROR: Couldn't connect to database\n";

    check_key( $args->{online_key}, $dbh );

    my $query = "SELECT * FROM categories ORDER BY description";
    my $cat_hashref = $dbh->selectall_hashref( $query, "code" )
      or die "ERROR: Couldn't selectall_hashref on query $query\n";

    $cat_hashref->{any} = { code => 'any', description => 'Any Category' };
    return $cat_hashref;
}

###########

sub build_filename
{
    my ( $oldfilename, $title, $artist ) = @_;
    my $newfilename;

    if ($artist)
    {
        $newfilename = "$artist-$title";
    }
    else
    {
        $newfilename = $title;
    }
    $newfilename =~ s/[^a-zA-Z0-9\-]//g;

    my ( $name, $path, $extension ) = fileparse( $oldfilename, '\.\w+' );
    $extension = lc($extension);

    if ( -e catfile( $upload_path, "$newfilename$extension" ) )
    {

        my $i = 0;
        while ( 1 == 1 )
        {
            if ( !-e catfile( $upload_path, "$newfilename-$i$extension" ) )
            {
                $newfilename = "$newfilename-$i";
                last;
            }
            $i++;
        }
    }

    $newfilename = "$newfilename$extension";

    return ($newfilename);
}

sub check_key
{
    my $key = shift;
    my $dbh = shift;

    die "ERROR: Must have an authorization key to search\n"
      unless $key;

    my $sth = $dbh->prepare("SELECT * FROM online_keys WHERE key_id = '$key'");
    $sth->execute;
    if ( my $row = $sth->fetchrow_hashref )
    {
        return $row;
    }
    else
    {
        die
          "ERROR: Online Key not valid.  Email Wade at minter\@mrvoice.net to get a key.\n";
    }
}

1;
