#!/usr/bin/perl 
use warnings;
no warnings 'redefine';

#use diagnostics;

use strict;    # Works now!  Woo hoo!
use Encode::Unicode;
use Tk '804.026';
use Tk::DialogBox;
use Tk::Dialog;
use Tk::DragDrop;
use Tk::DropSite;
use Tk::NoteBook;
use Tk::ProgressBar::Mac;
use Tk::DirTree;
use File::Basename;
use File::Copy;
use File::Spec::Functions;
use DBI;
use MPEG::MP3Info;
use Audio::Wav;
use Date::Manip;
use Time::Local;
use Time::HiRes qw(gettimeofday);
use Ogg::Vorbis::Header::PurePerl;
use File::Glob qw(:globally :nocase);
use File::Temp qw/ tempfile tempdir /;
use Cwd 'abs_path';

use subs
  qw/filemenu_items hotkeysmenu_items categoriesmenu_items songsmenu_items advancedmenu_items helpmenu_items/;

#########
# AUTHOR: H. Wade Minter <minter@lunenburg.org>
# TITLE: mrvoice.pl
# DESCRIPTION: A Perl/TK frontend for an MP3 database.  Written for
#              ComedyWorx, Raleigh, NC.
#              http://www.comedyworx.com/
# CVS ID: $Id: mrvoice.pl,v 1.380 2004/04/26 20:20:49 minter Exp $
# CHANGELOG:
#   See ChangeLog file
##########

#####
# YOU SHOULD NOT NEED TO MODIFY ANYTHING BELOW HERE FOR NORMAL USE
#####

##########
# Set up variables that need to be global for now
##########
our %config;           # Holds the config variables
our $mw;               # Mainwindow
our $dbh;              # Database Handle
our $icon;             # Window Icon
our $mainbox;          # Main search box
our $agent;            # LWP agent for Win32
our $holdingtank;      # Holding Tank window
our $tankbox;          # Holding tank listbox
our %fkeys;            # Function keys
our %oldfkeys;         # Used when restoring hotkeys
our %fkeys_cb;         # The checkboxes in the Hotkeys box
our @current;          # Array holding the dynamic documents
our $mp3_pid;          # The Process ID of the MP3 player
our $hotkeysbox;       # The hotkey display Toplevel
our $tank_token;       # The Holding Tank D&D Token
our $dnd_token;        # The main Search Box D&D Token
our $current_token;    # Global holding the current D&D Token
our $lock_hotkeys   = 0;        # Are hotkeys locked?
our $savefile_count = 0;        # Counter variables
our $savefile_max   = 4;        # The maximum number of files to
                                # keep in the "recently used" list.
our $category       = 'Any';    # The default category to search
our $longcat        = 'Any';    # The default category to search
our $rcfile;                    # Resource file
our $dynamicmenu;               # The menu that lists "dynamic documents"
our $hotkeysmenu;               # The main hotkeys menu
our $title;                     # The "Title" search entry field
our $artist;                    # The "Artist" search entry field
our $anyfield;                  # The "Any Field" search entry field
our $cattext;                   # The "Extra Info" search entry field
##########

# Allow searches of all music publishers by default.
$config{'search_ascap'}   = 1;
$config{'search_bmi'}     = 1;
$config{'search_other'}   = 1;
$config{'show_publisher'} = 0;

our @publishers = ( 'OTHER', 'ASCAP', 'BMI' );

our $hotkeytypes =
  [ [ 'Mr. Voice Hotkey Files', '.mrv' ], [ 'All Files', '*' ], ];

our $holdingtanktypes =
  [ [ 'Mr. Voice Holding Tank Files', '.hld' ], [ 'All Files', '*' ], ];

our $databasefiles =
  [ [ 'Database Dump Files', '.sql' ], [ 'All Files', '*' ], ];

our $mp3types = [
    [
        'All Valid Audio Files',
        [
            '*.mp3', '*.MP3', '*.ogg', '*.OGG', '*.wav', '*.WAV',
            '*.m3u', '*.M3U', '*.pls', '*.PLS'
        ]
    ],
    [ 'MP3 Files',    [ '*.mp3', '*.MP3' ] ],
    [ 'WAV Files',    [ '*.wav', '*.WAV' ] ],
    [ 'Vorbis Files', [ '*.ogg', '*.OGG' ] ],
    [ 'Playlists',    [ '*.m3u', '*.M3U', '*.pls', '*.PLS' ] ],
    [ 'All Files', '*' ],
];

if ( $^O eq "MSWin32" )
{
    push @{ $mp3types->[0][1] }, ( "*.wma", "*.WMA" );
    my $wmaref = [ [ 'WMA Files', [ '*.wma', '*.WMA' ] ] ];
    splice( @{$mp3types}, 4, 0, @{$wmaref} );
}

# Check to see if we're on Windows or Linux, and set the RC file accordingly.
if ( "$^O" eq "MSWin32" )
{
    $rcfile = "C:\\mrvoice.cfg";
    my $logfile = "C:\\mrvoice.log";
    open( STDOUT, ">$logfile" );
    open( STDERR, ">&STDOUT" );

    BEGIN
    {
        if ( $^O eq "MSWin32" )
        {
            require LWP::UserAgent;
            LWP::UserAgent->import();
            require HTTP::Request;
            HTTP::Request->import();
            require Win32::Process;
            Win32::Process->import();
            require Tk::Radiobutton;
            Tk::Radiobutton->import();
            require Win32::FileOp;
            Win32::FileOp->import();
            require Audio::WMA;
            Audio::WMA->import();
        }
    }
    $agent = LWP::UserAgent->new;
    $agent->agent("Mr. Voice Audio Software/$0 ");

    # You have to manually set the time zone for Windows.
    my ( $l_min, $l_hour, $l_year, $l_yday ) = ( localtime $^T )[ 1, 2, 5, 7 ];
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
    my $logfile = "$homedir/mrvoice.log";
    open( STDOUT, ">$logfile" );
    open( STDERR, ">&STDOUT" );
}

# The following variables set the locations of MP3s for static hotkey'd
# sounds
#STARTCSZ
#our $altt = "TaDa.mp3";
#our $alty = "CalloutMusic.mp3";
#our $altb = "BrownBag.mp3";
#our $altg = "Groaner.mp3";
#our $altv = "PriceIsRightTheme.mp3";

#ENDCSZ

#####

my $version = "1.10.7";    # Program version
our $status = "Welcome to Mr. Voice version $version";

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

sub logo_photo
{
    my $logo_photo_data = <<end_of_data;
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
rM3qrM8KrdEqrdNKrdVqrdeKrdmqre8TCAA7
end_of_data

    return ($logo_photo_data);
}

sub soundicon_gif
{

    # FILENAME: /Users/minter/soundicon.gif
    # THIS FUNCTION RETURNS A BASE64 ENCODED
    # REPRESENTATION OF THE ABOVE FILE.
    # SUITABLE FOR USE BY THE -data PROPERTY.
    # OF A Perl/Tk PHOTO.
    my $binary_data = <<EOD;
R0lGODlhGQAgAMQAAPfv92NjzjExY5yc/87O/+/v9xghIUpSUq21tTEpKf///+/v797e3s7Ozr29
va2trZSUlHt7e2NjY1paWkpKSjk5OSkpKRgYGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAA
GQAgAAAF/6AiiowkTWhKTVTbVlRVjcpiLmNR18Di4wtGYmRrTHy1H0MZZDAcM0XJYWMkf8Gs0/mw
1CRUxRGJ1S6diMp0KS6Xz1uHBbU6oNjYc/PcnUAefxBUZG9mDzBSPmdXeWYMfTg7QDUMAlk2e48W
FJFElAKWigsRcF0HnUBBAgGhnEsSTV2cNDiVAQMBP66jXBezO1KrAwS5ukGwmr8kwgQKuWoLE06k
j746CqDMCsQLrkevCw++kQIDAw4iBNwLFT4U09W/AzTqA6HtDN+k4r/luObmWi2RVkVcFAUYAigE
aM8HPlekIIwTgaHiwoDsfHxjsO/CQQUOHCS81RAfQWoPMG60owFyZMMfBCX0onBtkkiFoRhwCkJN
ohdPNW5iGJgF2SOVLMmIxMDE6NGVIiIBEYkFWSyktFItGLTEkU9aURf0EOXo6QgAkhiJgsMAAgYL
Wx84QPCgrl27fwDp/aPSgt+/Bi4IHiwYQ+ELFSuGAAA7
EOD
    return ($binary_data);
}    # END soundicon_gif...

# This function is redefined due to evilness that keeps the focus on
# the dragged token.  Thanks to Slaven Rezic <slaven.rezic@berlin.de>
# The extra brackets are suggested by the debugging code
sub Tk::DragDrop::Mapped
{
    my ($token) = @_;
    my $e = $token->parent->XEvent;
    $token = $token->toplevel;
    $token->grabGlobal;

    #$token->focus;
    if ( defined $e )
    {
        my $X = $e->X;
        my $Y = $e->Y;
        $token->MoveToplevelWindow( $X + 3, $Y + 3 );
        $token->NewDrag;
        $token->FindSite( $X, $Y, $e );
    }
}

# Try to override the motion part of Tk::Listbox extended mode.
sub Tk::Listbox::Motion
{
    return;
}

sub BindMouseWheel
{

    my ($w) = @_;

    if ( $^O eq 'MSWin32' )
    {
        $w->bind(
            '<MouseWheel>' => [
                sub { $_[0]->yview( 'scroll', -( $_[1] / 120 ) * 3, 'units' ) },
                Ev('D')
            ]
        );
    }
    else
    {

        # Support for mousewheels on Linux commonly comes through
        # mapping the wheel to buttons 4 and 5.  If you have a
        # mousewheel ensure that the mouse protocol is set to
        # "IMPS/2" in your /etc/X11/XF86Config (or XF86Config-4)
        # file:
        #
        # Section "InputDevice"
        #     Identifier  "Mouse0"
        #     Driver      "mouse"
        #     Option      "Device" "/dev/mouse"
        #     Option      "Protocol" "IMPS/2"
        #     Option      "Emulate3Buttons" "off"
        #     Option      "ZAxisMapping" "4 5"
        # EndSection

        $w->bind(
            '<4>' => sub {
                $_[0]->yview( 'scroll', -3, 'units' ) unless $Tk::strictMotif;
            }
        );

        $w->bind(
            '<5>' => sub {
                $_[0]->yview( 'scroll', +3, 'units' ) unless $Tk::strictMotif;
            }
        );
    }

}    # end BindMouseWheel

sub update_110
{
    my $query =
      "ALTER TABLE mrvoice ADD COLUMN publisher VARCHAR(16) NOT NULL DEFAULT 'OTHER'";
    my $sth = $dbh->prepare($query);
    $sth->execute;
    if ($DBI::err)
    {
        my $errorbox = $mw->DialogBox(
            -title   => "Database Update Failed",
            -buttons => ["Exit"]
        );
        $errorbox->Icon( -image => $icon );
        my $string = "$DBI::errstr";
        $errorbox->add( "Label", -text => "FAILED: $string" )->pack();
        $errorbox->add( "Label",
            -text =>
              "You must fix this error before you can run Mr. Voice 1.10" )
          ->pack();
        my $result = $errorbox->Show();
        do_exit() if ($result);
    }
    $sth->finish;
}

sub bind_hotkeys
{

    # This will set up hotkeybindings for the window that is passed
    # in as the first argument.

    my $window = shift;
    foreach my $num ( 1 .. 12 )
    {
        $window->bind( "all", "<Key-F$num>", [ \&play_mp3, "f$num" ] );
    }
    $window->bind( "<Key-Escape>", [ \&stop_mp3 ] );
    $window->bind( "<Key-Return>",    \&do_search );
    $window->bind( "<Control-Key-x>", \&do_exit );
    $window->bind( "<Control-Key-o>", \&open_file );
    $window->bind( "<Control-Key-s>", \&save_file );
    $window->bind( "<Control-Key-h>", \&list_hotkeys );
    $window->bind( "<Control-Key-t>", \&holding_tank );

    #STARTCSZ
    #$window->bind( "<Alt-Key-t>", [ \&play_mp3, "ALT-T" ] );
    #$window->bind( "<Alt-Key-y>", [ \&play_mp3, "ALT-Y" ] );
    #$window->bind( "<Alt-Key-b>", [ \&play_mp3, "ALT-B" ] );
    #$window->bind( "<Alt-Key-g>", [ \&play_mp3, "ALT-G" ] );
    #$window->bind( "<Alt-Key-v>", [ \&play_mp3, "ALT-V" ] );

    #ENDCSZ
    if ( $^O eq "MSWin32" )
    {
        $window->bind(
            "<Shift-Key-Escape>",
            sub {
                my $req =
                  HTTP::Request->new( GET =>
                      "http://localhost:4800/fadeoutandstop?p=$config{'httpq_pw'}"
                  );
                $agent->request($req);
            }
        );
    }
}

sub open_tank
{

    # Opens a saved holding tank file, overwriting the current contents
    # UGLY HACK
    my $initialdir = $config{'savedir'};
    if ( $^O eq "MSWin32" )
    {
        $initialdir =~ s#/#\\#;
    }

    # UGLY HACK

    my $selectedfile = $mw->getOpenFile(
        -filetypes  => $holdingtanktypes,
        -initialdir => $initialdir,
        -title      => 'Open a File'
    );
    if ($selectedfile)
    {
        if ( !-r $selectedfile )
        {
            $status = "Could not open saved file for reading";
            infobox( $mw, "File Error",
                "Could not open file $selectedfile for reading" );
        }
        else
        {
            holding_tank() if ( !Exists($holdingtank) );
            wipe_tank();
            open( TANKFILE, $selectedfile );
            while ( my $id = <TANKFILE> )
            {
                chomp($id);
                my $query =
                  "SELECT mrvoice.id,categories.description,mrvoice.info,mrvoice.artist,mrvoice.title,mrvoice.time from mrvoice,categories where mrvoice.category=categories.code AND mrvoice.id=$id";
                my $tank_ref = $dbh->selectrow_hashref($query);
                my $string   = "$id:($tank_ref->{description}";
                $string = $string . " - $tank_ref->{info}"
                  if ( $tank_ref->{info} );
                $string = $string . ") - \"$tank_ref->{title}\"";
                $string = $string . " by $tank_ref->{artist}"
                  if ( $tank_ref->{artist} );
                $string = $string . " $tank_ref->{time}";

                $tankbox->insert( 'end', $string );
            }
        }
        close(TANKFILE);
        $status = "Loaded saved holding tank file $selectedfile";
    }
    else
    {
        $status = "Cancelled loading of holding tank file";
    }
}

sub save_tank
{
    if ( !Exists($tankbox) )
    {
        $status = "Can't save the holding tank before you use it...";
        return;
    }
    my @indices = $tankbox->get( 0, 'end' );

    if ( $#indices < 0 )
    {
        $status = "Not saving an empty holding tank";
        return;
    }

    # UGLY HACK
    my $initialdir = $config{'savedir'};
    if ( $^O eq "MSWin32" )
    {
        $initialdir =~ s#/#\\#;
    }
    my $selectedfile = $mw->getSaveFile(
        -title            => 'Save a File',
        -defaultextension => ".hld",
        -filetypes        => $holdingtanktypes,
        -initialdir       => $initialdir
    );

    if ($selectedfile)
    {
        if ( ( !-w $selectedfile ) && ( -e $selectedfile ) )
        {
            $status = "Holding tank save failed due to file error";
            infobox( $mw, "File Error!",
                "Could not open file $selectedfile for writing" );
        }
        elsif ( !-w dirname($selectedfile) )
        {
            $status = "Holding tank save failed due to directory error";
            my $directory = dirname($selectedfile);
            $directory = Win32::GetShortPathName($directory)
              if ( $^O eq "MSWin32" );
            infobox(
                $mw,
                "Directory Error!",
                "Could not write new file to directory $directory"
            );
        }
        else
        {
            $selectedfile = "$selectedfile.hld"
              unless ( $selectedfile =~ /.*\.hld$/ );
            open( TANKFILE, ">$selectedfile" );
            foreach my $string (@indices)
            {
                my ( $id, $desc ) = split( /:/, $string );
                print TANKFILE "$id\n";
            }
            close TANKFILE;
            $status = "Saved holding tank to $selectedfile";
        }
    }
    else
    {
        $status = "Cancelled save of holding tank";
    }
}

sub open_file
{

    # Used to open a saved hotkey file.
    # Takes an optional argument.  If the argument is given, we attempt
    # to open the file for reading.  If not, we pop up a file dialog
    # box and get the name of a file first.
    # Once we have the file, we read each line, of the form
    # hotkey_name::mp3_name, and assign the value to the hotkey.
    # Finally, we add this file to our dynamic documents menu.

    if ( $lock_hotkeys == 1 )
    {
        $status = "Can't open saved hotkeys - current hotkeys locked";
        return;
    }

    my $parentwidget = shift;
    my $selectedfile = shift;

    # UGLY HACK
    my $initialdir = $config{'savedir'};
    if ( $^O eq "MSWin32" )
    {
        $initialdir =~ s#/#\\#;
    }
    if ( !$selectedfile )
    {
        $selectedfile = $mw->getOpenFile(
            -filetypes  => $hotkeytypes,
            -initialdir => $initialdir,
            -title      => 'Open a File'
        );
    }

    if ($selectedfile)
    {
        if ( !-r $selectedfile )
        {
            infobox( $mw, "File Error",
                "Could not open file $selectedfile for reading" );
        }
        else
        {
            clear_hotkeys();
            open( HOTKEYFILE, $selectedfile );
            while (<HOTKEYFILE>)
            {
                chomp;
                my ( $key, $id ) = split(/::/);
                if ( ( not( $id =~ /^\d+$/ ) ) && ( not( $id =~ /^\w*$/ ) ) )
                {
                    infobox(
                        $mw,
                        "Invalid Hotkey File",
                        "This hotkey file, $selectedfile, is from an old version of Mr. Voice. After upgrading to Version 1.8, you need to run the converthotkeys utility in the tools subdirectory to convert to the new format.  This only has to be done once."
                    );
                    return (1);
                }
                elsif ( ($id) && ( validate_id($id) ) )
                {
                    $fkeys{$key}->{id}    = $id;
                    $fkeys{$key}->{title} = get_info_from_id($id)->{fulltitle};
                    $fkeys{$key}->{filename} =
                      get_info_from_id($id)->{filename};
                }
            }
            close(HOTKEYFILE);
            $status = "Loaded hotkey file $selectedfile";
            dynamic_documents($selectedfile);
            list_hotkeys();
        }
    }
    else
    {
        $status = "File load cancelled.";
    }
}

sub save_file
{

    # Used to save a set of hotkeys to a file on disk.
    # We pop up a save file dialog box to get the filename and path. We
    # then write out the data in the form of hotkey_number::id.
    # Finally, we add this file to our dynamic documents menu.

    # UGLY HACK
    my $initialdir = $config{'savedir'};
    if ( $^O eq "MSWin32" )
    {
        $initialdir =~ s#/#\\#;
    }
    my $selectedfile = $mw->getSaveFile(
        -title            => 'Save a File',
        -defaultextension => ".mrv",
        -filetypes        => $hotkeytypes,
        -initialdir       => $initialdir,
    );

    if ($selectedfile)
    {
        if ( ( !-w $selectedfile ) && ( -e $selectedfile ) )
        {
            infobox( $mw, "File Error!",
                "Could not open file $selectedfile for writing" );
        }
        elsif ( !-w dirname($selectedfile) )
        {
            my $directory = dirname($selectedfile);
            $directory = Win32::GetShortPathName($directory)
              if ( $^O eq "MSWin32" );
            infobox(
                $mw,
                "Directory Error!",
                "Could not write new file to directory $directory"
            );
        }
        else
        {
            $selectedfile = "$selectedfile.mrv"
              unless ( $selectedfile =~ /.*\.mrv$/ );
            open( HOTKEYFILE, ">$selectedfile" );
            foreach my $num ( 1 .. 12 )
            {
                my $keynum = "f$num";
                print HOTKEYFILE "$keynum";
                print HOTKEYFILE "::$fkeys{$keynum}->{id}\n";
            }
            close(HOTKEYFILE);
            $status = "Finished saving hotkeys to $selectedfile";
            dynamic_documents($selectedfile);
        }
    }
    else
    {
        $status = "File save cancelled.";
    }
}

sub dump_database
{
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime();
    $year += 1900;
    $mon  += 1;
    my $defaultfilename = "database-$year-$mon-$mday.sql";
    my $dumpfile        = $mw->getSaveFile(
        -title            => 'Choose Database Export File',
        -defaultextension => ".sql",
        -initialfile      => $defaultfilename,
        -filetypes        => $databasefiles
    );
    my $dirname = dirname($dumpfile);
    $dirname = Win32::GetShortPathName($dirname) if ( $^O eq "MSWin32" );
    my $shortdumpfile = basename($dumpfile);
    $shortdumpfile = catfile( $dirname, $shortdumpfile );

    if ($dumpfile)
    {
        if ( ( !-w $shortdumpfile ) && ( -e $shortdumpfile ) )
        {
            infobox( $mw, "File Error!",
                "Could not open file $dumpfile for writing" );
        }
        elsif ( !-w $dirname )
        {
            infobox(
                $mw,
                "Directory Error!",
                "Could not write new file to directory $dirname"
            );
        }
        else
        {

            # Run the MySQL Dump
            if ( $^O eq "MSWin32" )
            {
                my $cmd =
                  "C:\\mysql\\bin\\mysqldump.exe --add-drop-table --user=$config{'db_username'} --password=$config{'db_pass'} $config{'db_name'} > $shortdumpfile";
                my $rc = system($cmd );
                if ( $rc == 0 )
                {
                    infobox(
                        $mw,
                        "Database Dumped",
                        "The contents of your database have been dumped to the file: $dumpfile\n\nNote: In order to have a full backup, you must also back up the files from the directory: $config{'filepath'} as well as $rcfile and, optionally, the hotkeys from $config{'savedir'}"
                    );
                    $status = "Database dumped to $dumpfile";
                }
                else
                {
                    infobox(
                        $mw,
                        "Database Dump Failed",
                        "The database export to $dumpfile\nfailed with a status code $rc\n"
                    );
                    $status = "Failed database dump to $dumpfile";
                }
            }
            else
            {
                my $rc =
                  system(
                    "mysqldump --add-drop-table --user=$config{'db_username'} --password=$config{'db_pass'} $config{'db_name'} > $dumpfile"
                  );
                infobox(
                    $mw,
                    "Database Dumped",
                    "The contents of your database have been dumped to the file: $dumpfile\n\nNote: In order to have a full backup, you must also back up the files from the directory: $config{'filepath'} as well as $rcfile"
                );
                $status = "Database dumped to $dumpfile";
            }
        }
    }
    else
    {
        $status = "Database dump cancelled";
    }
}

sub import_database
{
    my $dumpfile = $mw->getOpenFile(
        -title            => 'Choose Database Export File',
        -defaultextension => ".sql",
        -filetypes        => $databasefiles
    );

    my $shortdumpfile =
      $^O eq "MSWin32" ? Win32::GetShortPathName($dumpfile) : $dumpfile;

    if ($dumpfile)
    {
        if ( !-r $shortdumpfile )
        {
            infobox(
                $mw,
                "File Error",
                "Could not open file $dumpfile for reading. Check permissions and try again."
            );
        }
        else
        {

            # We can read the file - pop up a warning before continuing.
            my $box = $mw->Dialog(
                -title  => "Warning",
                -bitmap => 'warning',
                -text   =>
                  "Warning!\nImporting this database dumpfile will completely overwrite your current Mr. Voice database.\n\nIf you are certain that you want to do this, press Ok.  Otherwise, press Cancel.",
                -buttons        => [ "Ok", "Cancel" ],
                -default_button => "Cancel"
            );
            $box->Icon( -image => $icon );
            my $button = $box->Show;

            if ( $button eq "Ok" )
            {
                if ( $^O eq "MSWin32" )
                {
                    my $rc =
                      system(
                        "C:\\mysql\\bin\\mysql.exe --user=$config{'db_username'} --password=$config{'db_pass'} $config{'db_name'} < $shortdumpfile"
                      );
                    infobox(
                        $mw,
                        "Database Imported",
                        "The database backup file $dumpfile has been imported."
                    );
                    $status = "Database imported from $dumpfile";
                }
                else
                {
                    my $rc =
                      system(
                        "mysql --user=$config{'db_username'} --password=$config{'db_pass'} $config{'db_name'} < $dumpfile"
                      );
                    infobox(
                        $mw,
                        "Database Imported",
                        "The database backup file $dumpfile has been imported."
                    );
                    $status = "Database imported from $dumpfile";
                }
            }
            else
            {
                $status = "Database import cancelled";
            }
        }

    }
    else
    {
        $status = "Database import cancelled";
    }

}

sub get_title_artist
{

    # Returns the title and artist of an MP3 or OGG file
    my $filename = shift;
    my $title;
    my $artist;

    if ( $filename =~ /.mp3$/i )
    {
        $filename = Win32::GetShortPathName($filename) if ( $^O eq "MSWin32" );
        my $tag = get_mp3tag($filename);
        $title  = $tag->{TITLE};
        $artist = $tag->{ARTIST};
    }
    elsif ( $filename =~ /.ogg/i )
    {
        $filename = Win32::GetShortPathName($filename) if ( $^O eq "MSWin32" );
        my $ogg = Ogg::Vorbis::Header::PurePerl->new($filename);
        ($title)  = $ogg->comment('title');
        ($artist) = $ogg->comment('artist');
    }
    elsif ( $filename =~ /.wma/i )
    {
        $filename = Win32::GetShortPathName($filename) if ( $^O eq "MSWin32" );
        my $wma     = Audio::WMA->new($filename);
        my $comment = $wma->comment();
        $title  = $comment->{TITLE};
        $artist = $comment->{AUTHOR};
    }
    $title  =~ s/^\s*// if $title;
    $artist =~ s/^\s*// if $artist;

    return ( $title, $artist );
}

sub dynamic_documents
{

    # This function takes a filename as an argument.  It then increments
    # a counter to keep track of how many documents we've accessed in this
    # session.
    # It adds the file to the "Recent Files" menu off of Files, and if we're
    # over the user-specified limit, removes the oldest file from the list.

    my $file = shift;

    my $fileentry;
    my $counter = 0;
    my $success = 0;
    foreach my $fileentry (@current)
    {
        if ( $fileentry eq $file )
        {

            # The item is currently in the list.  Move it to the front of
            # the line.
            splice( @current, $counter, 1 );
            unshift @current, $file;
            $counter++;
            $success = 1;
        }
        else
        {
            $counter++;
        }
    }

    if ( $success != 1 )
    {

        # The file isn't in our current list, so we need to add it.
        unshift @current, $file;
        $savefile_count++;
    }

    if ( $#current >= $savefile_max )
    {
        pop(@current);
    }

    # Get rid of the old menu and rebuild from our array
    $dynamicmenu->delete( 0, 'end' );
    foreach $fileentry (@current)
    {
        $dynamicmenu->command(
            -label   => "$fileentry",
            -command => [ \&open_file, $mw, $fileentry ]
        );
    }
}

sub infobox
{

    # A generic wrapper function to pop up an information box.  It takes
    # a reference to the parent widget, the title for the box, and a
    # formatted string of data to display.

    my ( $parent_window, $title, $string, $type ) = @_;
    $type = "info" if !$type;
    my $box = $parent_window->Dialog(
        -title   => "$title",
        -bitmap  => $type,
        -text    => $string,
        -buttons => ["OK"]
    );
    $box->Icon( -image => $icon );
    $box->Show;
}

sub backup_hotkeys
{

    # This saves the contents of the hotkeys to temporary variables, so
    # you can restore them after a file open, etc.

    foreach my $key (%fkeys)
    {
        $oldfkeys{$key}->{title}    = $fkeys{$key}->{title};
        $oldfkeys{$key}->{id}       = $fkeys{$key}->{id};
        $oldfkeys{$key}->{filename} = $fkeys{$key}->{filename};
    }
    $hotkeysmenu->menu->entryconfigure( "Restore Hotkeys", -state => "normal" );
}

sub restore_hotkeys
{

    # Replaces the hotkeys with the old ones from backup_hotkeys()
    foreach my $key (%oldfkeys)
    {
        $fkeys{$key}->{title}    = $oldfkeys{$key}->{title};
        $fkeys{$key}->{id}       = $oldfkeys{$key}->{id};
        $fkeys{$key}->{filename} = $oldfkeys{$key}->{filename};
    }
    $status = "Previous hotkeys restored.";
    $hotkeysmenu->menu->entryconfigure( "Restore Hotkeys",
        -state => "disabled" );
}

sub build_category_menubutton
{
    my $parent  = shift;
    my $var_ref = shift;
    my $menu    = $parent->Menubutton(
        -text        => "Choose Category",
        -relief      => 'raised',
        -tearoff     => 0,
        -indicatoron => 1
    );
    my $query = "SELECT * from categories ORDER BY description";
    my $sth   = $dbh->prepare($query);
    $sth->execute or die "can't execute the query: $DBI::errstr\n";

    while ( my $cat_hashref = $sth->fetchrow_hashref )
    {
        $menu->radiobutton(
            -label    => $cat_hashref->{description},
            -value    => $cat_hashref->{code},
            -variable => $var_ref,
            -command  => sub {
                $menu->configure( -text => return_longcat($$var_ref) );
            }
        );
    }
    $sth->finish;
    $menu->configure( -text => return_longcat($$var_ref) );
    return ($menu);
}

sub bulk_add
{
    my ( @accepted, @rejected, $directory, $longcat, $db_cat );
    my $box1 = $mw->DialogBox(
        -title   => "Add all songs in directory",
        -buttons => [ "Continue", "Cancel" ]
    );
    $box1->Icon( -image => $icon );
    my $box1frame1 = $box1->add("Frame")->pack( -fill => 'x' );
    $box1frame1->Label( -text =>
          "This will allow you to add all songs in a directory to a particular\ncategory, using the information stored in MP3 or OGG files to fill in the title and\nartist.  You will have to go back after the fact to add Extra Info or do any editing.\nIf a file does not have at least a title embedded in it, it will not be added.\n\nChoose your directory and category below.\n\n"
    )->pack( -side => 'top' );
    my $box1frame2 = $box1->add("Frame")->pack( -fill => 'x' );
    $box1frame2->Label( -text => "Add To Category: " )->pack( -side => 'left' );
    my $menu = build_category_menubutton( $box1frame2, \$db_cat );
    $menu->pack( -side => 'left' );

    my $box1frame3 = $box1->add("Frame")->pack( -fill => 'x' );
    $box1frame3->Label( -text => "Choose Directory: " )
      ->pack( -side => 'left' );
    $box1frame3->Entry( -textvariable => \$directory )->pack( -side => 'left' );
    $box1frame3->Button(
        -text    => "Select Source Directory",
        -command => sub {
            $directory = $box1->chooseDirectory;
        }
    )->pack( -side => 'left' );

    my $firstbutton = $box1->Show;

    if ( $firstbutton ne "Continue" )
    {
        $status = "Bulk-Add Cancelled";
        return;
    }

    $directory = Win32::GetShortPathName($directory) if ( $^O eq "MSWin32" );
    if ( !-r $directory )
    {
        infobox(
            $mw,
            "Directory unreadable",
            "Could not read files from the directory $directory\nPlease check permissions and try again."
        );
        $status = "Bulk-Add exited due to directory error";
        return (1);
    }

    if ( !$db_cat )
    {
        infobox(
            $mw,
            "Select a category",
            "You must select a category to load the files into.\nPlease try again."
        );
        $status = "Bulk-Add exited due to category error";
        return (1);
    }

    my @mp3glob = glob( catfile( $directory, "*.mp3" ) );
    my @oggglob = glob( catfile( $directory, "*.ogg" ) );
    my @wmaglob = glob( catfile( $directory, "*.wma" ) )
      if ( $^O eq "MSWin32" );

    my @list = ( @mp3glob, @oggglob );
    push( @list, @wmaglob ) if ( $^O eq "MSWin32" );

    $mw->Busy( -recurse => 1 );
    foreach my $file (@list)
    {
        $file = Win32::GetShortPathName($file) if ( $^O eq "MSWin32" );
        my ( $title, $artist ) = get_title_artist($file);
        if ($title)
        {

            # Valid title, all we need
            my $time     = get_songlength($file);
            my $db_title = $dbh->quote($title);
            my $db_artist;
            if ( ($artist) && ( $artist !~ /^\s*$/ ) )
            {
                $db_artist = $dbh->quote($artist);
            }
            else
            {
                $db_artist = "NULL";
            }
            my $db_filename = move_file( $file, $title, $artist );
            my $query =
              "INSERT INTO mrvoice (id,title,artist,category,filename,time,modtime) VALUES (NULL, $db_title, $db_artist, '$db_cat', '$db_filename', '$time', NULL)";
            my $sth = $dbh->prepare($query);
            $sth->execute or die "can't execute the query: $DBI::errstr\n";
            $sth->finish;
            if ( $^O eq "MSWin32" )
            {
                push( @accepted, basename( Win32::GetLongPathName($file) ) );
            }
            else
            {
                push( @accepted, basename($file) );
            }
        }
        else
        {

            # No title, no go.
            if ( $^O eq "MSWin32" )
            {
                push( @rejected, basename( Win32::GetLongPathName($file) ) );
            }
            else
            {
                push( @rejected, basename($file) );
            }
        }
    }
    $mw->Unbusy( -recurse => 1 );

    # Final Summary
    my $summarybox = $mw->Toplevel( -title => "Bulk-Add Summary" );
    $summarybox->withdraw();
    $summarybox->Icon( -image => $icon );
    my $lb = $summarybox->Scrolled(
        "Listbox",
        -scrollbars => "osoe",
        -setgrid    => 1,
        -width      => 50,
        -height     => 20,
        -selectmode => "single"
    )->pack();
    $lb->insert( 'end', "===> The following items were successfully added" );
    foreach my $good (@accepted)
    {
        $lb->insert( 'end', $good );
    }
    $lb->insert( 'end', "", "", "===> The following files were NOT added:" );
    foreach my $bad (@rejected)
    {
        $lb->insert( 'end', $bad );
    }
    $summarybox->Button(
        -text    => "Close",
        -command => sub {
            $summarybox->destroy if Tk::Exists($summarybox);
        }
    )->pack();
    $summarybox->update();
    $summarybox->deiconify();
    $summarybox->raise();
}

sub add_category
{
    my ( $addcat_code, $addcat_desc );
    my $box = $mw->DialogBox(
        -title   => "Add a category",
        -buttons => [ "Ok", "Cancel" ]
    );
    $box->Icon( -image => $icon );
    my $acframe1 = $box->add("Frame")->pack( -fill => 'x' );
    $acframe1->Label( -text => "Category Code:  " )->pack( -side => 'left' );
    $acframe1->Entry(
        -width        => 6,
        -textvariable => \$addcat_code
    )->pack( -side => 'left' );
    my $acframe2 = $box->add("Frame")->pack( -fill => 'x' );
    $acframe2->Label( -text => "Category Description:  " )
      ->pack( -side => 'left' );
    $acframe2->Entry(
        -width        => 25,
        -textvariable => \$addcat_desc
    )->pack( -side => 'left' );
    my $button = $box->Show;

    if ( $button eq "Ok" )
    {
        if ( ($addcat_code) && ($addcat_desc) )
        {
            $addcat_desc = $dbh->quote($addcat_desc);
            $addcat_code =~ tr/a-z/A-Z/;

            # Check to see if there's a duplicate of either entry

            my $checkquery =
              "SELECT * FROM categories WHERE (code='$addcat_code' OR description=$addcat_desc)";
            my $sth    = $dbh->prepare($checkquery);
            my $result = $sth->execute;
            if ( $sth->rows > 0 )
            {
                infobox(
                    $mw,
                    "Category Error",
                    "A category with that name or code already exists.  Please try again"
                );
            }
            else
            {
                my $query =
                  "INSERT INTO categories VALUES ('$addcat_code',$addcat_desc)";
                $sth = $dbh->prepare($query);
                if ( !$sth->execute )
                {
                    my $error_message = $sth->errstr();
                    infobox(
                        $mw,
                        "Database Error",
                        "Database returned error: $error_message on query $query"
                    );
                }
                else
                {
                    $status = "Added category $addcat_desc";
                    infobox( $mw, "Success", "Category added." );
                }
                $sth->finish;
            }
        }
        else
        {
            infobox( $mw, "Error",
                "You must enter both a category code and a description" );
        }
    }
    else
    {
        $status = "Cancelled adding category.";
    }
}

sub edit_category
{
    my $edit_cat;
    my $box = $mw->DialogBox(
        -title   => "Choose a category to edit",
        -buttons => [ "Ok", "Cancel" ]
    );
    $box->Icon( -image => $icon );
    $box->add( "Label",
        -text =>
          "You may currently edit the long name, but not the code, of a category.\n\nChoose the category to edit below."
    )->pack();
    my $query = "SELECT * from categories ORDER BY description";
    my $sth   = $dbh->prepare($query);
    $sth->execute or die "can't execute the query: $DBI::errstr\n";
    my $editbox = $box->add(
        "Scrolled", "Listbox",
        -scrollbars => 'osoe',
        -setgrid    => 1,
        -height     => 10,
        -width      => 30,
        -selectmode => "single"
    )->pack();

    while ( my $cat_hashref = $sth->fetchrow_hashref )
    {
        my $string = "$cat_hashref->{code} - $cat_hashref->{description}";
        $editbox->insert( 'end', "$string" );
    }
    $sth->finish;
    my $choice = $box->Show();
    if ( ( $choice ne "Cancel" ) && ( defined( $editbox->curselection() ) ) )
    {

        # Throw up another dialog box to do the actual editing
        my ( $code, $desc ) =
          split( /-/, $editbox->get( $editbox->curselection() ) );
        my $editbox = $mw->DialogBox(
            -title   => "Edit a category",
            -buttons => [ "Ok", "Cancel" ]
        );
        $editbox->Icon( -image => $icon );
        $editbox->add( "Label",
            -text => "Edit the long name of the category: $desc." )->pack();
        my $new_desc = $desc;
        $editbox->add( "Label", -text => "CODE: $code", -anchor => 'w' )
          ->pack( -fill => 'x', -expand => 1 );
        my $labelframe = $editbox->add("Frame")->pack( -fill => 'x' );
        $labelframe->Label( -text => "New Description: " )
          ->pack( -side => 'left' );
        $labelframe->Entry(
            -width        => 25,
            -textvariable => \$new_desc
        )->pack( -side => 'left' );
        my $editchoice = $editbox->Show();

        if ( $editchoice ne "Cancel" )
        {
            $query =
              "UPDATE categories SET description='$new_desc' WHERE code='$code'";
            $sth = $dbh->prepare($query);
            if ( !$sth->execute )
            {
                my $error_message = $sth->errstr();
                infobox(
                    $mw,
                    "Database Error",
                    "Database returned error: $error_message on query $query"
                );
            }
            else
            {
                $status = "Edited category: $new_desc";
                infobox( $mw, "Success", "Category edited." );
            }
            $sth->finish;
        }
        else
        {
            $status = "Cancelled category edit";
        }
    }
}

sub delete_category
{
    my $box = $mw->DialogBox(
        -title   => "Delete a category",
        -buttons => [ "Ok", "Cancel" ]
    );
    $box->Icon( -image => $icon );
    $box->add( "Label", -text => "Choose a category to delete." )->pack();

    my $query = "SELECT * from categories ORDER BY description";
    my $sth   = $dbh->prepare($query);
    $sth->execute or die "Cannot execute the query: $DBI::errstr\n";
    my $deletebox = $box->add(
        "Scrolled", "Listbox",
        -scrollbars => 'osoe',
        -setgrid    => 1,
        -height     => 10,
        -width      => 30,
        -selectmode => "single"
    )->pack();
    while ( my $cat_hashref = $sth->fetchrow_hashref )
    {
        $deletebox->insert( 'end',
            "$cat_hashref->{code} - $cat_hashref->{description}" );
    }
    $sth->finish;
    my $choice = $box->Show();

    if ( ( $choice ne "Cancel" ) && ( defined( $deletebox->curselection() ) ) )
    {
        my ( $del_cat, $del_desc ) =
          split( /-/, $deletebox->get( $deletebox->curselection() ) );
        $query = "SELECT * FROM mrvoice WHERE category='$del_cat'";
        my $sth = $dbh->prepare($query);
        $sth->execute;
        my $rows = $sth->rows;
        $sth->finish;
        if ( $rows > 0 )
        {
            infobox( $mw, "Error",
                "Could not delete category $del_cat because there are still entries in the database using it.  Delete all entries using this category before deleting the category"
            );
            $status = "Category not deleted";
        }
        else
        {
            $query = "DELETE FROM categories WHERE code='$del_cat'";
            my $sth = $dbh->prepare($query);
            if ( $sth->execute )
            {
                $status = "Deleted category $del_desc";
                infobox( $mw, "Success",
                    "Category \"$del_desc\" has been deleted." );
            }
            $sth->finish;
        }
    }
    else
    {
        $status = "Category deletion cancelled";
    }
}

sub move_file
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

    if ( -e catfile( $config{'filepath'}, "$newfilename$extension" ) )
    {
        my $i = 0;
        while ( 1 == 1 )
        {
            if ( !-e catfile( $config{'filepath'}, "$newfilename-$i$extension" )
              )
            {
                $newfilename = "$newfilename-$i";
                last;
            }
            $i++;
        }
    }

    $newfilename = "$newfilename$extension";

    copy( $oldfilename, catfile( $config{'filepath'}, "$newfilename" ) );

    return ($newfilename);
}

sub add_new_song
{
    my (
        $addsong_title, $addsong_artist,   $addsong_info,
        $addsong_cat,   $addsong_filename, $addsong_publisher
    );
    my $continue = 0;
    $addsong_publisher = "OTHER";
    while ( $continue != 1 )
    {
        my $box = $mw->DialogBox(
            -title   => "Add New Song",
            -buttons => [ "OK", "Cancel" ]
        );
        $box->bind( "<Key-Escape>", [ \&stop_mp3 ] );
        $box->Icon( -image => $icon );
        $box->add( "Label",
            -text =>
              "Enter the following information for the new song, and choose the file to add."
        )->pack();
        $box->add( "Label", -text => "Items in red are required.\n" )->pack();
        my $frame1 = $box->add("Frame")->pack( -fill => 'x' );
        $frame1->Label(
            -text       => "Song Title",
            -foreground => "#cdd226132613"
        )->pack( -side => 'left' );
        $frame1->Entry(
            -width        => 30,
            -textvariable => \$addsong_title
        )->pack( -side => 'right' );
        my $frame2 = $box->add("Frame")->pack( -fill => 'x' );
        $frame2->Label( -text => "Artist" )->pack( -side => 'left' );
        $frame2->Entry(
            -width        => 30,
            -textvariable => \$addsong_artist
        )->pack( -side => 'right' );
        my $frame3 = $box->add("Frame")->pack( -fill => 'x' );
        $frame3->Label(
            -text       => "Category",
            -foreground => "#cdd226132613"
        )->pack( -side => 'left' );
        my $menu = build_category_menubutton( $frame3, \$addsong_cat );
        $menu->pack( -side => 'right' );
        my $frame4 = $box->add("Frame")->pack( -fill => 'x' );
        $frame4->Label( -text => "Category Extra Info" )
          ->pack( -side => 'left' );
        $frame4->Entry(
            -width        => 30,
            -textvariable => \$addsong_info
        )->pack( -side => 'right' );
        my $pubframe = $box->add("Frame")->pack( -fill => 'x' );
        $pubframe->Label( -text => 'Publisher' )->pack( -side => 'left' );
        my $pubmenu = $pubframe->Menubutton(
            -text        => "Choose Publisher",
            -relief      => 'raised',
            -tearoff     => 0,
            -indicatoron => 1
        )->pack( -side => 'right' );

        foreach my $item (@publishers)
        {
            $pubmenu->radiobutton(
                -label    => $item,
                -value    => $item,
                -variable => \$addsong_publisher,
                -command  => sub {
                    $pubmenu->configure( -text => $addsong_publisher );
                }
            );
        }
        my $frame5 = $box->add("Frame")->pack( -fill => 'x' );
        $frame5->Label(
            -text       => "File to add",
            -foreground => "#cdd226132613"
        )->pack( -side => 'left' );
        my $frame6 = $box->add("Frame")->pack( -fill => 'x' );
        $frame6->Button(
            -text    => "Select File",
            -command => sub {
                $addsong_filename = $mw->getOpenFile(
                    -title     => 'Select File',
                    -filetypes => $mp3types
                );
                ( $addsong_title, $addsong_artist ) =
                  get_title_artist($addsong_filename);
            }
        )->pack( -side => 'right' );
        my $songentry = $frame5->Entry(
            -width        => 30,
            -textvariable => \$addsong_filename
        )->pack( -side => 'right' );
        my $frame7 = $box->add("Frame")->pack( -fill => 'x' );
        $frame7->Button(
            -text    => "Preview song",
            -command => sub {
                my $tmpsong = $songentry->cget( -textvariable );
                play_mp3( $box, "addsong", $$tmpsong );
            }
        )->pack( -side => 'right' );

        my $result = $box->Show();

        if ( $result eq "OK" )
        {
            if ( !$addsong_cat )
            {
                infobox( $mw, "Error",
                    "Could not add new song\n\nYou must choose a category" );
            }
            elsif ( !-r $addsong_filename )
            {
                infobox(
                    $mw,
                    "File Error",
                    "Could not open input file $addsong_filename for reading.  Check file permissions"
                );
            }
            elsif ( !$addsong_title )
            {
                infobox( $mw, "File Error",
                    "You must provide the title for the song." );
            }
            elsif ( !-w $config{'filepath'} )
            {
                infobox(
                    $mw,
                    "File Error",
                    "Could not write file to directory $config{'filepath'}\nPlease check the permissions"
                );
            }
            else
            {
                $continue = 1;
            }
        }
        else
        {
            $status = "Cancelled song add";
            return (1);
        }
    }    # End while continue loop

    my $newfilename =
      move_file( $addsong_filename, $addsong_title, $addsong_artist );

    $addsong_title = $dbh->quote($addsong_title);
    if ( $addsong_info eq "" )
    {
        $addsong_info = "NULL";
    }
    else
    {
        $addsong_info = $dbh->quote($addsong_info);
    }
    if ( $addsong_artist eq "" )
    {
        $addsong_artist = "NULL";
    }
    else
    {
        $addsong_artist = $dbh->quote($addsong_artist);
    }
    my $time  = get_songlength($addsong_filename);
    my $query =
      "INSERT INTO mrvoice VALUES (NULL,$addsong_title,$addsong_artist,'$addsong_cat',$addsong_info,'$newfilename','$time',NULL,'$addsong_publisher')";
    if ( $dbh->do($query) )
    {
        my $addsong_filename = Win32::GetLongPathName($addsong_filename)
          if ( $^O eq "MSWin32" );
        infobox(
            $mw,
            "File Added Successfully",
            "Successfully added new song into database.\n\nYou may now delete/move/etc. the file: $addsong_filename as it is no longer needed by Mr. Voice"
        );
        $status = "File added";
    }
    else
    {
        infobox( $mw, "Error", "Could not add song into database" );
        $status = "File add exited on database error";
    }
}

sub edit_preferences
{
    my $box = $mw->DialogBox(
        -title          => "Edit Preferences",
        -buttons        => [ "Ok", "Cancel" ],
        -default_button => "Ok"
    );
    $box->Icon( -image => $icon );
    my $notebook = $box->add( 'NoteBook', -ipadx => 6, -ipady => 6 );
    my $database_page = $notebook->add(
        "database",
        -label     => "Database Options",
        -underline => 0
    );
    my $filepath_page = $notebook->add(
        "filepath",
        -label     => "File Paths",
        -underline => 0
    );
    my $search_page = $notebook->add(
        "search",
        -label     => "Search Options",
        -underline => 0
    );
    my $other_page = $notebook->add(
        "other",
        -label     => "Other",
        -underline => 0
    );

    my $db_name_frame = $database_page->Frame()->pack( -fill => 'x' );
    $db_name_frame->Label( -text => "Database Name" )->pack( -side => 'left' );
    $db_name_frame->Entry(
        -width        => 30,
        -textvariable => \$config{'db_name'}
    )->pack( -side => 'right' );

    my $db_user_frame = $database_page->Frame()->pack( -fill => 'x' );
    $db_user_frame->Label( -text => "Database Username" )
      ->pack( -side => 'left' );
    $db_user_frame->Entry(
        -width        => 30,
        -textvariable => \$config{'db_username'}
    )->pack( -side => 'right' );

    my $db_pass_frame = $database_page->Frame()->pack( -fill => 'x' );
    $db_pass_frame->Label( -text => "Database Password" )
      ->pack( -side => 'left' );
    $db_pass_frame->Entry(
        -width        => 30,
        -textvariable => \$config{'db_pass'}
    )->pack( -side => 'right' );

    my $mp3dir_frame = $filepath_page->Frame()->pack( -fill => 'x' );
    $mp3dir_frame->Label( -text => "MP3 Directory" )->pack( -side => 'left' );
    $mp3dir_frame->Button(
        -text    => "Select MP3 Directory",
        -command => sub {
            if ( my $filepath = $box->chooseDirectory )
            {
                $filepath = Win32::GetShortPathName($filepath)
                  if ( $^O eq "MSWin32" );
                $config{'filepath'} = $filepath;
            }
        }
    )->pack( -side => 'right' );

    $mp3dir_frame->Entry(
        -width        => 30,
        -textvariable => \$config{'filepath'}
    )->pack( -side => 'right' );

    my $hotkeydir_frame = $filepath_page->Frame()->pack( -fill => 'x' );
    $hotkeydir_frame->Label( -text => "Hotkey Save Directory" )
      ->pack( -side => 'left' );
    $hotkeydir_frame->Button(
        -text    => "Select Hotkey Directory",
        -command => sub {
            if ( my $savedir = $box->chooseDirectory )
            {
                $savedir = Win32::GetShortPathName($savedir)
                  if ( $^O eq "MSWin32" );
                $config{'savedir'} = $savedir;
            }
        }
    )->pack( -side => 'right' );
    $hotkeydir_frame->Entry(
        -width        => 30,
        -textvariable => \$config{'savedir'}
    )->pack( -side => 'right' );

    my $display_page =
      $search_page->Frame( -relief => 'groove', -bd => 1 )
      ->pack( -fill => 'x' );
    $display_page->Checkbutton(
        -text     => 'Display publisher in search results?',
        -variable => \$config{'show_publisher'}
    )->pack( -side => 'left' );
    $search_page->Label( -text => 'Allow searches of music published by:' )
      ->pack( -side => 'top' );
    my $checkbox_frame = $search_page->Frame()->pack( -fill => 'x' );
    $checkbox_frame->Checkbutton(
        -text     => 'ASCAP',
        -variable => \$config{'search_ascap'}
    )->pack( -side => 'left', -expand => 1 );
    $checkbox_frame->Checkbutton(
        -text     => 'BMI',
        -variable => \$config{'search_bmi'}
    )->pack( -side => 'left', -expand => 1 );
    $checkbox_frame->Checkbutton(
        -text     => 'Other',
        -variable => \$config{'search_other'}
    )->pack( -side => 'left', -expand => 1 );

    my $mp3frame = $other_page->Frame()->pack( -fill => 'x' );
    $mp3frame->Label( -text => "MP3 Player" )->pack( -side => 'left' );
    $mp3frame->Button(
        -text    => "Choose",
        -command => sub {
            $config{'mp3player'} = $mw->getOpenFile( -title => 'Select File' );
        }
    )->pack( -side => 'right' );
    $mp3frame->Entry(
        -width        => 30,
        -textvariable => \$config{'mp3player'}
    )->pack( -side => 'right' );

    my $numdyn_frame = $other_page->Frame()->pack( -fill => 'x' );
    $numdyn_frame->Label( -text => "Number of Dynamic Documents To Show" )
      ->pack( -side => 'left' );
    $numdyn_frame->Entry(
        -width        => 2,
        -textvariable => \$savefile_max
    )->pack( -side => 'right' );

    my $httpq_frame = $other_page->Frame()->pack( -fill => 'x' );
    $httpq_frame->Label( -text => "httpQ Password (WinAmp only, optional)" )
      ->pack( -side => 'left' );
    $httpq_frame->Entry(
        -width        => 8,
        -textvariable => \$config{'httpq_pw'}
    )->pack( -side => 'right' );

    $notebook->pack(
        -expand => "yes",
        -fill   => "both",
        -padx   => 5,
        -pady   => 5,
        -side   => "top"
    );
    my $result = $box->Show();

    if ( $result eq "Ok" )
    {
        if (   ( !$config{'db_name'} )
            || ( !$config{'db_username'} )
            || ( !$config{'db_pass'} )
            || ( !$config{'filepath'} )
            || ( !$config{'savedir'} )
            || ( !$config{'mp3player'} ) )
        {
            infobox( $mw, "Warning", "All fields must be filled in\n" );
            edit_preferences();
        }
        if ( !open( RCFILE, ">$rcfile" ) )
        {
            infobox( $mw, "Warning",
                "Could not open $rcfile for writing. Your preferences will not be saved\n"
            );
        }
        else
        {
            print RCFILE "db_name::$config{'db_name'}\n";
            print RCFILE "db_username::$config{'db_username'}\n";
            print RCFILE "db_pass::$config{'db_pass'}\n";
            print RCFILE "filepath::$config{'filepath'}\n";
            print RCFILE "savedir::$config{'savedir'}\n";
            print RCFILE "mp3player::$config{'mp3player'}\n";
            print RCFILE "savefile_max::$config{'savefile_max'}\n";
            print RCFILE "httpq_pw::$config{'httpq_pw'}\n";
            print RCFILE "search_ascap::$config{'search_ascap'}\n";
            print RCFILE "search_bmi::$config{'search_bmi'}\n";
            print RCFILE "search_other::$config{'search_other'}\n";
            print RCFILE "show_publisher::$config{'show_publisher'}\n";
            close(RCFILE);
        }
    }
    read_rcfile();
}

sub edit_song
{
    my (@selected) = $mainbox->curselection();
    my ( $edit_title, $edit_artist, $edit_category, $edit_publisher,
        $edit_info );
    my $count = $#selected + 1;
    if ( $count == 1 )
    {

        # We're looking to edit one song, so we can choose everything
        my $id = get_song_id( $mainbox, $selected[0] );
        my $query =
          "SELECT title,artist,category,info,publisher from mrvoice where id=$id";
        my (
            $edit_title, $edit_artist, $edit_category,
            $edit_info,  $edit_publisher
          )
          = $dbh->selectrow_array($query);

        my $box = $mw->DialogBox(
            -title          => "Edit Song",
            -buttons        => [ "Edit", "Cancel" ],
            -default_button => "Edit"
        );
        $box->Icon( -image => $icon );
        $box->add( "Label",
            -text =>
              "You may use this form to modify information about a song that is already in the database\n"
        )->pack();
        my $frame1 = $box->add("Frame")->pack( -fill => 'x' );
        $frame1->Label( -text => "Song Title" )->pack( -side => 'left' );
        $frame1->Entry(
            -width        => 30,
            -textvariable => \$edit_title
        )->pack( -side => 'right' );
        my $frame2 = $box->add("Frame")->pack( -fill => 'x' );
        $frame2->Label( -text => "Artist" )->pack( -side => 'left' );
        $frame2->Entry(
            -width        => 30,
            -textvariable => \$edit_artist
        )->pack( -side => 'right' );
        my $frame3 = $box->add("Frame")->pack( -fill => 'x' );
        $frame3->Label( -text => "Category" )->pack( -side => 'left' );
        my $menu = build_category_menubutton( $frame3, \$edit_category );
        $menu->pack( -side => 'right' );

        my $frame4 = $box->add("Frame")->pack( -fill => 'x' );
        $frame4->Label( -text => "Extra Info" )->pack( -side => 'left' );
        $frame4->Entry(
            -width        => 30,
            -textvariable => \$edit_info
        )->pack( -side => 'right' );
        my $pubframe = $box->add("Frame")->pack( -fill => 'x' );
        $pubframe->Label( -text => 'Publisher' )->pack( -side => 'left' );
        my $pubmenu = $pubframe->Menubutton(
            -text        => 'Choose Publisher',
            -relief      => 'raised',
            -tearoff     => 0,
            -indicatoron => 1
        )->pack( -side => 'right' );

        foreach my $item (@publishers)
        {
            $pubmenu->radiobutton(
                -label    => $item,
                -value    => $item,
                -variable => \$edit_publisher,
                -command  => sub {
                    $pubmenu->configure( -text => $edit_publisher );
                }
            );
        }
        $pubmenu->configure( -text => $edit_publisher );
        my $result = $box->Show();
        if ( $result eq "Edit" )
        {
            $edit_artist = $dbh->quote($edit_artist);
            $edit_title  = $dbh->quote($edit_title);
            $edit_info   = $dbh->quote($edit_info);

            my $query =
              "UPDATE mrvoice SET artist=$edit_artist, title=$edit_title, info=$edit_info, category='$edit_category' WHERE id=$id";
            if ( $dbh->do($query) )
            {
                infobox(
                    $mw,
                    "Song Edited Successfully",
                    "The song was edited successfully."
                );
                $status = "Edited song";
            }
            else
            {
                infobox( $mw, "Error",
                    "There was an error editing the song. No changes made." );
                $status = "Error editing song - no changes made";
            }
        }
        else
        {
            $status = "Cancelled song edit.";
        }
    }
    elsif ( $count > 1 )
    {

        # We're editing multiple songs, so only put up a subset
        # First, convert the indices to song ID's
        my @songids;
        my (
            $clear_artist_cb, $clear_info_cb, $edit_artist,
            $edit_info,       $edit_category
        );
        foreach my $id (@selected)
        {
            my $songid = get_song_id( $mainbox, $id );
            push( @songids, $songid );
        }
        my $box = $mw->DialogBox(
            -title          => "Edit $count Songs",
            -buttons        => [ "Edit", "Cancel" ],
            -default_button => "Edit"
        );
        $box->Icon( -image => $icon );
        $box->add( "Label",
            -text =>
              "You are editing the attributes of $count songs.\nAny changes you make here will be applied to all $count.\n\nTo completely erase a field, use the checkbox beside the field\n"
        )->pack();
        my $frame2 = $box->add("Frame")->pack( -fill => 'x' );
        $frame2->Label( -text => "Artist" )->pack( -side => 'left' );
        $frame2->Checkbutton(
            -text     => "Clear Field",
            -variable => \$clear_artist_cb
        )->pack( -side => 'right' );
        $frame2->Entry(
            -width        => 30,
            -textvariable => \$edit_artist
        )->pack( -side => 'right' );
        my $frame3 = $box->add("Frame")->pack( -fill => 'x' );
        $frame3->Label( -text => "Category" )->pack( -side => 'left' );
        my $menu = build_category_menubutton( $frame3, \$edit_category );
        $menu->pack( -side => 'right' );

        my $frame4 = $box->add("Frame")->pack( -fill => 'x' );
        $frame4->Label( -text => "Extra Info" )->pack( -side => 'left' );
        $frame4->Checkbutton(
            -text     => "Clear Field",
            -variable => \$clear_info_cb
        )->pack( -side => 'right' );
        $frame4->Entry(
            -width        => 30,
            -textvariable => \$edit_info
        )->pack( -side => 'right' );
        my $pubframe = $box->add("Frame")->pack( -fill => 'x' );
        $pubframe->Label( -text => 'Publisher' )->pack( -side => 'left' );
        my $pubmenu = $pubframe->Menubutton(
            -text        => 'Choose Publisher',
            -relief      => 'raised',
            -tearoff     => 0,
            -indicatoron => 1
        )->pack( -side => 'right' );

        foreach my $item (@publishers)
        {
            $pubmenu->radiobutton(
                -label    => $item,
                -value    => $item,
                -variable => \$edit_publisher,
                -command  => sub {
                    $pubmenu->configure( -text => $edit_publisher );
                }
            );
        }
        my $result = $box->Show();
        if (
            ( $result eq "Edit" )
            && (   $edit_artist
                || $edit_category
                || $edit_info
                || $edit_publisher
                || $clear_artist_cb
                || $clear_info_cb )
          )
        {

            # Go into edit loop
            my @querystring;
            my $string;
            $edit_artist = "artist=" . $dbh->quote($edit_artist)
              if $edit_artist;
            $edit_info = "info=" . $dbh->quote($edit_info) if $edit_info;
            $edit_publisher = "publisher=" . $dbh->quote($edit_publisher)
              if $edit_publisher;
            $edit_category = "category=" . $dbh->quote($edit_category)
              if $edit_category;

            $edit_artist = "artist=NULL" if ( $clear_artist_cb == 1 );
            $edit_info   = "info=NULL"   if ( $clear_info_cb == 1 );

            push( @querystring, $edit_artist )    if $edit_artist;
            push( @querystring, $edit_info )      if $edit_info;
            push( @querystring, $edit_publisher ) if $edit_publisher;
            push( @querystring, $edit_category )  if $edit_category;

            $string = join( ", ", @querystring );

            foreach my $songid (@songids)
            {
                my $query = "UPDATE mrvoice SET $string WHERE id=$songid";
                $dbh->do($query);
            }
            $status = "Edited $count songs";
        }
        else
        {
            $status = "Cancelled editing $count songs";
        }
    }
    else
    {
        $status = "No songs selected for editing";
    }
}

sub delete_song
{
    my (@selection) = $mainbox->curselection();
    my $count = $#selection + 1;
    my @ids;
    my $delete_file_cb;
    foreach my $index (@selection)
    {
        push( @ids, get_song_id( $mainbox, $index ) );
    }
    if ( $count >= 1 )
    {
        my $box = $mw->DialogBox(
            -title          => "Confirm Deletion",
            -default_button => "Cancel",
            -buttons        => [ "Delete", "Cancel" ]
        );
        $box->Icon( -image => $icon );
        if ( $count == 1 )
        {
            $box->add( "Label",
                -text =>
                  "About to delete $count song from the database.\nBe sure this is what you want to do!"
            )->pack();
        }
        else
        {
            $box->add( "Label",
                -text =>
                  "About to delete $count songs from the database.\nBe sure this is what you want to do!"
            )->pack();
        }
        $box->add(
            "Checkbutton",
            -text     => "Delete file on disk",
            -variable => \$delete_file_cb
        )->pack();
        my $result = $box->Show();
        if ( $result eq "Delete" )
        {
            foreach my $id (@ids)
            {
                my $filename;
                if ( $delete_file_cb == 1 )
                {
                    my $filequery = "SELECT filename FROM mrvoice WHERE id=$id";
                    ($filename) = $dbh->selectrow_array($filequery);
                }
                my $query = "DELETE FROM mrvoice WHERE id=$id";
                my $sth   = $dbh->prepare($query);
                $sth->execute;
                $sth->finish;
                if ( $delete_file_cb == 1 )
                {
                    my $file = catfile( $config{'filepath'}, $filename );
                    unlink("$file");
                }
                $status = "Deleted $count songs";
            }
        }
        else
        {
            $status = "Cancelled deletion";
        }
    }
    else
    {
        $status = "No song selected for deletion";
    }
}

sub show_about
{
    my $rev    = '$Revision: 1.380 $';
    my $tkver  = Tk->VERSION;
    my $dbiver = DBI->VERSION;
    my $dbdver = DBD::mysql->VERSION;
    $rev =~ s/.*(\d+\.\d+).*/$1/;
    my $string =
      "Mr. Voice Version $version (Revision: $rev)\n\nBy H. Wade Minter <minter\@lunenburg.org>\n\nURL: http://www.lunenburg.org/mrvoice/\n\nTk Version: $tkver\nDBI Version: $dbiver\nDBD Version: $dbdver\n\n(c)2001-2004, Released under the GNU General Public License";
    my $box = $mw->DialogBox(
        -title      => "About Mr. Voice",
        -buttons    => ["OK"],
        -background => 'white'
    );
    my $logo_photo = $mw->Photo( -data => logo_photo() );
    $box->Icon( -image => $icon );
    $box->add(
        "Label",
        -image      => $logo_photo,
        -background => 'white'
    )->pack();
    $box->add(
        "Label",
        -text       => "$string",
        -background => 'white'
    )->pack();
    $box->Show;
}

#STARTCSZ
#sub show_predefined_hotkeys
#{
#    my $box =
#      $mw->DialogBox( -title => "Predefined Hotkeys", -buttons => ["Close"] );
#    $box->Icon( -image => $icon );
#    $box->add( "Label",
#        -text =>
#          "The following hotkeys are always available and may not be changed" )
#      ->pack();
#    $box->add(
#        "Label",
#        -text   => "<Escape> - Stop the currently playing MP3",
#        -anchor => 'nw'
#    )->pack( -fill => 'x' );
#    $box->add(
#        "Label",
#        -text   => "<Control-P> - Play the currently selected song",
#        -anchor => 'nw'
#    )->pack( -fill => 'x' );
#    $box->add(
#        "Label",
#        -text   => "<Enter> - Perform the currently entered search",
#        -anchor => 'nw'
#    )->pack( -fill => 'x' );
#    $box->add(
#        "Label",
#        -text   => "<ALT-t> - The \"Ta-Da\" MIDI",
#        -anchor => 'nw'
#    )->pack( -fill => 'x' );
#    $box->add(
#        "Label",
#        -text   => "<ALT-y> - The \"You're Out\" MIDI",
#        -anchor => 'nw'
#    )->pack( -fill => 'x' );
#    $box->add(
#        "Label",
#        -text   => "<ALT-b> - The Brown Bag MIDI",
#        -anchor => 'nw'
#    )->pack( -fill => 'x' );
#    $box->add(
#        "Label",
#        -text   => "<ALT-g> - The Groaner MIDI",
#        -anchor => 'nw'
#    )->pack( -fill => 'x' );
#    $box->add(
#        "Label",
#        -text   => "<ALT-v> - The Price Is Right theme (Volunteer photos)",
#        -anchor => 'nw'
#    )->pack( -fill => 'x' );
#    $box->Show;
#}

#ENDCSZ

sub wipe_tank
{

    # Clears the holding tank
    $tankbox->delete( 0, 'end' );
}

sub clear_hotkeys
{

    # Backs up the hotkeys, then deletes all of them.

    if ( $lock_hotkeys == 1 )
    {
        $status = "Can't clear all hotkeys - hotkeys locked";
        return;
    }

    backup_hotkeys();
    foreach my $fkeynum ( 1 .. 12 )
    {
        my $fkey = "f$fkeynum";
        $fkeys{$fkey}->{id}       = '';
        $fkeys{$fkey}->{filename} = '';
        $fkeys{$fkey}->{title}    = '';
    }
    $status = "All hotkeys cleared";
}

sub clear_selected
{
    if ( $lock_hotkeys == 1 )
    {
        $status = "Can't clear selected hotkeys - hotkeys locked";
        return;
    }

    # If a hotkey has its checkbox activated, then that hotkey will have
    # its entry cleared.  Then all checkboxes are unselected.

    foreach my $num ( 1 .. 12 )
    {
        my $fkey = "f$num";
        if ( $fkeys_cb{$fkey} == 1 )
        {
            $fkeys{$fkey}->{title}    = '';
            $fkeys{$fkey}->{id}       = '';
            $fkeys{$fkey}->{filename} = '';
        }
        $fkeys_cb{$fkey} = 0;
    }

    $status = "Selected hotkeys cleared";
}

sub launch_tank_playlist
{

    # Launch an m3u playlist from the contents of the holding tank
    my @indices = $tankbox->get( 0, 'end' );
    return if ( $#indices < 0 );
    my ( $fh, $filename ) = tempfile( SUFFIX => '.m3u', UNLINK => 1 );
    print $fh "#EXTM3U\n";
    foreach my $item (@indices)
    {
        my ( $id, $description ) = split( /:/, $item );
        my $file = get_info_from_id($id)->{filename};
        my $path = catfile( $config{filepath}, $file );
        print $fh "$path\n";
    }
    close($fh) or die;
    system("$config{'mp3player'} $filename");
}

sub holding_tank
{
    if ( !Exists($holdingtank) )
    {
        my $arrowdown = $mw->Photo( -data => <<'EOF');
R0lGODlhFgAWAIUAAPwCBAQCBAQGBBwaHDQyNExKTHx6fGxqbFxeXGRiZFRSVDw+PAwKDJSWlOzu7LSytJyenJSSlISGhISChIyOjFRWVDw6PPz+/MTCxLS2tGRmZDQ2NAwODJyanKSmpKSipIyKjHRydBQSFERCRExOTFxaXAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAWABYAAAasQIBwSCwah4FkQKBsDpoBIqFgOCASCYRWm1AUFgRGkdBwPCARiWRCaTwOFYvYSIhcMOiJpJGZaDYcR0IEHXceEQ0fICEWIoJDhHcQHxIHgI9SEHeVG46YUh8OISOen1INCqWmUnOYTUxQAU9NUlRWWFtbCiRgrYNlZ2lriG8lYUd1khETE24gCZeCkRgeFBAQIAeNn9OTlXKrBJoYnKrcoaPmpmSpq3S+7u50QQAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJzaW9uIDIuNQ0KqSBEZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVzZXJ2ZWQuDQpodHRwOi8vd3d3LmRldmVsY29yLmNvbQA7
EOF

        my $arrowup = $mw->Photo( -data => <<'EOF');
R0lGODlhFgAWAIUAAPwCBAQCBGReZDQyNMTCxHx6fPz+/JyWnKyurHx2fDw6PJSSlISGhIyKjIyGjISChLy6vJyanOTm5PTy9OTi5MzKzLSytKSepMTGxMzGzLS2tLSutKymrHRydCQiJCwmLBwWHAwODLy2vHx+fAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAWABYAAAajQIBwSCwaj8RAAMkUBgSDZdP4JBSi06TAcEAkFNLp07BgLLzY5njRcDzO3zB1C4lEGI83Wj58SiYUFRUWdg0XEXFFAwIYGRoWGxwRZQUFHZdgRAObmx4fHiChISFKpVlKWUdPaalOAlasp1sHG4myZGZ7Yltsbgu1mUhjdRF5egmxfQJ/gYOFdrZDi40iFgiSCw8jBQmYcpydn6Ego6WorUwGQQAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJzaW9uIDIuNQ0KqSBEZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVzZXJ2ZWQuDQpodHRwOi8vd3d3LmRldmVsY29yLmNvbQA7
EOF

        $holdingtank = $mw->Toplevel();
        $holdingtank->minsize( 35, 2 );
        $holdingtank->withdraw();
        $holdingtank->Icon( -image => $icon );
        bind_hotkeys($holdingtank);
        $holdingtank->bind( "<Control-Key-p>", [ \&play_mp3, "Holding" ] );
        $holdingtank->title("Holding Tank");
        $holdingtank->Label(
            -text => "I'm Mr. Holding Tank - you put your songs in me." )->pack;
        $holdingtank->Label(
            -text => "Drag a song here from the main search box to store it" )
          ->pack;
        my $playlistbutton = $holdingtank->Button(
            -text    => "Launch Playlist",
            -command => \&launch_tank_playlist
        )->pack();
        $playlistbutton->configure(
            -bg               => 'dodgerblue',
            -activebackground => 'royalblue'
        );
        my $buttonframe = $holdingtank->Frame()->pack(
            -side => 'bottom',
            -fill => 'x'
        );
        $holdingtank->Button(
            -image   => $arrowup,
            -command => [ \&move_tank, "-1" ]
        )->pack( -side => 'left' );
        $holdingtank->Button(
            -image   => $arrowdown,
            -command => [ \&move_tank, "1" ]
        )->pack( -side => 'right' );
        $tankbox = $holdingtank->Scrolled(
            'Listbox',
            -scrollbars => 'osoe',
            -width      => 50,
            -setgrid    => 1,
            -selectmode => 'extended'
          )->pack(
            -fill   => 'both',
            -expand => 1,
            -padx   => 2,
            -side   => 'top'
          );
        $tank_token = $tankbox->DragDrop(
            -event        => '<B1-Motion>',
            -sitetypes    => ['Local'],
            -startcommand => sub { StartDrag($tank_token) }
        );
        $tankbox->DropSite(
            -droptypes   => ['Local'],
            -dropcommand => [ \&Tank_Drop, $dnd_token ]
        );
        $tankbox->bind( "<Double-Button-1>", \&play_mp3 );

        #  $tankbox->bind("<Control-Key-p>", [\&play_mp3, "Holding"]);
        $tankbox->bind( "<Button-1>", sub { $tankbox->focus(); } );
        &BindMouseWheel($tankbox);
        my $playbutton = $buttonframe->Button(
            -text    => "Play Now",
            -command => [ \&play_mp3, $tankbox ]
        )->pack( -side => 'left' );
        $playbutton->configure(
            -bg               => 'green',
            -activebackground => 'SpringGreen2'
        );
        my $stopbutton = $buttonframe->Button(
            -text    => "Stop Now",
            -command => \&stop_mp3
        )->pack( -side => 'left' );
        $stopbutton->configure(
            -bg               => 'red',
            -activebackground => 'tomato3'
        );
        $buttonframe->Button(
            -text    => "Close",
            -command => sub { $holdingtank->withdraw }
        )->pack( -side => 'right' );
        $buttonframe->Button(
            -text    => "Clear Selected",
            -command => \&clear_tank
        )->pack( -side => 'right' );
        $holdingtank->update();
        $holdingtank->deiconify();
        $holdingtank->raise();
    }
    else
    {
        $holdingtank->deiconify();
        $holdingtank->raise();
    }
}

sub move_tank
{

    # Blatantly cribbed from Mastering Perl/Tk's Tk::NavListbox example
    my $lb          = $tankbox;
    my $direction   = shift;
    my (@selection) = $lb->curselection;
    my $index       = $selection[0];

    # Sanity checks
    return if ( $index == 0 && $direction == -1 );
    return if ( $index == $lb->size() - 1 && $direction == 1 );

    my $newindex = $index + $direction;

    my $item = $lb->get($index);
    $lb->delete($index);
    $lb->insert( $newindex, $item );
    $lb->selectionSet($newindex);
}

sub clear_tank
{
    my @selected = reverse( $tankbox->curselection() );
    foreach my $item (@selected)
    {
        $tankbox->delete($item);
    }
}

sub list_hotkeys
{
    if ( !Exists($hotkeysbox) )
    {
        my %fkeys_frame;
        my %fkeys_chkb;
        my %fkeys_label;
        $hotkeysbox = $mw->Toplevel();
        $hotkeysbox->withdraw();
        $hotkeysbox->Icon( -image => $icon );
        bind_hotkeys($hotkeysbox);
        $hotkeysbox->bind( "<Control-Key-p>", [ \&play_mp3, "Current" ] );
        $hotkeysbox->title("Hotkeys");
        $hotkeysbox->Label( -text => "Currently defined hotkeys:" )->pack;

        foreach my $num ( 1 .. 12 )
        {
            my $fkey = "f$num";
            $fkeys_frame{$fkey} = $hotkeysbox->Frame()->pack( -fill => 'x' );
            $fkeys_chkb{$fkey} = $fkeys_frame{$fkey}->Checkbutton(
                -text     => uc("$fkey: "),
                -variable => \$fkeys_cb{$fkey}
            )->pack( -side => 'left' );
            $fkeys_label{$fkey} = $fkeys_frame{$fkey}->Label(
                -textvariable => \$fkeys{$fkey}->{title},
                -anchor       => 'w'
            )->pack( -side => 'left' );
            $fkeys_frame{$fkey}->DropSite(
                -droptypes   => ['Local'],
                -dropcommand => [ \&Hotkey_Drop, "$fkey" ]
            );
            $fkeys_chkb{$fkey}->DropSite(
                -droptypes   => ['Local'],
                -dropcommand => [ \&Hotkey_Drop, "$fkey" ]
            );
            $fkeys_label{$fkey}->DropSite(
                -droptypes   => ['Local'],
                -dropcommand => [ \&Hotkey_Drop, "$fkey" ]
            );
        }
        my $buttonframe = $hotkeysbox->Frame()->pack(
            -side => 'bottom',
            -fill => 'x'
        );
        $buttonframe->Button(
            -text    => "Close",
            -command => sub { $hotkeysbox->withdraw }
        )->pack( -side => 'left' );
        $buttonframe->Button(
            -text    => "Clear Selected",
            -command => \&clear_selected
        )->pack( -side => 'right' );
        $hotkeysbox->update();
        $hotkeysbox->deiconify();
        $hotkeysbox->raise();
    }
    else
    {
        $hotkeysbox->deiconify();
        $hotkeysbox->raise();
    }
}

sub get_song_id
{

    # This gets the current selection for the index passed in, and returns
    # the database ID for that song.

    my ( $box, $index ) = @_;
    my $selection = $box->get($index);
    my ($id) = split /:/, $selection;
    return ($id);
}

sub update_time
{
    $mw->Busy( -recurse => 1 );
    my $percent_done = 0;
    my $updated      = 0;
    my $progressbox  = $mw->Toplevel();
    $progressbox->withdraw();
    $progressbox->Icon( -image => $icon );
    $progressbox->title("Time Update");
    $progressbox->Label( -text => "Time Update Status (Percentage)" )
      ->pack( -side => 'top' );
    my $pb = $progressbox->ProgressBar( -width => 150 )->pack( -side => 'top' );
    my $progress_frame1 = $progressbox->Frame()->pack( -side => 'top' );
    $progress_frame1->Label( -text => "Number of files updated: " )
      ->pack( -side => 'left' );
    $progress_frame1->Label( -textvariable => \$updated )
      ->pack( -side => 'left' );
    my $donebutton = $progressbox->Button(
        -text    => "Done",
        -state   => 'disabled',
        -command => sub { $progressbox->destroy }
    )->pack( -side => 'bottom' );
    $progressbox->update();
    $progressbox->deiconify();
    $progressbox->raise();

    my $count        = 0;
    my $query        = "SELECT id,filename,time FROM mrvoice";
    my $get_rows_sth = $dbh->prepare($query);
    $get_rows_sth->execute;
    my $numrows      = $get_rows_sth->rows;
    my $update_query = "UPDATE mrvoice SET time=? WHERE id=?";
    my $update_sth   = $dbh->prepare($update_query);
    while ( my @table_row = $get_rows_sth->fetchrow_array )
    {
        my ( $id, $filename, $time ) = @table_row;
        my $newtime =
          get_songlength( catfile( $config{'filepath'}, $filename ) );
        if ( $newtime ne $time )
        {
            $update_sth->execute( $newtime, $id );
            $updated++;
        }
        $count++;
        $percent_done = int( ( $count / $numrows ) * 100 );
        $pb->set($percent_done);
        $progressbox->update();
    }
    $get_rows_sth->finish;
    $donebutton->configure( -state => 'active' );
    $donebutton->focus;
    $progressbox->update();
    $mw->Unbusy( -recurse => 1 );
    $status = "Updated times on $updated files";
}

sub get_info_from_id
{

    # Returns a hash reference containing all the info for a specified ID

    my $id = shift;
    my %info;
    my $query          = "SELECT * FROM mrvoice WHERE id=$id";
    my $result_hashref = $dbh->selectrow_hashref($query);
    $info{filename} = $result_hashref->{filename};
    $info{title}    = $result_hashref->{title};
    $info{artist}   = $result_hashref->{artist};
    if ( $info{artist} )
    {
        $info{fulltitle} = "\"$info{title}\" by $info{artist}";
    }
    else
    {
        $info{fulltitle} = $info{title};
    }
    $info{info} = $result_hashref->{info};
    return \%info;
}

sub validate_id
{
    my $id      = shift;
    my $query   = "SELECT * FROM mrvoice WHERE id=$id";
    my $numrows = $dbh->do($query);
    return $numrows == 1 ? 1 : 0;
}

sub stop_mp3
{

    # Sends a stop command to the MP3 player.  Works for both xmms and WinAmp,
    # though not particularly cleanly.

    system("$config{'mp3player'} --stop");
    $status = "Playing Stopped";
}

sub play_mp3
{

    my ( $statustitle, $statusartist, $filename );
    my $songstatusstring;
    my $widget = shift;
    my $action = shift;

    # See if the request is coming from one our hotkeys first...
    if ( $action =~ /^f\d+/ )
    {
        $filename = $fkeys{$action}->{filename};
    }
    elsif ( $action =~ /^ALT/ )
    {

        #STARTCSZ
        #if    ( $action eq "ALT-T" ) { $filename = $altt; }
        #elsif ( $action eq "ALT-Y" ) { $filename = $alty; }
        #elsif ( $action eq "ALT-B" ) { $filename = $altb; }
        #elsif ( $action eq "ALT-G" ) { $filename = $altg; }
        #elsif ( $action eq "ALT-V" ) { $filename = $altv; }

        #ENDCSZ
    }
    elsif ( $action eq "addsong" )
    {

        # if we're playing from the "add new song" dialog, the full path
        # will already be set.
        $filename = shift @_;
        if ( $^O eq "MSWin32" )
        {
            $filename = Win32::GetShortPathName($filename);
        }
    }
    else
    {
        my $box;
        if ( $action eq "Current" )
        {
            $box = $mainbox;
        }
        elsif ( $action eq "Holding" )
        {
            $box = $tankbox;
        }
        else
        {
            $box = $widget;
        }

        # We only care about playing one song
        my (@selection) = $box->curselection();
        my $id = get_song_id( $box, $selection[0] );
        if ($id)
        {
            my $id_ref = get_info_from_id($id);
            $filename     = $id_ref->{filename};
            $statustitle  = $id_ref->{title};
            $statusartist = $id_ref->{artist};
        }
    }
    if ( $action eq "addsong" )
    {
        $status = "Previewing file $filename";
        system("$config{'mp3player'} $filename");
    }
    elsif ($filename)
    {
        if ( $action =~ /^f.*/ )
        {
            my $fkey = lc($action);
            $songstatusstring = $fkeys{$fkey}->{title};
        }
        elsif ( $action =~ /^ALT/ )
        {
            $songstatusstring = $filename;
        }
        elsif ($statusartist)
        {
            $songstatusstring = "\"$statustitle\" by $statusartist";
        }
        else
        {
            $songstatusstring = "\"$statustitle\"";
        }
        $status = "Playing $songstatusstring";
        my $file = catfile( $config{'filepath'}, $filename );
        system("$config{'mp3player'} $file");
    }
}

sub get_songlength
{

    #Generic function to return the length of a song in mm:ss format.
    #Currently supports OGG, MP3 and WAV, with the appropriate modules.

    my $file = shift;
    my $time = "";
    if ( $file =~ /.*\.mp3$/i )
    {

        # It's an MP3 file
        my $info   = get_mp3info("$file");
        my $minute = $info->{MM};
        $minute = "0$minute" if ( $minute < 10 );
        my $second = $info->{SS};
        $second = "0$second" if ( $second < 10 );
        $time = "[$minute:$second]";
    }
    elsif ( $file =~ /\.wav$/i )
    {

        # It's a WAV file
        my $wav = new Audio::Wav;
        my $read;
        eval { $read = $wav->read("$file") };
        if ( !$@ )
        {
            my $audio_seconds = int( $read->length_seconds() );
            my $minute        = int( $audio_seconds / 60 );
            $minute = "0$minute" if ( $minute < 10 );
            my $second = $audio_seconds % 60;
            $second = "0$second" if ( $second < 10 );
            $time = "[$minute:$second]";
        }
        else
        {
            $time = "[??:??]";
        }
    }
    elsif ( $file =~ /\.ogg$/i )
    {

        #It's an Ogg Vorbis file.
        my $ogg = Ogg::Vorbis::Header::PurePerl->new($file);

        my $audio_seconds = $ogg->info->{length};
        my $minute        = int( $audio_seconds / 60 );
        $minute = "0$minute" if ( $minute < 10 );
        my $second = $audio_seconds % 60;
        $second = "0$second" if ( $second < 10 );
        $time = "[$minute:$second]";
    }
    elsif ( ( $file =~ /\.wma$/i ) && ( $^O eq "MSWin32" ) )
    {

        # It's a Windows Media file
        my $wma           = Audio::WMA->new($file);
        my $info          = $wma->info();
        my $audio_seconds = $info->{playtime_seconds};
        my $minute        = int( $audio_seconds / 60 );
        $minute = "0$minute" if ( $minute < 10 );
        my $second = $audio_seconds % 60;
        $second = "0$second" if ( $second < 10 );
        $time = "[$minute:$second]";
    }
    elsif ( ( $file =~ /\.m3u$/i ) || ( $file =~ /\.pls$/i ) )
    {

        #It's a playlist
        $time = "[PLAYLIST]";
    }
    else
    {

        # Unsupported file type
        $time = "[??:??]";
    }
    return ($time);
}

sub do_search
{
    my ( $datestring, $startdate, $enddate );
    if ( ( $_[0] ) && ( $_[0] eq "timespan" ) )
    {
        my $date = DateCalc( "today", "- $_[1]" );
        $date =~ /^(\d{4})(\d{2})(\d{2}).*?/;
        my $year  = $1;
        my $month = $2;
        my $day   = $3;
        $datestring = "$year-$month-$day";
    }
    elsif ( ( $_[0] ) && ( $_[0] eq "range" ) )
    {
        $startdate = $_[1];
        $enddate   = $_[2];
    }
    $anyfield =~ s/^\s*(.*?)\s*$/$1/ if ($anyfield);
    $title    =~ s/^\s*(.*?)\s*$/$1/ if ($title);
    $artist   =~ s/^\s*(.*?)\s*$/$1/ if ($artist);
    $cattext  =~ s/^\s*(.*?)\s*$/$1/ if ($cattext);
    $status = "Starting search...";
    $mw->Busy( -recurse => 1 );
    $mainbox->delete( 0, 'end' );
    my $query =
      "SELECT mrvoice.id,categories.description,mrvoice.info,mrvoice.artist,mrvoice.title,mrvoice.filename,mrvoice.time,mrvoice.publisher FROM mrvoice,categories WHERE mrvoice.category=categories.code ";
    $query = $query . "AND publisher != 'ASCAP' "
      if ( $config{'search_ascap'} == 0 );
    $query = $query . "AND publisher != 'BMI' "
      if ( $config{'search_bmi'} == 0 );
    $query = $query . "AND publisher != 'OTHER' "
      if ( $config{'search_other'} == 0 );
    $query = $query . "AND modtime >= '$datestring' "
      if ( ( $_[0] ) && ( $_[0] eq "timespan" ) );
    $query = $query . "AND modtime >= '$startdate' AND modtime <= '$enddate' "
      if ( ( $_[0] ) && ( $_[0] eq "range" ) );
    $query = $query . "AND category='$category' " if ( $category ne "Any" );

    if ($anyfield)
    {
        $query = $query
          . "AND ( info LIKE '%$anyfield%' OR title LIKE '%$anyfield%' OR artist LIKE '%$anyfield%') ";
    }
    else
    {
        $query = $query . "AND info LIKE '%$cattext%' "  if ($cattext);
        $query = $query . "AND title LIKE '%$title%' "   if ($title);
        $query = $query . "AND artist LIKE '%$artist%' " if ($artist);
    }
    $query = $query . "ORDER BY category,info,title";
    my $starttime = gettimeofday();
    my $sth       = $dbh->prepare($query);
    if ( !$sth->execute )
    {
        infobox(
            $mw,
            "Database Error",
            "Your search failed with the following database error:\n"
              . $sth->errstr
        );
        $status = "Search failed with database error";
        $mw->Unbusy( -recurse => 1 );
        return (1);
    }
    my $numrows = $sth->rows;
    while ( my $row_hashref = $sth->fetchrow_hashref )
    {

        if ( -e catfile( $config{'filepath'}, $row_hashref->{filename} ) )
        {
            my $string = "$row_hashref->{id}:($row_hashref->{description}";
            $string = $string . " - $row_hashref->{info}"
              if ( $row_hashref->{info} );
            $string = $string . ") - \"$row_hashref->{title}\"";
            $string = $string . " by $row_hashref->{artist}"
              if ( $row_hashref->{artist} );
            $string = $string . " $row_hashref->{time}";
            $string = $string . " ($row_hashref->{publisher})"
              if ( $config{'show_publisher'} == 1 );
            $mainbox->insert( 'end', $string );
        }
        else
        {
            $numrows--;
        }
    }
    if ( $numrows > 0 )
    {
        $mainbox->selectionSet(0);
    }
    $sth->finish;
    my $endtime = gettimeofday();
    my $diff = sprintf( "%.2f", $endtime - $starttime );
    $cattext  = "";
    $title    = "";
    $artist   = "";
    $anyfield = "";
    $category = "Any";
    $longcat  = "Any Category";
    $mw->Unbusy( -recurse => 1 );

    $status = sprintf( "Displaying %d search result%s ",
        $numrows, $numrows == 1 ? "" : "s" );
    $status .= "($diff seconds elapsed)";
    $mainbox->yview( 'scroll', 1, 'units' );
    $mainbox->update;
    $mainbox->yview( 'scroll', -1, 'units' );
}

sub return_longcat
{
    my $category = shift;
    my $query    = "SELECT description FROM categories WHERE code='$category'";
    my $longcat_ref = $dbh->selectrow_hashref($query);
    return ( $longcat_ref->{description} );
}

sub build_main_categories_menu
{

    # This builds the categories menu in the search area.  First, it deletes
    # all entries from the menu.  Then it queries the categories table in
    # the database and builds a menu, with one radiobutton entry per
    # category.  This ensures that adding or deleting categories will
    # cause the menu to reflect the most current information.

    # Remove old entries
    my $catmenu = shift;
    $catmenu->delete( 0, 'end' );
    $catmenu->configure( -tearoff => 0 );

    # Query the database for new ones.
    $catmenu->radiobutton(
        -label    => "Any category",
        -value    => "Any",
        -variable => \$category,
        -command  => sub {
            $longcat = "Any Category";
        }
    );
    my $query = "SELECT * from categories ORDER BY description";
    my $sth   = $dbh->prepare($query);
    $sth->execute or die "can't execute the query: $DBI::errstr\n";
    while ( my $cat_hashref = $sth->fetchrow_hashref )
    {
        $catmenu->radiobutton(
            -label    => $cat_hashref->{description},
            -value    => $cat_hashref->{code},
            -variable => \$category,
            -command  => sub {
                $longcat = return_longcat($category);
            }
        );
    }
    $sth->finish;
}

sub do_exit
{

    # Disconnects from the database, attempts to close the MP3 player, and
    # exits the program.

    my $box = $mw->Dialog(
        -title   => "Exit Mr. Voice",
        -text    => "Exit Mr. Voice?",
        -bitmap  => "question",
        -buttons => [ "Yes", "No" ]
    );
    $box->Icon( -image => $icon );
    my $choice = $box->Show();

    if ( $choice =~ /yes/i )
    {
        $dbh->disconnect;
        if ( "$^O" eq "MSWin32" )
        {

            # Close the MP3 player on a Windows system
            Win32::Process::KillProcess( $mp3_pid, 1 );
        }
        else
        {

            # Close the MP3 player on a Unix system.
            kill( 15, $mp3_pid );
        }
        Tk::exit;
        close(STDERR);
        close(STDOUT);
    }
}

sub rightclick_menu
{

    # Bound to the search results box, this function binds the creation
    # of a popup menu to the right mouse button. The menu allows you to
    # play, edit, or delete the current song.  The right-click finds the
    # nearest search result to your mouse, and activates it.

    my $rightmenu = $mw->Menu(
        -menuitems => [
            [
                "command" => "Play This Song",
                -command => [ \&play_mp3, $mainbox ]
            ],
            [
                "command" => "Edit This Song",
                -command  => \&edit_song
            ],
            [
                "command" => "Delete This Song",
                -command  => \&delete_song
            ]
        ],
        -tearoff => 0
    );

    $rightmenu->Popup(
        -popover   => 'cursor',
        -popanchor => 'nw'
    );
}

sub read_rcfile
{

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
    }
    else
    {
        infobox(
            $mw,
            "Configuration not found",
            "You don't appear to have configured Mr. Voice before.\nStarting configuration now\n"
        );
        edit_preferences();
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

sub StartDrag
{

    # Starts the drag for the hotkey drag-and-drop.
    my $sound_icon = $mw->Photo( -data => soundicon_gif() );

    my ($token) = @_;
    $current_token = $token;
    my $widget = $current_token->parent;
    my $event  = $widget->XEvent;
    my $index  = $widget->nearest( $event->y );
    if ( defined $index )
    {
        $current_token->configure( -image => $sound_icon );
        my ( $X, $Y ) = ( $event->X, $event->Y );
        $current_token->raise;
        $current_token->deiconify;
        $current_token->FindSite( $X, $Y, $event );
    }
}

sub Hotkey_Drop
{

    # Assigns the dragged token to the hotkey that it's dropped onto.

    if ( $lock_hotkeys == 1 )
    {
        $status = "Can't drop hotkey - hotkeys locked";
        return;
    }
    my ($fkey_var)  = @_;
    my $widget      = $current_token->parent;
    my (@selection) = $widget->curselection();
    my $id       = get_song_id( $widget, $selection[0] );
    my $filename = get_info_from_id($id)->{filename};
    my $title    = get_info_from_id($id)->{fulltitle};
    $fkeys{$fkey_var}->{id}       = $id;
    $fkeys{$fkey_var}->{filename} = $filename;
    $fkeys{$fkey_var}->{title}    = $title;
}

sub Tank_Drop
{
    my ($dnd_source) = @_;
    my $parent       = $dnd_source->parent;
    my (@indices)    = $parent->curselection();
    foreach my $index (@indices)
    {
        my $entry = $parent->get($index);
        $tankbox->insert( 'end', $entry );
    }
    if ( $#indices > 1 )
    {
        $parent->selectionClear( 0, 'end' );
    }
}

#########
# MAIN PROGRAM
#########
$mw = MainWindow->new;
$mw->withdraw();
my $menubar = $mw->Menu;
$mw->configure( -menu => $menubar );
$mw->geometry("+0+0");
$mw->title("Mr. Voice");
$mw->minsize( 67, 2 );
$mw->protocol( 'WM_DELETE_WINDOW', \&do_exit );
$icon = $mw->Pixmap( -data => icon_data() );
$mw->Icon( -image => $icon );

read_rcfile();

if (
    !(
        $dbh = DBI->connect(
            "DBI:mysql:$config{'db_name'}", $config{'db_username'},
            $config{'db_pass'}
        )
    )
  )
{
    my $box = $mw->DialogBox( -title => "Fatal Error", -buttons => ["Ok"] );
    $box->Icon( -image => $icon );
    $box->add( "Label", -text => "Could not connect to database." )->pack();
    $box->add( "Label",
        -text =>
          "Make sure your database configuration is correct, and that your database is running."
    )->pack();
    $box->add( "Label",
        -text =>
          "The preferences menu will now pop up for you to check or set any configuration options."
    )->pack();
    $box->add( "Label",
        -text =>
          "After you set the preferences, Mr. Voice will exit. You will need to restart to test your changes."
    )->pack();
    $box->add( "Label", -text => "Database returned error: $DBI::errstr" )
      ->pack();
    my $result = $box->Show();

    if ($result)
    {
        edit_preferences();
        die "Died with database error $DBI::errstr\n";
    }
}

if ( !-W $config{'filepath'} )
{
    my $box = $mw->DialogBox( -title => "Fatal Error", -buttons => ["Exit"] );
    $box->Icon( -image => $icon );
    $box->add( "Label", -text => "MP3 Directory unavailable" )->pack();
    $box->add( "Label",
        -text =>
          "The MP3 directory that you set is unavailable.  Check to make sure the directory is correct, and you have permission to access it."
    )->pack();
    $box->add( "Label",
        -text =>
          "The preferences menu will now pop up for you to check or set any configuration options."
    )->pack();
    $box->add( "Label",
        -text =>
          "After you set the preferences, Mr. Voice will exit. You will need to restart to test your changes."
    )->pack();
    $box->add( "Label", -text => "Current MP3 Directory: $config{'filepath'}" )
      ->pack();
    my $result = $box->Show();

    if ($result)
    {
        edit_preferences();
        die("Error accessing MP3 directory\n");
    }
}

if ( !-W $config{'savedir'} )
{
    my $box = $mw->DialogBox( -title => "Warning", -buttons => ["Continue"] );
    $box->Icon( -image => $icon );
    $box->add( "Label", -text => "Hotkey save directory unavailable" )->pack();
    $box->add( "Label",
        -text =>
          "The hotkey save directory is unset or you do not have permission to write to it."
    )->pack();
    $box->add( "Label",
        -text =>
          "While this will not impact the operation of Mr. Voice, you should probably fix it in the File->Preferences menu."
    )->pack();
    $box->add( "Label",
        -text => "Current Hotkey Directory: $config{'savedir'}" )->pack();
    my $result = $box->Show();
}

# Check to see if the database is compatible with version 1.7+
my $query_17 = "SELECT time FROM mrvoice LIMIT 1";
if ( !$dbh->do($query_17) )
{
    my $box = $mw->DialogBox(
        -title   => "Database Update Needed",
        -buttons => [ "Continue", "Quit" ]
    );
    $box->Icon( -image => $icon );
    $box->add( "Label",
        -text => "Your database is not compatible with Mr. Voice 1.7" )->pack();
    $box->add( "Label",
        -text =>
          "With the 1.7 release, some database changes were introduced. Press the Continue button to automatically update your database, or Quit to exit."
    )->pack();
    $box->add( "Label",
        -text =>
          "Continuing will update your tables and record the song times into the database This process may take upwards of a few minutes, depending on the number of songs in your database."
    )->pack();
    my $result = $box->Show();
    if ( $result eq "Continue" )
    {
        my $box = $mw->DialogBox(
            -title   => "Updating Database",
            -buttons => ["Continue"]
        );
        $box->Icon( -image => $icon );
        $box->add( "Label", -text => "Creating temp database..." )->pack();
        my $create_query = "CREATE TABLE mrvoice2 (
   id int(8) NOT NULL auto_increment,
   title varchar(255) NOT NULL,
   artist varchar(255),
   category varchar(8) NOT NULL,
   info varchar(255),
   filename varchar(255) NOT NULL,
   time varchar(10),
   modtime timestamp(6),
   PRIMARY KEY (id))";

        my $create_temp_table_sth = $dbh->prepare($create_query);
        $create_temp_table_sth->execute;
        if ($DBI::err)
        {
            my $string = "$DBI::errstr";
            $box->add( "Label", -text => "FAILED: $string" )->pack();
        }
        else
        {
            $box->add( "Label", -text => "SUCCEEDED" )->pack();
        }
        $create_temp_table_sth->finish;

        my $selectall_query = "SELECT * from mrvoice";

        my $percent_done = 0;
        my $progressbox  = $mw->Toplevel();
        $progressbox->withdraw();
        $progressbox->Icon( -image => $icon );
        $progressbox->title("Song Conversion Status");
        my $pb =
          $progressbox->ProgressBar( -width => 150 )->pack( -side => 'top' );
        $progressbox->Label( -text => "Song Conversion Status (Percentage)" )
          ->pack( -side => 'top' );
        my $donebutton = $progressbox->Button(
            -text    => "Done",
            -state   => 'disabled',
            -command => sub { $progressbox->destroy }
        )->pack( -side => 'top' );
        $progressbox->deiconify();
        $progressbox->raise();

        my $select_all_sth = $dbh->prepare($selectall_query);
        $select_all_sth->execute;
        my $numrows  = $select_all_sth->rows;
        my $rowcount = 0;
        while ( my @table_row = $select_all_sth->fetchrow_array )
        {
            my $tmpid       = $dbh->quote( $table_row[0] );
            my $tmptitle    = $dbh->quote( $table_row[1] );
            my $tmpartist   = $dbh->quote( $table_row[2] );
            my $tmpcategory = $dbh->quote( $table_row[3] );
            my $tmpinfo     = $dbh->quote( $table_row[4] );
            my $tmpfilename = $dbh->quote( $table_row[5] );
            my $tmpmodtime  = $dbh->quote( $table_row[6] );

            my $insert_query =
              "INSERT INTO mrvoice2 (id,title,artist,category,info,filename,time,modtime) VALUES ($tmpid, $tmptitle,";
            if ( $tmpartist eq "" )
            {
                $insert_query .= "NULL,";
            }
            else
            {
                $insert_query .= "$tmpartist,";
            }
            $insert_query .= "$tmpcategory,";
            if ( $tmpinfo eq "" )
            {
                $insert_query .= "NULL,";
            }
            else
            {
                $insert_query .= "$tmpinfo,";
            }
            $insert_query .= "$tmpfilename,";
            my $length =
              get_songlength( catfile( $config{'filepath'}, $table_row[5] ) );
            $insert_query .= "'$length',$tmpmodtime)";
            my $insert_new_table_sth = $dbh->prepare($insert_query);
            $insert_new_table_sth->execute;
            $insert_new_table_sth->finish;
            $rowcount++;
            $percent_done = int( ( $rowcount / $numrows ) * 100 );
            $pb->set($percent_done);
            $progressbox->update();
        }
        $select_all_sth->finish;
        $donebutton->configure( -state => 'active' );
        $progressbox->update();
        while ( Exists($progressbox) )
        {
            $progressbox->update();
        }
        $box->add( "Label", -text => "Building new table...SUCCEEDED" )->pack();
        $dbh->do("RENAME TABLE mrvoice TO oldmrvoice");
        $dbh->do("RENAME TABLE mrvoice2 TO mrvoice");
        $box->add( "Label", -text => "Renaming tables...SUCCEEDED" )->pack();
        $box->add( "Label",
            -text =>
              "The database has been updated - song times are now stored in the database itself\nIn the future, if you modify a file in $config{'filepath'} directly, you will need to run the Update Song Times function from the Songs menu."
        )->pack();
        $box->Show();
    }
    else
    {
        do_exit;
    }
}

# Check to see if the database is compatible with version 1.10+
my $query_110 = "SELECT publisher FROM mrvoice LIMIT 1";
if ( !$dbh->do($query_110) )
{
    $mw->deiconify();
    $mw->raise();
    my $box = $mw->DialogBox(
        -title   => "Database Update Needed",
        -buttons => [ "Continue", "Backup", "Quit" ]
    );
    $box->Icon( -image => $icon );
    $box->add( "Label",
        -text => "Your database is not compatible with Mr. Voice 1.10" )
      ->pack();
    $box->add( "Label",
        -text =>
          "With the 1.10 release, some database changes were introduced.\nPress the Continue button to automatically update your database, or Quit to exit."
    )->pack();
    $box->add( "Label",
        -text =>
          "If you have not taken a backup of your database recently, you should press the Backup button to take one now.\nThat way, if there are any problems withe update, you can get your database back to a known good state."
    )->pack();
    $box->add( "Label",
        -text =>
          "Continuing or backing up will add a new Publisher field to the database."
    )->pack();
    my $result = $box->Show();

    if ( $result eq "Continue" )
    {
        update_110();
    }
    elsif ( $result eq "Backup" )
    {
        dump_database();
        update_110();
    }
    else
    {
        do_exit();
    }
}

# We use the following statement to open the MP3 player asynchronously
# when the Mr. Voice app starts.

if ( !-x $config{'mp3player'} )
{
    infobox(
        $mw,
        "Warning - MP3 Player Not Found",
        "Warning - Could not execute your defined MP3 player:\n\n$config{'mp3player'}\n\nYou may need to select the proper file in the preferences.",
        "warning"
    );
}
else
{
    if ( "$^O" eq "MSWin32" )
    {

        # Start the MP3 player on a Windows system
        my $object;
        Win32::Process::Create( $object, $config{'mp3player'}, '', 1,
            NORMAL_PRIORITY_CLASS(), "." );
        $mp3_pid = $object->GetProcessID();
        sleep(1);
    }
    else
    {

        # Start the MP3 player on a Unix system using fork/exec
        $mp3_pid = fork();
        if ( $mp3_pid == 0 )
        {

            # We're the child of the fork
            exec("$config{'mp3player'}");
        }
    }
}

# Menu bar
# Using the new-style menubars from "Mastering Perl/Tk"
# Define the menus we don't reference later to stop warnings.
our $categoriesmenu;
our $songsmenu;
our $advancedmenu;
our $helpmenu;
our $filemenu;

$filemenu = $menubar->cascade(
    -label     => 'File',
    -tearoff   => 0,
    -menuitems => filemenu_items
);
$dynamicmenu =
  $menubar->entrycget( 'File', -menu )->entrycget( 'Recent Files', -menu );
$hotkeysmenu = $menubar->cascade(
    -label     => 'Hotkeys',
    -tearoff   => 0,
    -menuitems => hotkeysmenu_items
);
$hotkeysmenu->menu->entryconfigure( "Restore Hotkeys", -state => "disabled" );
$categoriesmenu = $menubar->cascade(
    -label     => 'Categories',
    -tearoff   => 0,
    -menuitems => categoriesmenu_items
);
$songsmenu = $menubar->cascade(
    -label     => 'Songs',
    -tearoff   => 0,
    -menuitems => songsmenu_items
);
$advancedmenu = $menubar->cascade(
    -label     => 'Advanced Search',
    -tearoff   => 0,
    -menuitems => advancedmenu_items
);
$helpmenu = $menubar->cascade(
    -label     => 'Help',
    -tearoff   => 0,
    -menuitems => helpmenu_items
);

sub filemenu_items
{
    [
        [
            'command', 'Open Hotkey File',
            -command     => \&open_file,
            -accelerator => 'Ctrl-O'
        ],
        [
            'command', 'Save Hotkeys To A File',
            -command     => \&save_file,
            -accelerator => 'Ctrl-S'
        ],
        '',
        [ 'command', 'Open Holding Tank File',      -command => \&open_tank ],
        [ 'command', 'Save Holding Tank To A File', -command => \&save_tank ],
        '',
        [ 'command', 'Backup Database To A File', -command => \&dump_database ],
        [
            'command',
            'Import Database Backup File',
            -command => \&import_database
        ],
        '',
        [ 'command', 'Preferences',  -command => \&edit_preferences ],
        [ 'cascade', 'Recent Files', -tearoff => 0 ],
        '',
        [ 'command', 'Exit', -command => \&do_exit, -accelerator => 'Ctrl-X' ],
    ];
}

sub hotkeysmenu_items
{
    [
        [
            'command', 'Show Hotkeys',
            -command     => \&list_hotkeys,
            -accelerator => 'Ctrl-H'
        ],
        [ 'command', 'Clear All Hotkeys', -command => \&clear_hotkeys ],
        [
            'command', 'Show Holding Tank',
            -command     => \&holding_tank,
            -accelerator => 'Ctrl-T'
        ],

        #STARTCSZ
        #[
        #    'command',
        #    'Show Predefined Hotkeys',
        #    -command => \&show_predefined_hotkeys
        #],

        #ENDCSZ
        "",
        [ 'command',     'Restore Hotkeys', -command  => \&restore_hotkeys ],
        [ 'checkbutton', 'Lock Hotkeys',    -variable => \$lock_hotkeys ],
    ];
}

sub categoriesmenu_items
{
    [
        [ 'command', 'Add Category',    -command => \&add_category ],
        [ 'command', 'Delete Category', -command => \&delete_category ],
        [ 'command', 'Edit Category',   -command => \&edit_category ],
    ];
}

sub songsmenu_items
{
    [
        [ 'command', 'Add New Song', -command => \&add_new_song ],
        [
            'command',
            'Edit Currently Selected Song(s)',
            -command => \&edit_song
        ],
        [
            'command',
            'Delete Currently Selected Song(s)',
            -command => \&delete_song
        ],
        [ 'command', 'Bulk-Add Songs Into Category', -command => \&bulk_add ],
        [ 'command', 'Update Song Times', -command => \&update_time ],
    ];
}

sub orphans
{

    # Build up a list of all files in the filepath directory
    my @mp3files = glob( catfile( $config{filepath}, "*.mp3" ) );
    my @oggfiles = glob( catfile( $config{filepath}, "*.ogg" ) );
    my @wavfiles = glob( catfile( $config{filepath}, "*.wav" ) );
    my @m3ufiles = glob( catfile( $config{filepath}, "*.m3u" ) );
    my @plsfiles = glob( catfile( $config{filepath}, "*.pls" ) );
    my @wmafiles = glob( catfile( $config{filepath}, "*.wma" ) )
      if ( $^O eq "MSWin32" );
    my @files = ( @mp3files, @oggfiles, @wavfiles, @m3ufiles, @plsfiles );
    push( @files, @wmafiles ) if ( $^O eq "MSWin32" );
    my @orphans;

    # Display a ProgressBar while we scan the files
    $mw->Busy( -recurse => 1 );
    my $percent_done = 0;
    my $file_count   = 0;
    my $progressbox  = $mw->Toplevel();
    $progressbox->withdraw();
    $progressbox->Icon( -image => $icon );
    $progressbox->title("Orphan Search");
    $progressbox->Label( -text => "Checking all files for orphans" )
      ->pack( -side => 'top' );
    my $pb = $progressbox->ProgressBar( -width => 150 )->pack( -side => 'top' );
    my $progress_frame1 = $progressbox->Frame()->pack( -side => 'top' );
    $progressbox->update();
    $progressbox->deiconify();
    $progressbox->raise();

    # Cycle through each file and check whether or not a database entry
    # references it.
    foreach my $file (@files)
    {
        $file = basename($file);
        my $query = "SELECT * FROM mrvoice WHERE filename='$file'";
        my $rv    = $dbh->do($query);
        if ( $rv == 0 )
        {
            push( @orphans, $file );
        }
        $file_count++;
        $percent_done = int( ( $file_count / $#files ) * 100 );
        $pb->set($percent_done);
        $progressbox->update();
    }
    $mw->Unbusy( -recurse => 1 );
    $progressbox->destroy();

    if ( $#orphans == -1 )
    {
        $status = "No orphaned files found";
        return;
    }

    # Create a listbox with the orphans
    my $orphanbox = $mw->Toplevel( -title => "Orphaned Files" );
    $orphanbox->withdraw();
    $orphanbox->Icon( -image => $icon );
    $orphanbox->Label( -text =>
          "The following files are orphans - they are not referenced by\nany entry in the database.  You can remove them without impacting your system.\n\nYou may close this box and do nothing, or select some or all of the files and delete them."
    )->pack( -side => 'top' );
    my $buttonframe =
      $orphanbox->Frame()->pack( -side => 'bottom', -fill => 'x' );
    my $lb = $orphanbox->Scrolled(
        "Listbox",
        -scrollbars => "osoe",
        -setgrid    => 1,
        -width      => 50,
        -height     => 20,
        -selectmode => "extended"
    )->pack( -side => 'top' );
    $buttonframe->Button(
        -text    => 'Close',
        -command => sub { $orphanbox->destroy() }
    )->pack( -side => 'left' );
    $buttonframe->Button(
        -text    => 'Select All',
        -command => sub { $lb->selectionSet( 0, 'end' ) }
    )->pack( -side => 'right' );
    $buttonframe->Button(
        -text    => 'Delete Selected',
        -command => sub {
            my @list = $lb->curselection();
            if ( $#list >= 0 )
            {
                my $deleted = 0;
                foreach my $index (@list)
                {
                    my $filename = $lb->get($index);
                    unlink( catfile( $config{filepath}, $filename ) );
                    $deleted++;
                }
                $status = sprintf( "Deleted %d orphaned file%s",
                    $deleted, $deleted == 1 ? "" : "s" );
            }
            else
            {
                $status = "No files selected to delete";
            }
            $orphanbox->destroy();
        },
    )->pack( -side => 'right' );

    foreach my $orphan (@orphans)
    {
        $lb->insert( 'end', $orphan );
    }

    $orphanbox->update();
    $orphanbox->deiconify();
    $orphanbox->raise();
}

sub advanced_search
{
    my $query = "select modtime from mrvoice order by modtime asc limit 1";
    my $firstdate_ref = $dbh->selectrow_hashref($query);
    my $firstdate     = $firstdate_ref->{modtime};

    $firstdate =~ /(\d\d)(\d\d)(\d\d)/;

    my $start_month = $2;
    my $start_date  = $3;
    my $start_year  = "20$1";

    my @today     = localtime();
    my $end_month = $today[4] + 1;
    my $end_date  = $today[3];
    my $end_year  = $today[5] + 1900;

    my $box = $mw->DialogBox(
        -title   => "Advanced Search",
        -buttons => [ "Ok", "Cancel" ]
    );
    $box->Icon( -image => $icon );
    $box->add( "Label",
        -text =>
          "Use this form to search for songs modified between specific dates." )
      ->pack();
    my $adv_searchframe_start = $box->add( "Frame", -borderwidth => 5 )->pack(
        -side   => 'top',
        -anchor => 'w',
        -fill   => 'x'
    );
    $adv_searchframe_start->Label( -text => "Start date: " )
      ->pack( -side => 'left' );
    my $start_month_button = $adv_searchframe_start->Menubutton(
        -text        => "Month ($start_month)",
        -relief      => 'raised',
        -indicatoron => 1
    )->pack( -side => "left" );
    my $start_month_menu = $start_month_button->menu( -tearoff => 0 );
    $start_month_button->configure( -menu => $start_month_menu );

    for ( my $i = 1 ; $i <= 12 ; $i++ )
    {
        $start_month_menu->radiobutton(
            -label    => $i,
            -value    => $i,
            -variable => \$start_month,
            -command  => sub {
                update_button( $start_month_button, "Month", $start_month );
            }
        );
    }
    $adv_searchframe_start->Label( -text => "/" )->pack( -side => 'left' );

    my $start_date_button = $adv_searchframe_start->Menubutton(
        -text        => "Date ($start_date)",
        -relief      => 'raised',
        -indicatoron => 1
    )->pack( -side => "left" );
    my $start_date_menu = $start_date_button->menu( -tearoff => 0 );
    $start_date_button->configure( -menu => $start_date_menu );
    for ( my $i = 1 ; $i <= 31 ; $i++ )
    {
        $start_date_menu->radiobutton(
            -label    => $i,
            -value    => $i,
            -variable => \$start_date,
            -command  =>
              sub { update_button( $start_date_button, "Date", $start_date ); }
        );
    }
    $adv_searchframe_start->Label( -text => "/" )->pack( -side => 'left' );
    my $start_year_button = $adv_searchframe_start->Menubutton(
        -text        => "Year ($start_year)",
        -relief      => 'raised',
        -indicatoron => 1
    )->pack( -side => "left" );
    my $start_year_menu = $start_year_button->menu( -tearoff => 0 );
    $start_year_button->configure( -menu => $start_year_menu );
    for ( my $i = $start_year ; $i <= $end_year ; $i++ )
    {
        $start_year_menu->radiobutton(
            -label    => $i,
            -value    => $i,
            -variable => \$start_year,
            -command  =>
              sub { update_button( $start_year_button, "Year", $start_year ); }
        );
    }

    my $adv_searchframe_end = $box->add( "Frame", -borderwidth => 5 )->pack(
        -side   => 'top',
        -anchor => 'w',
        -fill   => 'x'
    );
    $adv_searchframe_end->Label( -text => "End date:   " )
      ->pack( -side => 'left' );
    my $end_month_button = $adv_searchframe_end->Menubutton(
        -text        => "Month ($end_month)",
        -relief      => 'raised',
        -indicatoron => 1
    )->pack( -side => "left" );
    my $end_month_menu = $end_month_button->menu( -tearoff => 0 );
    $end_month_button->configure( -menu => $end_month_menu );
    for ( my $i = 1 ; $i <= 12 ; $i++ )
    {
        $end_month_menu->radiobutton(
            -label    => $i,
            -value    => $i,
            -variable => \$end_month,
            -command  =>
              sub { update_button( $end_month_button, "Month", $end_month ); }
        );
    }
    $adv_searchframe_end->Label( -text => "/" )->pack( -side => 'left' );

    my $end_date_button = $adv_searchframe_end->Menubutton(
        -text        => "Date ($end_date)",
        -relief      => 'raised',
        -indicatoron => 1
    )->pack( -side => "left" );
    my $end_date_menu = $end_date_button->menu( -tearoff => 0 );
    $end_date_button->configure( -menu => $end_date_menu );
    for ( my $i = 1 ; $i <= 31 ; $i++ )
    {
        $end_date_menu->radiobutton(
            -label    => $i,
            -value    => $i,
            -variable => \$end_date,
            -command  =>
              sub { update_button( $end_date_button, "Date", $end_date ); }
        );
    }
    $adv_searchframe_end->Label( -text => "/" )->pack( -side => 'left' );
    my $end_year_button = $adv_searchframe_end->Menubutton(
        -text        => "Year ($end_year)",
        -relief      => 'raised',
        -indicatoron => 1
    )->pack( -side => "left" );
    my $end_year_menu = $end_year_button->menu( -tearoff => 0 );
    $end_year_button->configure( -menu => $end_year_menu );
    for ( my $i = $start_year ; $i <= $end_year ; $i++ )
    {
        $end_year_menu->radiobutton(
            -label    => $i,
            -value    => $i,
            -variable => \$end_year,
            -command  =>
              sub { update_button( $end_year_button, "Year", $end_year ); }
        );
    }

    my $button = $box->Show;

    if ( $button eq "Ok" )
    {
        my $errorcode   = 0;
        my $errorstring = "";

        # Check for invalid dates before we send stuff over to the database
        if ( !ParseDate("$start_month/$start_date/$start_year") )
        {
            $errorcode = 1;
            $errorstring .=
              "Your start date of $start_month/$start_date/$start_year is invalid!\n";
        }
        if ( !ParseDate("$end_month/$end_date/$end_year") )
        {
            $errorcode = 1;
            $errorstring .=
              "Your end date of $end_month/$end_date/$end_year is invalid!\n";
        }

        if ( $errorcode == 1 )
        {
            $errorstring .= "Search cancelled - please try again.";
            infobox( $mw, "Invalid dates entered", $errorstring );
        }
        else
        {

            # Go on and do the search - data checks out
            do_search(
                "range",
                "$start_year-$start_month-$start_date",
                "$end_year-$end_month-$end_date"
            );
        }
    }

    else
    {
        $status = "Advanced Search Cancelled";
    }
}

sub update_button()
{
    my ( $button, $label, $value ) = @_;
    $button->configure( -text => "$label ($value)" );
}

sub advancedmenu_items
{
    [
        [
            'command',
            'Show songs added/changed today',
            -command => [ \&do_search, "timespan", "0 days" ]
        ],
        [
            'command',
            'Show songs added/changed in past 7 days',
            -command => [ \&do_search, "timespan", "7 days" ]
        ],
        [
            'command',
            'Show songs added/changed in past 14 days',
            -command => [ \&do_search, "timespan", "14 days" ]
        ],
        [
            'command',
            'Show songs added/changed in past 30 days',
            -command => [ \&do_search, "timespan", "30 days" ]
        ],
        [ 'command', 'Advanced date search', -command => \&advanced_search ],
        [ 'command', 'Find orphaned files',  -command => \&orphans ],
    ];
}

sub helpmenu_items
{
    [ [ 'command', 'About', -command => \&show_about ], ];
}

#####
# The search frame
my $category_frame = $mw->Frame()->pack(
    -side   => 'top',
    -anchor => 'n',
    -fill   => 'x'
);

my $catmenubutton = $category_frame->Menubutton(
    -text        => "Choose Category",
    -relief      => 'raised',
    -indicatoron => 1
  )->pack(
    -side   => 'left',
    -anchor => 'n'
  );
my $catmenu = $catmenubutton->menu();
$catmenubutton->configure( -menu => $catmenu );
$catmenubutton->menu()
  ->configure( -postcommand => [ \&build_main_categories_menu, $catmenu ] );

$category_frame->Label( -text => "Currently Selected: " )->pack(
    -side   => 'left',
    -anchor => 'n'
);
$category_frame->Label( -textvariable => \$longcat )->pack(
    -side   => 'left',
    -anchor => 'n'
);

#
######

#####
# Extra Info
my $extrainfo_frame = $mw->Frame()->pack(
    -side   => 'top',
    -fill   => 'x',
    -anchor => 'n'
);
$extrainfo_frame->Label(
    -text   => "where extra info contains",
    -width  => 25,
    -anchor => 'w'
)->pack( -side => 'left' );
$extrainfo_frame->Entry( -textvariable => \$cattext )->pack( -side => 'left' );

#####
# Artist
my $artist_frame = $mw->Frame()->pack(
    -side   => 'top',
    -fill   => 'x',
    -anchor => 'n'
);
$artist_frame->Label(
    -text   => "Artist contains",
    -width  => 25,
    -anchor => "w"
)->pack( -side => 'left' );
$artist_frame->Entry( -textvariable => \$artist )->pack( -side => 'left' );

#
#####

#####
# Title
my $title_frame = $mw->Frame()->pack(
    -side => 'top',
    -fill => 'x'
);
$title_frame->Label(
    -text   => "Title contains",
    -width  => 25,
    -anchor => 'w'
)->pack( -side => 'left' );
$title_frame->Entry( -textvariable => \$title )->pack( -side => 'left' );

#
#####

#####
# Any Field
my $anyfield_frame = $mw->Frame()->pack(
    -side => 'top',
    -fill => 'x'
);
$anyfield_frame->Label(
    -text   => "OR any field contains",
    -width  => 25,
    -anchor => 'w'
)->pack( -side => 'left' );
$anyfield_frame->Entry( -textvariable => \$anyfield )->pack( -side => 'left' );
#####

#####
# Search Button
my $searchbuttonframe = $mw->Frame()->pack(
    -side => 'top',
    -fill => 'x'
);
$searchbuttonframe->Button(
    -text    => "Do Search",
    -cursor  => 'question_arrow',
    -command => \&do_search
)->pack();

#
#####

#####
# Main display area - search results
our $searchboxframe = $mw->Frame();
$mainbox = $searchboxframe->Scrolled(
    'Listbox',
    -scrollbars => 'osoe',
    -width      => 100,
    -setgrid    => 1,
    -selectmode => "extended"
  )->pack(
    -fill   => 'both',
    -expand => 1,
    -side   => 'top'
  );
$mainbox->bind( "<Double-Button-1>", \&play_mp3 );
$mainbox->bind( "<Button-1>", sub { $mainbox->focus(); } );
$mainbox->bind( "<Button-3>", [ \&rightclick_menu ] );

$dnd_token = $mainbox->DragDrop(
    -event        => '<B1-Motion>',
    -sitetypes    => ['Local'],
    -startcommand => sub { StartDrag($dnd_token) }
);

# This works around brokenness in ActivePerl 5.8.  Thanks Slaven.
$dnd_token->deiconify;
$dnd_token->raise;
$dnd_token->withdraw;

&BindMouseWheel($mainbox);

#
#####

#####
# Status Frame

my $statusframe = $mw->Frame()->pack(
    -side   => 'bottom',
    -anchor => 's',
    -fill   => 'x'
);
our $playbutton = $statusframe->Button(
    -text    => "Play Now",
    -command => [ \&play_mp3, $mainbox ]
)->pack( -side => 'left' );
$playbutton->configure(
    -bg               => 'green',
    -activebackground => 'SpringGreen2'
);
our $stopbutton = $statusframe->Button(
    -text    => "Stop Now",
    -command => \&stop_mp3
)->pack( -side => 'right' );
if ( $^O eq "MSWin32" )
{

    # Windows users can shift-click on the stop button to activate WinAmp's
    # automatic fadeout function.
    # It's not changing the relief back after it's done, though.
    $stopbutton->bindtags(
        [ $stopbutton, ref($stopbutton), $stopbutton->toplevel, 'all' ] );
    $stopbutton->bind(
        "<Shift-ButtonRelease-1>" => sub {
            my $req =
              HTTP::Request->new( GET =>
                  "http://localhost:4800/fadeoutandstop?p=$config{'httpq_pw'}"
              );
            $agent->request($req);
        }
    );
}

$stopbutton->configure(
    -bg               => 'red',
    -activebackground => 'tomato3'
);

$statusframe->Label(
    -textvariable => \$status,
    -relief       => 'sunken'
  )->pack(
    -anchor => 'center',
    -expand => 1,
    -padx   => 5,
    -fill   => 'x'
  );

#
#####

$searchboxframe->pack(
    -side   => 'bottom',
    -fill   => 'both',
    -expand => 1
);

bind_hotkeys($mw);
$mw->bind( "<Control-Key-p>", [ \&play_mp3, "Current" ] );

# If the default hotkey file exists, load that up.
if ( -r catfile( $config{'savedir'}, "default.mrv" ) )
{
    open_file( $mw, catfile( $config{'savedir'}, "default.mrv" ) );
}

$mw->deiconify();
$mw->raise();
MainLoop;
