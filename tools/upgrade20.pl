#!/usr/bin/perl

use warnings;
use strict;

use Tk;
use DBI;
use Date::Manip;

our %config;       # Configuration hash
our $mw;           # Tk MainWindow
our $icon;         # Window icon
our $homedir;      # Unix home directory
our $mysql_dbh;    # MySQL database handle

sub icon_data
{

    # Define 32x32 XPM icon data
    my $icon = <<'end-of-icon-data';
/* XPM */
static char * mrvoice_3232_xpm[] = {
"32 32 21 1",
" 	c None",
".	c #FFFFFF",
"+	c #AAAAAA",
"@	c #000000",
"#	c #E3E3E3",
"$	c #393939",
"%	c #555555",
"&	c #727272",
"*	c #8E8E8E",
"=	c #C7C7C7",
"-	c #1D1D1D",
";	c #FFABAA",
">	c #FF5755",
",	c #FF7472",
"'	c #FF0300",
")	c #FF201D",
"!	c #FF3B39",
"~	c #915A59",
"{	c #FF8F8E",
"]	c #FFC8C7",
"^	c #FFE3E3",
"................................",
"+@@@#....$@@%...................",
"+@@@+....@@@%...................",
"+@@@&...+@@@%...................",
"+@@@$...&@@@%.%%*%&.............",
"#&@@@...%@@$=.@@@@@*............",
".+@%@+..@%@%..@@@@@%............",
".+@*@&.=@*@%..+@%*@%............",
".+@+-$.*@=@%...@+.%%............",
".+@+%@.%@.@%...@+.**............",
".+@+*@+-%.@%...@+...............",
".+@+=@%@*.@%...@+...............",
".+@+.@@@+.@%...@+...............",
"=$@$*%@@=%@-*..@+...............",
"+@@@%*@$+@@@%.+@&....=+#........",
"+@@@%=@&+@@@%.@@@;>>>@@%...,>>>.",
"+@@@%.@++@@@%.@@@;'''@@%...)''!.",
"=%%%*.&.=%%%*.%%%;'''~%+..{'''].",
".................;''';...^'''>..",
".................;''';...,'''^..",
".................;''';..]'''{...",
".................^''';..!'')....",
"..................''';.;''';....",
"..................''';.)''!.....",
"..................''';,'''].....",
"..................'''{''',......",
"..................''')'')^......",
"..................''''''{.......",
"..................''''')........",
"..................''''']........",
"..................)'''>.........",
"..................];;;^........."};
end-of-icon-data

    return ($icon);
}

sub read_rcfile
{
    my $rcfile;
    if ( $^O eq "MSWin32" )
    {
        $rcfile = "C:\\mrvoice.cfg";
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

    print "DEBUG: The config file is $rcfile\n";
    if ( -r $rcfile )
    {
        print "DEBUG: Reading rcfile\n";
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

sub do_exit
{
    Tk::exit;
}

sub check_17
{

    # This checks to see if the Mr. Voice database is at least at the
    # 1.7 level (song time column)

    my $infoframe = shift;
    my $query_17  = "SELECT time FROM mrvoice LIMIT 1";
    if ( !$mysql_dbh->do($query_17) )
    {
        $infoframe->Label( -text =>
              "FATAL ERROR - Your database does not have the song time column.  You need to upgrade your installation of Mr. Voice to at least version 1.10 before you can perform this upgrade"
        )->pack( -side => 'top' );
        return (0);
    }
    else
    {
        $infoframe->Label( -text =>
              "OK - Your database has the song time column, so it is at least at the 1.7 level"
        )->pack( -side => 'top' );
        return (1);
    }

}

sub check_110
{

    # This checks to see if the Mr. Voice database is at least at the
    # 1.10 level (publisher column)

    my $infoframe = shift;
    my $query_110 = "SELECT publisher FROM mrvoice LIMIT 1";
    if ( !$mysql_dbh->do($query_110) )
    {
        $infoframe->Label( -text =>
              "FATAL ERROR - Your database does not have the publisher column.  You need to upgrade your installation of Mr. Voice to at least version 1.10 before you can perform this upgrade"
        )->pack( -side => 'top' );
        return (0);
    }
    else
    {
        $infoframe->Label( -text =>
              "OK - Your database has the publisher column, so it is at least at the 1.10 level"
        )->pack( -side => 'top' );
        return (1);
    }
}

sub upgrade_20
{

    # This migrates the database from MySQL to SQLite

    my $sqlite_dbh =
      DBI->connect( "dbi:SQLite:dbname=/home/minter/mrvoice.db", "", "" )
      or die;

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

    while ( my $in = $mysql_sth->fetchrow_hashref )
    {
        my $title    = $sqlite_dbh->quote( $in->{title} );
        my $artist   = $sqlite_dbh->quote( $in->{artist} );
        my $category = $sqlite_dbh->quote( $in->{category} );
        my $info     = $sqlite_dbh->quote( $in->{info} );

        $in->{modtime} =~ /(\d\d)(\d\d)(\d\d)/;
        my ( $year, $month, $day ) = ( $1, $2, $3 );
        my $epoch = UnixDate( ParseDate("20$year-$month-$day 12:00"), "%s" );

        my $outquery =
          "INSERT INTO mrvoice VALUES ($in->{id}, $title, $artist, $category, $info, '$in->{filename}', '$in->{time}', $epoch, '$in->{publisher}')";
        my $sqlite_sth = $sqlite_dbh->prepare($outquery);
        $sqlite_sth->execute or die "Died on query -->$outquery<-- $!";
    }

    $mysql_dbh->disconnect;
    $sqlite_dbh->disconnect;

}

$mw = MainWindow->new;

#$mw->geometry("+0+0");
$mw->title("Mr. Voice 2.0 Updater");
$mw->minsize( 50, 50 );
$mw->protocol( 'WM_DELETE_WINDOW', \&do_exit );
$icon = $mw->Pixmap( -data => icon_data() );
$mw->Icon( -image => $icon );

my $frame1 = $mw->Frame()->pack( -side => 'top' );
$frame1->Label( -text =>
      "This utility will upgrade your Mr. Voice database from the version 1.x series (MySQL)\nto the version 2.x series (SQLite).  It should ONLY be run to upgrade an existing Mr. Voice installation.  For\nnew installs, do XXX"
)->pack( -side => 'top' );

my $infoframe = $mw->Frame()->pack( -side => 'top' );

if ( !read_rcfile() )
{
    $frame1->Label( -text =>
          "FATAL ERROR - We could not find your Mr. Voice configuration file, so we cannot upgrade\n"
    )->pack( -side => 'top' );
}

# Connect to the MySQL database
$mysql_dbh =
  DBI->connect( "DBI:mysql:$config{db_name}", $config{db_username},
    $config{db_pass} )
  or die;

if ( check_17($infoframe) && check_110($infoframe) )
{

    #upgrade_20();
}

MainLoop;
