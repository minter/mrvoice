#!/usr/bin/perl

# SVN ID: $Id$

use warnings;
use strict;

use DBI;
use Date::Manip;
use Text::Wrapper;

our %config;       # Configuration hash
our $mw;           # Tk MainWindow
our $icon;         # Window icon
our $homedir;      # Unix home directory
our $mysql_dbh;    # MySQL database handle
our $rcfile;       # Config file
our $wrapper = Text::Wrapper->new;

sub get_dbdir
{
    my $homedir;
    if ( $^O eq "MSWin32" )
    {
        $homedir = "C:/";
    }
    else
    {
        $homedir = "~";
        $homedir =~ s{ ^ ~ ( [^/]* ) }
              { $1
                   ? (getpwnam($1))[7]
                   : ( $ENV{HOME} || $ENV{LOGDIR}
                        || (getpwuid($>))[7]
                     )
              }ex;
    }
    return $homedir;
}

sub save_rcfile
{
    if ( !open( RCFILE, ">$rcfile" ) )
    {
        die
          "Could not open $rcfile for writing. Your preferences will not be saved\n";
    }
    else
    {
        foreach my $key ( sort keys %config )
        {
            print RCFILE "$key" . "::$config{$key}\n";
        }
        close(RCFILE);
    }
}

sub create_new_database
{
    if ( -r $config{db_file} )
    {
        die
          "A file already exists at $config{db_file} - are you sure you haven't tried to upgrade before?  Remove this file before attempting to upgrade.\n";
    }
    my $create_dbh;
    my @queries;
    if (
        !(
            $create_dbh =
            DBI->connect( "dbi:SQLite:dbname=$config{db_file}", "", "" )
        )
      )
    {
        die "Could not create new database file $config{db_file} via DBI";
    }

    my $query;
    while ( my $line = <DATA> )
    {
        chomp($line);
        next if ( ( $line =~ /^\s*#/ ) || ( $line =~ /^\s+$/ ) );

        if ( $line =~ /\);/ )
        {
            push( @queries, "$query \)\;" );
            $query = "";
        }
        else
        {
            $query .= $line;
        }
    }

    foreach my $query (@queries)
    {
        my $sth = $create_dbh->prepare($query);
        $sth->execute or die "Could not run database query $query";
    }
}

sub read_rcfile
{
    if ( $^O eq "MSWin32" )
    {
        $rcfile = "C:\\mrvoice.cfg";

        # You have to manually set the time zone for Windows.
        my ( $l_min, $l_hour, $l_year, $l_yday ) =
          ( localtime $^T )[ 1, 2, 5, 7 ];
        my ( $g_min, $g_hour, $g_year, $g_yday ) = ( gmtime $^T )[ 1, 2, 5, 7 ];
        my $tzval =
          ( $l_min - $g_min ) / 60 + $l_hour - $g_hour + 24 *
          ( $l_year <=> $g_year || $l_yday <=> $g_yday );
        $tzval = sprintf( "%2.2d00", $tzval );
        Date_Init("TZ=$tzval");

    }
    else
    {
        our $homedir = "~";
        $homedir =~ s{ ^ ~ ( [^/]* ) }
              { $1
                   ? (getpwnam($1))[7]
                   : ( $ENV{HOME} || $ENV{LOGDIR}
                        || (getpwuid($>))[7]
                     )
              }ex;
        $rcfile = "$homedir/.mrvoicerc";
    }

    # Opens the configuration file, of the form var_name::value, and assigns
    # the value to the variable name.
    # On MS Windows, it also converts long pathnames to short ones.

    if ( -r $rcfile )
    {
        open( RCFILE, $rcfile );
        while (<RCFILE>)
        {
            chomp;
            my ( $key, $value ) = split(/::/);
            $config{$key} = $value;
        }
        close(RCFILE);
        return (1);
    }
    else
    {
        return (0);
    }
    if ( $^O eq "MSWin32" )
    {
        $config{'filepath'}  = Win32::GetShortPathName( $config{'filepath'} );
        $config{'savedir'}   = Win32::GetShortPathName( $config{'savedir'} );
        $config{'mp3player'} = Win32::GetShortPathName( $config{'mp3player'} );
    }
    else
    {
        $config{'savedir'} =~ s#(.*)/$#$1#;
    }

}

sub upgrade_20
{

    # This migrates the database from MySQL to SQLite

    my $sqlite_dbh =
      DBI->connect( "dbi:SQLite:dbname=$config{db_file}", "", "" )
      or die
      "Could not connect to SQLite database $config{db_file} - error $DBI::errstr\n\n";

    my $mysql_cats = "SELECT * FROM categories";
    my $cats_sth   = $mysql_dbh->prepare($mysql_cats);
    $cats_sth->execute;

    while ( my $in = $cats_sth->fetchrow_hashref )
    {
        my $code        = $sqlite_dbh->quote( $in->{code} );
        my $description = $sqlite_dbh->quote( $in->{description} );

        my $outquery   = "INSERT INTO categories VALUES ($code,$description)";
        my $sqlite_sth = $sqlite_dbh->prepare($outquery);
        $sqlite_sth->execute or die "Died on query -->$outquery<-- $!";
    }

    my $mysql_query = "SELECT * FROM mrvoice";
    my $mysql_sth   = $mysql_dbh->prepare($mysql_query);
    $mysql_sth->execute;

    my $insert_count = 0;
    $sqlite_dbh->do("BEGIN");
    while ( my $in = $mysql_sth->fetchrow_hashref )
    {
        my $title    = $sqlite_dbh->quote( $in->{title} );
        my $artist   = $sqlite_dbh->quote( $in->{artist} );
        my $category = $sqlite_dbh->quote( $in->{category} );
        my $info     = $sqlite_dbh->quote( $in->{info} );
        my $time     = $in->{time} ? $in->{time} : "[??:??]";
        my $pub      = $in->{publisher} ? $in->{publisher} : "OTHER";

        $in->{modtime} =~ /(\d\d)(\d\d)(\d\d)/;
        my ( $year, $month, $day ) = ( $1, $2, $3 );
        my $epoch = UnixDate( ParseDate("20$year-$month-$day 12:00"), "%s" );

        my $outquery =
          "INSERT INTO mrvoice VALUES ($in->{id}, $title, $artist, $category, $info, '$in->{filename}', '$time', $epoch, '$pub')";
        my $sqlite_sth = $sqlite_dbh->prepare($outquery);
        $sqlite_sth->execute or die "Died on query -->$outquery<-- $!";
        if ( ( $insert_count % 500 ) == 0 )
        {

            # Commit after 500 inserts
            $sqlite_dbh->do("COMMIT");
            $sqlite_dbh->do("BEGIN");
        }
        $insert_count++;
    }
    $sqlite_dbh->do("COMMIT");

    $mysql_dbh->disconnect;
    $sqlite_dbh->disconnect;

}

print $wrapper->wrap(
    "This utility will upgrade your Mr. Voice database from the version 1.x series (MySQL) to the version 2.x series (SQLite).  It should ONLY be run to upgrade an existing Mr. Voice installation.  For new installs, just run the mrvoice.exe file - it will do all of the database creation for you.\n\n"
);
print $wrapper->wrap(
    "Your old MySQL data will not be changed, and will remain available in case there are problems with the upgrade.\n\n"
);

print "Continue with Mr. Voice 2.0 Database Migration [y/N]? ";

my $yesno = getc(STDIN);

unless ( $yesno =~ /^y/i )
{
    die "Ok.  Nothing ventured, nothing gained.\n\n";
}

if ( !read_rcfile() )
{
    die
      "FATAL ERROR - We could not find your Mr. Voice configuration file, so we cannot upgrade\n\n";
}

# Connect to the MySQL database
$mysql_dbh =
  DBI->connect( "DBI:mysql:$config{db_name}", $config{db_username},
    $config{db_pass} )
  or die
  "Could not connect to your current MySQL database.  Using Database Name $config{db_name}, User $config{db_username}, Password $config{db_pass}.  MySQL error returned: $DBI::errstr\n\n";

# Check to see if we're at the minimum database levels

my $dbdir = get_dbdir;
$config{db_file} = "$dbdir/mrvoice.db";

print $wrapper->wrap(
    "Your new SQLite Mr. Voice 2.0 database will be created at:\n$config{db_file}\nYou can move this file after the upgrade if you want it somewhere else.\n\n"
);

create_new_database;

print $wrapper->wrap(
    "New SQLite database created - we will now migrate your MySQL data to it.\n\n"
);

upgrade_20();

print $wrapper->wrap("Database upgraded!\n\n");

save_rcfile();

print $wrapper->wrap("New config file saved as $rcfile\n\n");

print $wrapper->wrap(
    "Your Mr. Voice database has now been upgraded to the 2.0 level.  When you are confident that the new database is working properly, you can remove MySQL from your system.\n\n"
);
print $wrapper->wrap("Press Enter to exit\n");
my $key = getc(STDIN);
exit;

__DATA__
# This is the Mr. Voice database schema
#

CREATE TABLE mrvoice (
   id INTEGER PRIMARY KEY,
   title varchar(255) NOT NULL,
   artist varchar(255),
   category varchar(8) NOT NULL,
   info varchar(255),
   filename varchar(255) NOT NULL,
   time varchar(10),
   modtime timestamp(6),
   publisher varchar(16)
);

CREATE TABLE categories (
   code varchar(8) NOT NULL,
   description varchar(255) NOT NULL
);

