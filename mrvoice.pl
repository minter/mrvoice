#!/usr/bin/perl 
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';

#use diagnostics;

use strict;    # Works now!  Woo hoo!
use Tk '804.026';
use Tk::DialogBox;
use Tk::Dialog;
use Tk::DragDrop;
use Tk::DropSite;
use Tk::NoteBook;
use Tk::ProgressBar::Mac;
use Tk::DirTree;
use Tk::ItemStyle;
use File::Basename;
use File::Copy;
use File::Spec::Functions;
use DBI;
use MPEG::MP3Info;
use MP4::Info;
use Audio::Wav;
use Date::Manip;
use Time::Local;
use Time::HiRes qw(gettimeofday);
use Ogg::Vorbis::Header::PurePerl;
use File::Glob qw(:globally :nocase);
use File::Temp qw/ tempfile tempdir /;
use Cwd 'abs_path';
use Getopt::Long;

use subs
  qw/filemenu_items hotkeysmenu_items categoriesmenu_items songsmenu_items advancedmenu_items helpmenu_items/;

#########
# AUTHOR: H. Wade Minter <minter@lunenburg.org>
# TITLE: mrvoice.pl
# DESCRIPTION: A Perl/TK frontend for an MP3 database.  Written for
#              ComedyWorx, Raleigh, NC.
#              http://www.comedyworx.com/
# SVN ID: $Id: mrvoice.pl 770 2004-07-13 18:47:37Z minter $
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
our $authenticated = 0;         # Has the user provided the proper password?
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
            '*.m3u', '*.M3U', '*.pls', '*.PLS', '*.m4a', '*.M4A',
            '*.mp4', '*.MP4'
        ]
    ],
    [ 'MP3 Files',    [ '*.mp3', '*.MP3' ] ],
    [ 'WAV Files',    [ '*.wav', '*.WAV' ] ],
    [ 'Vorbis Files', [ '*.ogg', '*.OGG' ] ],
    [ 'AAC Files',    [ '*.m4a', '*.M4A', '*.mp4', '*.MP4' ] ],
    [ 'Playlists',    [ '*.m3u', '*.M3U', '*.pls', '*.PLS' ] ],
    [ 'All Files', '*' ],
];

if ( $^O eq "MSWin32" )
{
    push @{ $mp3types->[0][1] }, ( "*.wma", "*.WMA" );
    my $wmaref = [ [ 'WMA Files', [ '*.wma', '*.WMA' ] ] ];
    splice( @{$mp3types}, 4, 0, @{$wmaref} );
}

my $logfile;
my $userrcfile;
my $debug;
my $help;
my $result = GetOptions(
    'logfile:s' => \$logfile,
    'config=s'  => \$userrcfile,
    'debug'     => \$debug,
    'help'      => \$help
);

if ($help)
{
    print <<EOL;
USAGE: mrvoice [--logfile filename] [--config filename] [--debug]

--logfile filename : Send all program output to the named file, or to a 
                     default file (C:/mrvoice.log on windows, ~/mrvoice.log
                     on Unix).  If you omit the filename and just supply
                     the --logfile flag, you will get the default. 

--config filename  : Use the named file as the Mr. Voice configuration file,
                     instead of the default (which is C:/mrvoice.cfg on 
                     Windows and ~/.mrvoicerc on Unix).

--debug            : Cause a ton of debugging output to get sent to the 
                     screen or to your logfile.  Useful when trying to track
                     down problems.

--help             : Print this information.
EOL

    exit;

}

# Check to see if we're on Windows or Linux, and set the RC file accordingly.
if ( "$^O" eq "MSWin32" )
{
    $rcfile =
      ( $userrcfile eq "" ) ? catfile( "C:", "mrvoice.cfg" ) : $userrcfile;
    $logfile = "" if !defined($logfile);
    $logfile = ( $logfile eq "" ) ? catfile( "C:", "mrvoice.log" ) : $logfile;
    open( STDOUT, ">$logfile" );
    open( STDERR, ">&STDOUT" );
    print "Using Windows logfile $logfile\n" if $debug;

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

    BEGIN
    {
        if ( $^O eq "darwin" )
        {
            require Mac::Applescript;
            Mac::AppleScript->import('RunAppleScript');
        }
    }
    my $homedir = get_homedir();
    $rcfile = ( $userrcfile eq "" ) ? "$homedir/.mrvoicerc" : $userrcfile;
    if ( ( defined($logfile) ) || ( $^O eq "darwin" ) )
    {
        $logfile = ( $logfile eq "" ) ? "$homedir/mrvoice.log" : $logfile;
        open( STDOUT, ">$logfile" );
        open( STDERR, ">&STDOUT" );
        print "Using Unix logfile $logfile\n"
          if ( $debug || ( $^O eq "darwin" ) );
    }
}

#####

my $version = "2.0.3";    # Program version
our $status = "Welcome to Mr. Voice version $version";

sub get_rows
{

    # $sth->rows support still appears to be wonky under Win32.  Go
    # back to the manual way for now.
    my $query = shift;
    print "Getting rows for $query\n" if $debug;
    my $rows = 0;
    my $sth  = $dbh->prepare($query);
    $sth->execute;
    print "$query executed\n" if $debug;
    while ( my @row = $sth->fetchrow_array )
    {
        $rows++;
    }
    print "$query returned $rows rows\n" if $debug;
    return $rows;
}

sub get_homedir
{
    print "Getting home directory\n" if $debug;
    return if ( $^O eq "MSWin32" );
    print "Must be on a Unix system - $^O\n" if $debug;
    my $homedir = "~";
    $homedir =~ s{ ^ ~ ( [^/]* ) }
              { $1 
                   ? (getpwnam($1))[7] 
                   : ( $ENV{HOME} || $ENV{LOGDIR} 
                        || (getpwuid($>))[7]
                     )
              }ex;
    print "Home directory is $homedir\n" if $debug;
    return $homedir;
}

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
    my $token = shift;
    my $e     = $token->parent->XEvent;
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

sub Tk::HList::Button1Motion
{
    return;
}

sub BindMouseWheel
{

    my $w = shift;

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

sub bind_hotkeys
{

    print "Binding hotkeys\n" if $debug;

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

    if ( $^O eq "MSWin32" )
    {
        print "Binding Shift-Escape on Windows\n" if $debug;
        $window->bind(
            "<Shift-Key-Escape>",
            sub {
                my $req =
                  HTTP::Request->new( GET =>
                      "http://localhost:4800/fadeoutandstop?p=$config{'httpq_pw'}"
                  );
                $agent->request($req);
                $status = "Playing Fade-Stopped";
            }
        );
    }
}

sub open_tank
{
    print "Opening saved holding tank file\n" if $debug;

    # Opens a saved holding tank file, overwriting the current contents
    # UGLY HACK
    my $initialdir = $config{'savedir'};
    if ( $^O eq "MSWin32" )
    {
        $initialdir =~ s#/#\\#;
    }
    print "Setting initialdir to $initialdir\n" if $debug;

    # UGLY HACK

    my $selectedfile = $mw->getOpenFile(
        -filetypes  => $holdingtanktypes,
        -initialdir => $initialdir,
        -title      => 'Open a Holding Tank file'
    );
    if ($selectedfile)
    {
        print "Selected file $selectedfile\n" if $debug;
        if ( !-r $selectedfile )
        {
            print "Could not read holding tank file $selectedfile\n" if $debug;
            $status = "Could not open saved file for reading";
            infobox( $mw, "File Error",
                "Could not open file $selectedfile for reading" );
        }
        else
        {
            print "Displaying holding tank (unless it's already up)\n"
              if $debug;
            holding_tank()              if ( !Exists($holdingtank) );
            print "Wiping tank clean\n" if $debug;
            wipe_tank();
            print "Opening tankfile $selectedfile\n" if $debug;
            open( TANKFILE, $selectedfile );
            while ( my $id = <TANKFILE> )
            {
                chomp($id);
                print "Read song id $id from tankfile\n" if $debug;
                next unless ( validate_id($id) );
                my $query =
                  "SELECT mrvoice.id,categories.description,mrvoice.info,mrvoice.artist,mrvoice.title,mrvoice.time from mrvoice,categories where mrvoice.category=categories.code AND mrvoice.id=$id";
                print "Running selectrow_hashref query $query\n" if $debug;
                my $tank_ref = $dbh->selectrow_hashref($query);
                print "Query run\n" if $debug;
                my $string = "($tank_ref->{description}";
                $string = $string . " - $tank_ref->{info}"
                  if ( $tank_ref->{info} );
                $string = $string . ") - \"$tank_ref->{title}\"";
                $string = $string . " by $tank_ref->{artist}"
                  if ( $tank_ref->{artist} );
                $string = $string . " $tank_ref->{time}";
                print "Built string $string, adding to tankbox\n" if $debug;

                $tankbox->add( $id, -data => $id, -text => $string );
                print "Added string $string as id $id\n" if $debug;
            }
        }
        close(TANKFILE);
        $status = "Loaded saved holding tank file $selectedfile";
    }
    else
    {
        print "Cancelled loading of holding tank file\n" if $debug;
        $status = "Cancelled loading of holding tank file";
    }
}

sub save_tank
{
    print "Starting save_tank routine\n" if $debug;
    if ( !Exists($tankbox) )
    {
        print "Returning because tankbox doesn't exist yet\n" if $debug;
        $status = "Can't save the holding tank before you use it...";
        return;
    }
    print "Getting all indices for tankbox\n" if $debug;
    my @indices = return_all_indices($tankbox);

    if ( $#indices < 0 )
    {
        print "Nothing in the tank, returning\n" if $debug;
        $status = "Not saving an empty holding tank";
        return;
    }

    # UGLY HACK
    my $initialdir = $config{'savedir'};
    if ( $^O eq "MSWin32" )
    {
        $initialdir =~ s#/#\\#;
    }
    print "Using initialdir $initialdir\n" if $debug;
    my $selectedfile = $mw->getSaveFile(
        -title            => 'Save a Holding Tank file',
        -defaultextension => ".hld",
        -filetypes        => $holdingtanktypes,
        -initialdir       => $initialdir
    );

    if ($selectedfile)
    {
        print "Using selected file $selectedfile\n" if $debug;
        if ( ( !-w $selectedfile ) && ( -e $selectedfile ) )
        {
            print "Could not open $selectedfile for writing\n" if $debug;
            $status = "Holding tank save failed due to file error";
            infobox( $mw, "File Error!",
                "Could not open file $selectedfile for writing" );
        }
        elsif ( !-w dirname($selectedfile) )
        {
            print "Could not write to directory "
              . dirname($selectedfile) . "\n"
              if $debug;
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
            print "Now selectedfile is $selectedfile.  Opening for writing.\n";
            open( TANKFILE, ">$selectedfile" );
            foreach my $string (@indices)
            {
                print "Got string $string\n" if $debug;
                my ( $id, $desc ) = split( /:/, $string );
                print TANKFILE "$id\n";
                print "Wrote ID $id to tankfile\n" if $debug;
            }
            close TANKFILE;
            $status = "Saved holding tank to $selectedfile";
        }
    }
    else
    {
        print "Cancelled save of holding tank\n" if $debug;
        $status = "Cancelled save of holding tank";
    }
}

sub open_file
{

    print "Opening a saved hotkey file\n" if $debug;

    # Used to open a saved hotkey file.
    # Takes an optional argument.  If the argument is given, we attempt
    # to open the file for reading.  If not, we pop up a file dialog
    # box and get the name of a file first.
    # Once we have the file, we read each line, of the form
    # hotkey_name::mp3_name, and assign the value to the hotkey.
    # Finally, we add this file to our dynamic documents menu.

    if ( $lock_hotkeys == 1 )
    {
        print "Hotkeys were locked.  Returning.\n" if $debug;
        $status = "Can't open saved hotkeys - current hotkeys locked";
        return;
    }

    my $parentwidget = shift;
    my $selectedfile = shift;

    print "Got selectedfile $selectedfile\n" if $debug;

    # UGLY HACK
    my $initialdir = $config{'savedir'};
    if ( $^O eq "MSWin32" )
    {
        $initialdir =~ s#/#\\#;
    }

    print "Initialdir is $initialdir\n" if $debug;

    if ( !$selectedfile )
    {
        print "No selectedfile passed in, popping up a file selector.\n"
          if $debug;
        $selectedfile = $mw->getOpenFile(
            -filetypes  => $hotkeytypes,
            -initialdir => $initialdir,
            -title      => 'Open a Hotkey file'
        );
    }

    if ($selectedfile)
    {
        print "Now selectedfile is $selectedfile\n" if $debug;
        if ( !-r $selectedfile )
        {
            print "$selectedfile is not readable\n" if $debug;
            infobox( $mw, "File Error",
                "Could not open file $selectedfile for reading" );
        }
        else
        {
            print "Clearing hotkeys\n" if $debug;
            clear_hotkeys();
            print "Opening $selectedfile\n" if $debug;
            open( HOTKEYFILE, $selectedfile );
            while (<HOTKEYFILE>)
            {
                chomp;
                my ( $key, $id ) = split(/::/);
                print "Got key $key and ID $id\n" if $debug;
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
                    print "ID $id validated\n" if $debug;
                    $fkeys{$key}->{id}    = $id;
                    $fkeys{$key}->{title} = get_info_from_id($id)->{fulltitle};
                    $fkeys{$key}->{filename} =
                      get_info_from_id($id)->{filename};
                    print "Got filename $fkeys{$key}->{filename}\n" if $debug;
                }
            }
            close(HOTKEYFILE);
            $status = "Loaded hotkey file $selectedfile";
            print "Adding $selectedfile to dynamic documents\n" if $debug;
            dynamic_documents($selectedfile);
            print "Raising hotkeys window" if $debug;
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

    print "Saving hotkey file\n" if $debug;

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
    print "Using initialdir $initialdir\n" if $debug;
    my $selectedfile = $mw->getSaveFile(
        -title            => 'Save a Hotkey file',
        -defaultextension => ".mrv",
        -filetypes        => $hotkeytypes,
        -initialdir       => $initialdir,
    );

    print "Got selectedfile $selectedfile\n" if $debug;

    if ($selectedfile)
    {
        if ( ( !-w $selectedfile ) && ( -e $selectedfile ) )
        {
            print "$selectedfile is not writable\n" if $debug;
            infobox( $mw, "File Error!",
                "Could not open file $selectedfile for writing" );
        }
        elsif ( !-w dirname($selectedfile) )
        {
            my $directory = dirname($selectedfile);
            $directory = Win32::GetShortPathName($directory)
              if ( $^O eq "MSWin32" );
            print "Could not write to directory $directory\n" if $debug;
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
            print
              "Now selectedfile is $selectedfile.  Opening file for writing.\n"
              if $debug;
            open( HOTKEYFILE, ">$selectedfile" );
            foreach my $num ( 1 .. 12 )
            {
                my $keynum = "f$num";
                print HOTKEYFILE "$keynum";
                print HOTKEYFILE "::$fkeys{$keynum}->{id}\n";
                print "Wrote $keynum and $fkeys{$keynum}->{id}\n" if $debug;
            }
            close(HOTKEYFILE);
            $status = "Finished saving hotkeys to $selectedfile";
            print "Adding $selectedfile to dynamic_documents\n" if $debug;
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
    print "Dumping database\n" if $debug;
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime();
    $year += 1900;
    $mon  += 1;
    my $defaultfilename = "database-$year-$mon-$mday.sql";
    print "Default filename is $defaultfilename\n" if $debug;
    my $dumpfile = $mw->getSaveFile(
        -title            => 'Choose Database Export File',
        -defaultextension => ".sql",
        -initialfile      => $defaultfilename,
        -initialdir       => ( $^O eq "MSWin32" ) ? "C:\\" : get_homedir(),
        -filetypes        => $databasefiles
    );
    print "Got dumpfile $dumpfile\n" if $debug;
    my $dirname = dirname($dumpfile);
    $dirname = Win32::GetShortPathName($dirname) if ( $^O eq "MSWin32" );
    print "Got directory $dirname\n" if $debug;
    my $shortdumpfile = basename($dumpfile);
    $shortdumpfile = catfile( $dirname, $shortdumpfile );
    print "Short dumpfile is $shortdumpfile\n" if $debug;

    if ($dumpfile)
    {
        if ( ( !-w $shortdumpfile ) && ( -e $shortdumpfile ) )
        {
            print "Short dumpfile $shortdumpfile is not writable\n" if $debug;
            infobox( $mw, "File Error!",
                "Could not open file $dumpfile for writing" );
        }
        elsif ( !-w $dirname )
        {
            print "Dirname $dirname is not writable\n" if $debug;
            infobox(
                $mw,
                "Directory Error!",
                "Could not write new file to directory $dirname"
            );
        }
        else
        {

            print "Running the SQLite dump. Opening file\n" if $dumpfile;

            # Run the SQLite Dump
            if ( !open( DUMPFILE, ">$dumpfile" ) )
            {
                print "Opening $dumpfile for writing failed\n" if $debug;
                $status = "Could not open $dumpfile for writing";
                return;
            }

            # Get the table schema information
            my $query =
              "SELECT tbl_name,sql FROM sqlite_master WHERE sql NOT NULL";
            print "Running schema query $query\n" if $debug;
            my $sth = $dbh->prepare($query);
            $sth->execute;
            print "Query executed\n" if $debug;
            while ( my $row = $sth->fetchrow_hashref )
            {
                print DUMPFILE "DROP TABLE $row->{tbl_name};\n";
                my $schema = $row->{sql};
                $schema =~ s/\n//g;
                print DUMPFILE "$schema;\n";
                print "Wrote table $row->{tbl_name} with schema $schema\n"
                  if $debug;

                my $data_query = "SELECT * FROM $row->{tbl_name}";
                print "Running data query $data_query\n" if $debug;
                my $data_sth = $dbh->prepare($data_query);
                $data_sth->execute();
                print "Executed data query\n" if $debug;
                while ( my @row = $data_sth->fetchrow_array )
                {
                    my @quoted;
                    print DUMPFILE "INSERT INTO $row->{tbl_name} VALUES (";
                    foreach my $item (@row)
                    {
                        print "Pushing and quoting $item\n" if $debug;
                        push( @quoted, $dbh->quote($item) );
                        print "Pushed " . $dbh->quote($item) . "\n" if $debug;
                    }

                    print DUMPFILE join( ",", @quoted ) . ");\n";
                    print "Ouptut data to dumpfile\n" if $debug;
                }

            }

            close DUMPFILE or die("Could not close $dumpfile after writing");

            print "Displaying infobox\n" if $debug;
            infobox(
                $mw,
                "Database Dumped",
                "The contents of your database have been dumped to the file: $dumpfile\n\nNote: In order to have a full backup, you must also back up the files from the directory: $config{'filepath'} as well as $rcfile and, optionally, the hotkeys from $config{'savedir'}"
            );
            $status = "Database dumped to $dumpfile";
        }
    }
    else
    {
        $status = "Database dump cancelled";
    }
}

sub import_database
{
    print "Importing database\n" if $debug;
    my $dumpfile = $mw->getOpenFile(
        -title            => 'Choose Database Export File',
        -defaultextension => ".sql",
        -initialdir       => ( $^O eq "MSWin32" ) ? "C:\\" : get_homedir(),
        -filetypes        => $databasefiles
    );

    my $shortdumpfile =
      $^O eq "MSWin32" ? Win32::GetShortPathName($dumpfile) : $dumpfile;
    print "Turning $dumpfile into $shortdumpfile\n" if $debug;

    if ($dumpfile)
    {
        if ( !-r $shortdumpfile )
        {
            print "Couldn't read $shortdumpfile\n" if $debug;
            infobox(
                $mw,
                "File Error",
                "Could not open file $dumpfile for reading. Check permissions and try again."
            );
        }
        else
        {

            print "Displaying warning box\n" if $debug;

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
                print "Got an 'Ok' from the warning box\n" if $debug;
                if ( !open( DUMPFILE, $shortdumpfile ) )
                {
                    print "Open of $shortdumpfile failed\n" if $debug;
                    $status = "Cannot open $dumpfile for reading";
                    return;
                }

                my $starttime = gettimeofday();
                my $errstat   = 0;
                $dbh->do("BEGIN");
                print "Begun transaction\n" if $debug;
                while ( my $query = <DUMPFILE> )
                {
                    if ( $query =~ /^--/ )
                    {
                        print
                          "This was a MySQL export, setting errstat and ending\n"
                          if $debug;
                        $errstat = 2;
                        last;
                    }
                    chomp $query;
                    my $sth = $dbh->prepare($query);
                    print "Prepared query $query\n" if $debug;
                    $errstat = 1 if ( !$sth->execute() );
                    print "Executed with errstat $errstat\n" if $debug;
                }
                close(DUMPFILE);
                my $endtime = gettimeofday();
                my $diff = sprintf( "%.2f", $endtime - $starttime );
                if ( $errstat == 1 )
                {
                    $status = "File $dumpfile HAD ERRORS - nothing imported";
                    $dbh->do("ROLLBACK");
                    print "Executed ROLLBACK because of errors\n" if $debug;
                }
                elsif ( $errstat == 2 )
                {
                    $status = "Cannot import old MySQL dump $dumpfile";
                }
                else
                {
                    $status = "Imported $dumpfile in $diff seconds";
                    $dbh->do("COMMIT");
                    print "Did COMMIT\n" if $debug;
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

    print "Getting title and artist\n" if $debug;

    # Returns the title and artist of an MP3 or OGG file
    my $filename = shift;
    print "Got filename $filename\n" if $debug;
    my $title;
    my $artist;

    if ( $filename =~ /.mp3$/i )
    {
        print "Getting mp3 tag info\n" if $debug;
        $filename = Win32::GetShortPathName($filename) if ( $^O eq "MSWin32" );
        my $tag = get_mp3tag($filename);
        $title  = $tag->{TITLE};
        $artist = $tag->{ARTIST};
        print "It's a mp3 with title $title and artist $artist\n" if $debug;
    }
    elsif ( $filename =~ /.ogg/i )
    {
        print "Getting ogg tag info\n" if $debug;
        $filename = Win32::GetShortPathName($filename) if ( $^O eq "MSWin32" );
        my $ogg = Ogg::Vorbis::Header::PurePerl->new($filename);
        ($title)  = $ogg->comment('title');
        ($artist) = $ogg->comment('artist');
        print "Got ogg title $title and artist $artist\n" if $debug;
    }
    elsif ( $filename =~ /.wma/i )
    {
        print "Getting wma tag info\n" if $debug;
        $filename = Win32::GetShortPathName($filename) if ( $^O eq "MSWin32" );
        my $wma     = Audio::WMA->new($filename);
        my $comment = $wma->comment();
        $title  = $comment->{TITLE};
        $artist = $comment->{AUTHOR};
        print "Got wma title $title and artist $artist\n" if $debug;
    }
    elsif ( ( $filename =~ /.m4a/i ) || ( $filename =~ /.mp4/i ) )
    {
        print "It's a AAC file\n" if $debug;
        $filename = Win32::GetShortPathName($filename) if ( $^O eq "MSWin32" );
        my $tag = get_mp4tag($filename);
        $title  = $tag->{NAM};
        $artist = $tag->{ART};
        print "Got AAC title $title and artist $artist\n" if $debug;
    }
    $title  =~ s/^\s*// if $title;
    $artist =~ s/^\s*// if $artist;

    print "Returning title $title and artist $artist\n" if $debug;
    return ( $title, $artist );
}

sub dynamic_documents
{

    print "Doing dynamic documents\n" if $debug;

    # This function takes a filename as an argument.  It then increments
    # a counter to keep track of how many documents we've accessed in this
    # session.
    # It adds the file to the "Recent Files" menu off of Files, and if we're
    # over the user-specified limit, removes the oldest file from the list.

    my $file = shift;
    print "Using file $file\n" if $debug;

    my $fileentry;
    my $counter = 0;
    my $success = 0;
    foreach my $fileentry (@current)
    {
        print "Using $fileentry from the current array\n" if $debug;
        if ( $fileentry eq $file )
        {

            print "We have match with a file already in the list\n" if $debug;

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

        print "The file isn't in our list, so we will add it\n" if $debug;

        # The file isn't in our current list, so we need to add it.
        unshift @current, $file;
        $savefile_count++;
    }

    if ( $#current >= $savefile_max )
    {
        pop(@current);
    }

    # Get rid of the old menu and rebuild from our array
    print "Deleting the old menu and rebuilding\n" if $debug;
    $dynamicmenu->delete( 0, 'end' );
    foreach $fileentry (@current)
    {
        print "Adding $fileentry to the menu\n" if $debug;
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
    print
      "Popping up a generic infobox with parent window $parent_window, title $title, string $string, and type $type\n"
      if $debug;
    $type = "info" if !$type;
    my $box = $parent_window->Dialog(
        -title   => "$title",
        -bitmap  => $type,
        -text    => $string,
        -buttons => ["OK"]
    );
    $box->Icon( -image => $icon );
    print "Showing infobox\n" if $debug;
    $box->Show;
    print "Finished showing infobox\n" if $debug;
}

sub backup_hotkeys
{

    print "Backing up hotkeys\n" if $debug;

    # This saves the contents of the hotkeys to temporary variables, so
    # you can restore them after a file open, etc.

    foreach my $key (%fkeys)
    {
        print "Setting old hotkey $key\n" if $debug;
        $oldfkeys{$key}->{title}    = $fkeys{$key}->{title};
        $oldfkeys{$key}->{id}       = $fkeys{$key}->{id};
        $oldfkeys{$key}->{filename} = $fkeys{$key}->{filename};
    }
    $hotkeysmenu->menu->entryconfigure( "Restore Hotkeys", -state => "normal" );
}

sub restore_hotkeys
{

    print "Restoring old hotkeys\n" if $debug;

    # Replaces the hotkeys with the old ones from backup_hotkeys()
    foreach my $key (%oldfkeys)
    {
        print "Restoring fkey $key\n" if $debug;
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
    print "Building category menubutton\n" if $debug;
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
    print "Preparing category query $query\n" if $debug;
    $sth->execute or die "can't execute the query: $DBI::errstr\n";
    print "Executed category query\n" if $debug;

    while ( my $cat_hashref = $sth->fetchrow_hashref )
    {
        print
          "Using description $cat_hashref->{description} and code $cat_hashref->{code}\n"
          if $debug;
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
    print "Using bulk add\n" if $debug;
    if ( ( $config{write_password} ) && ( !$authenticated ) )
    {
        print "There is a write_password of $config{write_password}\n"
          if $debug;
        if ( !authenticate_user() )
        {
            print "User authentication failed\n" if $debug;
            $status = "You do not have permission to bulk-add songs";
            return;
        }
    }
    my ( @accepted, @rejected, $directory, $longcat, $db_cat );
    my $bulkadd_publisher = "OTHER";
    my $box1              = $mw->DialogBox(
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

    my $pubframe = $box1->add("Frame")->pack( -fill => 'x' );
    $pubframe->Label( -text => 'Publisher: ' )->pack( -side => 'left' );
    my $pubmenu = $pubframe->Menubutton(
        -relief      => 'raised',
        -tearoff     => 0,
        -indicatoron => 1
    )->pack( -side => 'left' );

    foreach my $item (@publishers)
    {
        $pubmenu->radiobutton(
            -label    => $item,
            -value    => $item,
            -variable => \$bulkadd_publisher,
            -command  => sub {
                $pubmenu->configure( -text => $bulkadd_publisher );
            }
        );
    }
    $pubmenu->configure( -text => $bulkadd_publisher );

    my $box1frame3 = $box1->add("Frame")->pack( -fill => 'x' );
    $box1frame3->Label( -text => "Choose Directory: " )
      ->pack( -side => 'left' );
    $box1frame3->Entry( -background => 'white', -textvariable => \$directory )
      ->pack( -side => 'left' );
    $box1frame3->Button(
        -text    => "Select Source Directory",
        -command => sub {
            $directory = $box1->chooseDirectory(
                -title      => 'Choose the directory to bulk-add from',
                -initialdir => ( $^O eq "MSWin32" ) ? "C:\\" : get_homedir()
            );
        }
    )->pack( -side => 'left' );

    my $firstbutton = $box1->Show;
    print "Got a response from the first box\n" if $debug;

    if ( $firstbutton ne "Continue" )
    {
        $status = "Bulk-Add Cancelled";
        return;
    }

    $directory = Win32::GetShortPathName($directory) if ( $^O eq "MSWin32" );
    print "Got directory $directory\n" if $debug;
    if ( !-r $directory )
    {
        print "Directory unreadable, returning\n" if $debug;
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
        print "Didn't get a category, returning until we get one\n" if $debug;
        infobox(
            $mw,
            "Select a category",
            "You must select a category to load the files into.\nPlease try again."
        );
        $status = "Bulk-Add exited due to category error";
        return (1);
    }

    $directory =~ s/(\s)/\\$1/g;
    my @mp3glob = glob( catfile( $directory, "*.mp3" ) );
    my @oggglob = glob( catfile( $directory, "*.ogg" ) );
    my @m4aglob = glob( catfile( $directory, "*.m4a" ) );
    my @mp4glob = glob( catfile( $directory, "*.mp4" ) );
    my @wmaglob = glob( catfile( $directory, "*.wma" ) )
      if ( $^O eq "MSWin32" );
    print "Globbed everything\n" if $debug;

    my @list = ( @mp3glob, @oggglob, @m4aglob, @mp4glob );
    push( @list, @wmaglob ) if ( $^O eq "MSWin32" );

    $mw->Busy( -recurse => 1 );
    print "Gone busy\n" if $debug;
    my $query =
      "INSERT INTO mrvoice (id,title,artist,category,filename,time,modtime,publisher) VALUES (NULL, ?, ?, ?, ?, ?, (SELECT strftime('%s','now')),?)";
    my $sth = $dbh->prepare($query);
    print "Preparing query $query\n" if $debug;
    foreach my $file (@list)
    {
        $file = Win32::GetShortPathName($file) if ( $^O eq "MSWin32" );
        print "Using file $file\n" if $debug;
        my ( $title, $artist ) = get_title_artist($file);
        print "Got title $title and artist $artist\n" if $debug;
        if ($title)
        {

            # Valid title, all we need
            my $time = get_songlength($file);
            print "Got time $time\n" if $debug;
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
            print "Moved file to $db_filename\n" if $debug;
            $sth->execute( $db_title, $db_artist, $db_cat, $db_filename, $time,
                $bulkadd_publisher )
              or die "can't execute the query: $DBI::errstr\n";
            print "Executed sth\n" if $debug;
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

            print "Didn't have a title for this file\n" if $debug;

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
    print "Going unbusy\n" if $debug;

    # Final Summary
    print "Creating summarybox\n" if $debug;
    my $summarybox = $mw->Toplevel( -title => "Bulk-Add Summary" );
    $summarybox->withdraw();
    print "Withdrawed summarybox\n" if $debug;
    $summarybox->Icon( -image => $icon );
    my $lb = $summarybox->Scrolled(
        "Listbox",
        -scrollbars => "osoe",
        -background => 'white',
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
    print "Updating, deiconifying, and raising\n" if $debug;
    $summarybox->update();
    $summarybox->deiconify();
    $summarybox->raise();
    print "Done Updating, deiconifying, and raising\n" if $debug;
}

sub add_category
{
    print "Adding new category\n" if $debug;
    if ( ( $config{write_password} ) && ( !$authenticated ) )
    {
        print "There is a write_password of $config{write_password}\n"
          if $debug;
        if ( !authenticate_user() )
        {
            print "User authentication failed\n" if $debug;
            $status = "You do not have permission to add categories";
            return;
        }
    }
    my ( $addcat_code, $addcat_desc );
    my $box = $mw->DialogBox(
        -title   => "Add a category",
        -buttons => [ "Ok", "Cancel" ]
    );
    $box->Icon( -image => $icon );
    my $acframe1 = $box->add("Frame")->pack( -fill => 'x' );
    $acframe1->Label( -text => "Category Code:  " )->pack( -side => 'left' );
    $acframe1->Entry(
        -background   => 'white',
        -width        => 6,
        -textvariable => \$addcat_code
    )->pack( -side => 'left' );
    my $acframe2 = $box->add("Frame")->pack( -fill => 'x' );
    $acframe2->Label( -text => "Category Description:  " )
      ->pack( -side => 'left' );
    $acframe2->Entry(
        -background   => 'white',
        -width        => 25,
        -textvariable => \$addcat_desc
    )->pack( -side => 'left' );
    my $button = $box->Show;

    if ( $button eq "Ok" )
    {
        print "Got an Ok from addcategory box\n" if $debug;
        if ( ($addcat_code) && ($addcat_desc) )
        {
            $addcat_desc = $dbh->quote($addcat_desc);
            $addcat_code =~ tr/a-z/A-Z/;
            print "Got addcat_desc $addcat_desc and addcat_code $addcat_code\n"
              if $debug;

            # Check to see if there's a duplicate of either entry

            my $checkquery =
              "SELECT * FROM categories WHERE (code='$addcat_code' OR description=$addcat_desc)";
            if ( get_rows($checkquery) > 0 )
            {
                print "Got a duplicate from query $checkquery\n" if $debug;
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
                my $insert_sth = $dbh->prepare($query);
                print "Preparing insert query $query\n" if $debug;
                if ( !$insert_sth->execute )
                {
                    print "Got error on execute\n" if $debug;
                    my $error_message = $insert_sth->errstr();
                    infobox(
                        $mw,
                        "Database Error",
                        "Database returned error: $error_message on query $query"
                    );
                }
                else
                {
                    print "Inserted category successfully\n" if $debug;
                    $status = "Added category $addcat_desc";
                    infobox( $mw, "Success", "Category added." );
                }
                $insert_sth->finish;
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
    print "Editing category\n" if $debug;
    if ( ( $config{write_password} ) && ( !$authenticated ) )
    {
        print "There is a write_password of $config{write_password}\n"
          if $debug;
        if ( !authenticate_user() )
        {
            print "User authentication failed\n" if $debug;
            $status = "You do not have permission to edit categories";
            return;
        }
    }
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
    print "Preparing category query $query\n" if $debug;
    $sth->execute or die "can't execute the query: $DBI::errstr\n";
    my $editbox = $box->add(
        "Scrolled", "Listbox",
        -background => 'white',
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
        print "Inserting string $string\n" if $debug;
    }
    $sth->finish;
    print "Showing box\n" if $debug;
    my $choice = $box->Show();
    if ( ( $choice ne "Cancel" ) && ( defined( $editbox->curselection() ) ) )
    {

        # Throw up another dialog box to do the actual editing
        my ( $code, $desc ) =
          split( / - /, $editbox->get( $editbox->curselection() ) );
        print "Editing code $code, desc $desc\n" if $debug;
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
            -background   => 'white',
            -width        => 25,
            -textvariable => \$new_desc
        )->pack( -side => 'left' );
        print "Showing editbox\n" if $debug;
        my $editchoice = $editbox->Show();

        if ( $editchoice ne "Cancel" )
        {
            $query =
              "UPDATE categories SET description='$new_desc' WHERE code='$code'";
            $sth = $dbh->prepare($query);
            print "Preparing edit query $query\n" if $debug;
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
    print "Deleting category\n" if $debug;
    if ( ( $config{write_password} ) && ( !$authenticated ) )
    {
        print "There is a write_password of $config{write_password}\n"
          if $debug;
        if ( !authenticate_user() )
        {
            print "User authentication failed\n" if $debug;
            $status = "You do not have permission to delete categories";
            return;
        }
    }
    my $box = $mw->DialogBox(
        -title   => "Delete a category",
        -buttons => [ "Ok", "Cancel" ]
    );
    $box->Icon( -image => $icon );
    $box->add( "Label", -text => "Choose a category to delete." )->pack();

    my $query = "SELECT * from categories ORDER BY description";
    my $sth   = $dbh->prepare($query);
    print "Preparing category query $query\n" if $debug;
    $sth->execute or die "Cannot execute the query: $DBI::errstr\n";
    my $deletebox = $box->add(
        "Scrolled", "Listbox",
        -background => 'white',
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
    print "Showing delete category box\n" if $debug;
    my $choice = $box->Show();

    if ( ( $choice ne "Cancel" ) && ( defined( $deletebox->curselection() ) ) )
    {
        my ( $del_cat, $del_desc ) =
          split( / - /, $deletebox->get( $deletebox->curselection() ) );
        print "Deleting category $del_cat, description $del_desc\n" if $debug;
        $query = "SELECT * FROM mrvoice WHERE category='$del_cat'";
        if ( get_rows($query) > 0 )
        {
            print "No rows match with query $query\n" if $debug;
            infobox( $mw, "Error",
                "Could not delete category $del_cat because there are still entries in the database using it.  Delete all entries using this category before deleting the category"
            );
            $status = "Category not deleted";
        }
        else
        {
            $query = "DELETE FROM categories WHERE code='$del_cat'";
            my $delete_sth = $dbh->prepare($query);
            print
              "There are rows with that category, so delete with query $query\n"
              if $debug;
            if ( $delete_sth->execute )
            {
                $status = "Deleted category $del_desc";
                infobox( $mw, "Success",
                    "Category \"$del_desc\" has been deleted." );
            }
            $delete_sth->finish;
        }
    }
    else
    {
        $status = "Category deletion cancelled";
    }
}

sub move_file
{
    print "In move_file function\n" if $debug;
    my ( $oldfilename, $title, $artist ) = @_;
    my $newfilename;
    print "Got old filename $oldfilename, title $title, artist $artist\n"
      if $debug;

    if ($artist)
    {
        $newfilename = "$artist-$title";
    }
    else
    {
        $newfilename = $title;
    }
    $newfilename =~ s/[^a-zA-Z0-9\-]//g;
    print "Using new filename $newfilename\n" if $debug;

    my ( $name, $path, $extension ) = fileparse( $oldfilename, '\.\w+' );
    $extension = lc($extension);
    print "Using extension $extension\n" if $debug;

    if ( -e catfile( $config{'filepath'}, "$newfilename$extension" ) )
    {
        print "The file $newfilename$extension already exists\n" if $debug;
        my $i = 0;
        while ( 1 == 1 )
        {
            print "Using extension $i\n" if $debug;
            if ( !-e catfile( $config{'filepath'}, "$newfilename-$i$extension" )
              )
            {
                $newfilename = "$newfilename-$i";
                print "Found an unused filename at $newfilename\n" if $debug;
                last;
            }
            $i++;
        }
    }

    $newfilename = "$newfilename$extension";

    print "Starting file copy\n" if $debug;
    copy( $oldfilename, catfile( $config{'filepath'}, "$newfilename" ) );
    print "Copy finished\n" if $debug;

    return ($newfilename);
}

sub accept_songdrop
{

    # Thanks to the.noonings for the code
    my ( $widget, $selection ) = @_;

    my $string_dropped;
    eval {
        if ( $^O eq 'MSWin32' )
        {
            $string_dropped = $widget->SelectionGet(
                -selection => $selection,
                'STRING'
            );
        }
        else
        {
            $string_dropped = $widget->SelectionGet(
                -selection => $selection,
                'STRING'
            );
        }
    };

    if ( defined $string_dropped )
    {
        $string_dropped =~ s/^file:// if ( $^O ne "MSWin32" );
        if ( ( -f $string_dropped ) && ( -r $string_dropped ) )
        {
            $string_dropped = Win32::GetShortPathName($string_dropped)
              if ( $^O eq "MSWin32" );
            add_new_song($string_dropped);
        }
        else
        {
            $status = "$string_dropped is not a readable file";
        }
    }
}

sub add_new_song
{
    print "Adding new song\n" if $debug;
    if ( ( $config{write_password} ) && ( !$authenticated ) )
    {
        print "There is a write_password of $config{write_password}\n"
          if $debug;
        if ( !authenticate_user() )
        {
            print "User authentication failed\n" if $debug;
            $status = "You do not have permission to add new songs";
            return;
        }
    }
    my (
        $addsong_title, $addsong_artist,   $addsong_info,
        $addsong_cat,   $addsong_filename, $addsong_publisher
    );
    if ( $addsong_filename = shift )
    {
        ( $addsong_title, $addsong_artist ) =
          get_title_artist($addsong_filename);
    }
    my $continue = 0;
    $addsong_publisher = "OTHER";
    while ( $continue != 1 )
    {
        print "Building the Add Song dialog box\n" if $debug;
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
            -background   => 'white',
            -width        => 30,
            -textvariable => \$addsong_title
        )->pack( -side => 'right' );
        my $frame2 = $box->add("Frame")->pack( -fill => 'x' );
        $frame2->Label( -text => "Artist" )->pack( -side => 'left' );
        $frame2->Entry(
            -background   => 'white',
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
            -background   => 'white',
            -width        => 30,
            -textvariable => \$addsong_info
        )->pack( -side => 'right' );
        my $pubframe = $box->add("Frame")->pack( -fill => 'x' );
        $pubframe->Label( -text => 'Publisher' )->pack( -side => 'left' );
        my $pubmenu = $pubframe->Menubutton(
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
        $pubmenu->configure( -text => $addsong_publisher );
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
                    -title      => 'Select Audio file to add',
                    -initialdir => ( $^O eq "MSWin32" ) ? "C:/" : get_homedir(),
                    -filetypes  => $mp3types
                );
                ( $addsong_title, $addsong_artist ) =
                  get_title_artist($addsong_filename);
            }
        )->pack( -side => 'right' );
        my $songentry = $frame5->Entry(
            -background   => 'white',
            -width        => 30,
            -textvariable => \$addsong_filename
        )->pack( -side => 'right' );
        my $frame7 = $box->add("Frame")->pack( -fill => 'x' );
        my $previewbutton = $frame7->Button(
            -text    => "Preview song",
            -command => sub {
                my $tmpsong = $songentry->cget( -textvariable );
                play_mp3( $box, "addsong", $$tmpsong );
            }
        )->pack( -side => 'right' );
        $previewbutton->configure(
            -bg               => 'green',
            -activebackground => 'SpringGreen2'
        );

        print "Showing the Add Song dialog box\n" if $debug;
        my $result = $box->Show();
        print "Showed the Add Song dialog box\n" if $debug;

        if ( $result eq "OK" )
        {
            print "Got 'Ok' from dialog box\n" if $debug;
            if ( !$addsong_cat )
            {
                print
                  "Addsong_cat was $addsong_cat, so we didn't get a category\n"
                  if $debug;
                infobox( $mw, "Error",
                    "Could not add new song\n\nYou must choose a category" );
            }
            elsif ( !-r $addsong_filename )
            {
                print
                  "Addsong_filename was $addsong_filename and not readable\n"
                  if $debug;
                infobox(
                    $mw,
                    "File Error",
                    "Could not open input file $addsong_filename for reading.  Check file permissions"
                );
            }
            elsif ( !$addsong_title )
            {
                print
                  "Addsong_title was $addsong_title, so we didn't get a title\n"
                  if $debug;
                infobox( $mw, "File Error",
                    "You must provide the title for the song." );
            }
            elsif ( !-w $config{'filepath'} )
            {
                print "The filepath ($config{filepath}) was not writable\n"
                  if $debug;
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
      "INSERT INTO mrvoice VALUES (NULL,$addsong_title,$addsong_artist,'$addsong_cat',$addsong_info,'$newfilename','$time',(SELECT strftime('%s','now')),'$addsong_publisher')";
    print "Using INSERT query -->$query<--\n" if $debug;
    if ( $dbh->do($query) )
    {
        print "dbh->do successful\n" if $debug;
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
        print "dbh->do failed\n" if $debug;
        infobox( $mw, "Error", "Could not add song into database" );
        $status = "File add exited on database error";
    }
}

sub authenticate_user
{
    print "Attempting to authenticate user\n" if $debug;
    my $password;
    my $authbox = $mw->DialogBox(
        -title   => "Please Enter The Password",
        -buttons => [ "Authenticate", "Cancel" ]
    );
    $authbox->Icon( -image => $icon );
    $authbox->Label( -text =>
          "You must provide a password in order to access this function.\n\nPlease enter it below."
    )->pack( -side => 'top' );
    $authbox->Entry(
        -background   => 'white',
        -width        => 8,
        -textvariable => \$password,
        -show         => '*'
    )->pack( -side => 'top' );
    my $choice = $authbox->Show;
    return if ( $choice eq "Cancel" );

    if ( $password eq $config{write_password} )
    {
        $authenticated = 1;
        $status        = "Successfully authenticated for write access";
        return $authenticated;
    }
    else
    {
        return;
    }
}

sub edit_preferences
{
    print "Editing preferences\n" if $debug;
    if ( ( $config{write_password} ) && ( !$authenticated ) )
    {
        print "There is a write_password of $config{write_password}\n"
          if $debug;
        if ( !authenticate_user() )
        {
            print "User authentication failed\n" if $debug;
            $status = "You do not have permission to edit the Preferences";
            return;
        }
    }
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

    my $dbfile_frame = $database_page->Frame()->pack( -fill => 'x' );
    $dbfile_frame->Label( -text => "Database File" )->pack( -side => 'left' );
    $dbfile_frame->Button(
        -text    => "Select Database Location",
        -command => sub {
            if (
                my $dbdir = $box->chooseDirectory(
                    -title      => "Choose directory for the mrvoice.db file",
                    -initialdir => ( $^O eq "MSWin32" ) ? "C:\\" : get_homedir()
                )
              )
            {
                $dbdir = Win32::GetShortPathName($dbdir)
                  if ( $^O eq "MSWin32" );
                my $dbfile = catfile( $dbdir, "mrvoice.db" );
                $config{'db_file'} = $dbfile;
            }
        }
    )->pack( -side => 'right' );
    $dbfile_frame->Entry(
        -background   => 'white',
        -width        => 30,
        -textvariable => \$config{'db_file'}
    )->pack( -side => 'right' );

    my $mp3dir_frame = $filepath_page->Frame()->pack( -fill => 'x' );
    $mp3dir_frame->Label( -text => "MP3 Directory" )->pack( -side => 'left' );
    $mp3dir_frame->Button(
        -text    => "Select MP3 Directory",
        -command => sub {
            if (
                my $filepath = $box->chooseDirectory(
                    -title      => 'Choose audio file save directory',
                    -initialdir => ( $^O eq "MSWin32" ) ? "C:/" : get_homedir()
                )
              )
            {
                $filepath = Win32::GetShortPathName($filepath)
                  if ( $^O eq "MSWin32" );
                $config{'filepath'} = $filepath;
            }
        }
    )->pack( -side => 'right' );

    $mp3dir_frame->Entry(
        -background   => 'white',
        -width        => 30,
        -textvariable => \$config{'filepath'}
    )->pack( -side => 'right' );

    my $hotkeydir_frame = $filepath_page->Frame()->pack( -fill => 'x' );
    $hotkeydir_frame->Label( -text => "Hotkey Save Directory" )
      ->pack( -side => 'left' );
    $hotkeydir_frame->Button(
        -text    => "Select Hotkey Directory",
        -command => sub {
            if (
                my $savedir = $box->chooseDirectory(
                    -title      => 'Choose Hotkey save directory',
                    -initialdir => ( $^O eq "MSWin32" ) ? "C:\\" : get_homedir()
                )
              )
            {
                $savedir = Win32::GetShortPathName($savedir)
                  if ( $^O eq "MSWin32" );
                $config{'savedir'} = $savedir;
            }
        }
    )->pack( -side => 'right' );
    $hotkeydir_frame->Entry(
        -background   => 'white',
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
    my $mp3button = $mp3frame->Button(
        -text    => "Choose",
        -command => sub {
            $config{'mp3player'} = $mw->getOpenFile(
                -title      => 'Select MP3 player executable',
                -initialdir => ( $^O eq "MSWin32" ) ? "C:/" : get_homedir()
            );
        }
    )->pack( -side => 'right' );
    $mp3button->configure( -state => 'disabled' ) if ( $^O eq "darwin" );
    my $mp3entry = $mp3frame->Entry(
        -background   => 'white',
        -width        => 30,
        -textvariable => \$config{'mp3player'}
    )->pack( -side => 'right' );
    $mp3entry->configure( -state => 'disabled' ) if ( $^O eq "darwin" );

    my $numdyn_frame = $other_page->Frame()->pack( -fill => 'x' );
    $numdyn_frame->Label( -text => "Number of Dynamic Documents To Show" )
      ->pack( -side => 'left' );
    $numdyn_frame->Entry(
        -background   => 'white',
        -width        => 2,
        -textvariable => \$savefile_max
    )->pack( -side => 'right' );

    my $httpq_frame = $other_page->Frame()->pack( -fill => 'x' );
    $httpq_frame->Label( -text => "httpQ Password (WinAmp only, optional)" )
      ->pack( -side => 'left' );
    $httpq_frame->Entry(
        -background   => 'white',
        -width        => 8,
        -textvariable => \$config{'httpq_pw'}
    )->pack( -side => 'right' );

    my $writepass_frame = $other_page->Frame()->pack( -fill => 'x' );
    $writepass_frame->Label( -text => "Write Access Password (empty for none)" )
      ->pack( -side => 'left' );
    $writepass_frame->Entry(
        -background   => 'white',
        -width        => 8,
        -show         => '*',
        -textvariable => \$config{'write_password'}
    )->pack( -side => 'right' );

    $notebook->pack(
        -expand => "yes",
        -fill   => "both",
        -padx   => 5,
        -pady   => 5,
        -side   => "top"
    );
    print "Displaying preferences dialog\n" if $debug;
    my $result = $box->Show();
    print "Displayed preferences dialog\n" if $debug;

    if ( $result eq "Ok" )
    {
        if (   ( !$config{'db_file'} )
            || ( !$config{'filepath'} )
            || ( !$config{'savedir'} )
            || ( !$config{'mp3player'} ) )
        {
            print
              "All fields not filled in: db_file is $config{db_file}, filepath is $config{filepath}, savedir is $config{savedir}, mp3player is $config{mp3player}\n"
              if $debug;
            infobox( $mw, "Warning", "All fields must be filled in\n" );
            edit_preferences();
        }
        if ( !open( my $rcfile_fh, ">", $rcfile ) )
        {
            print "Couldn't open $rcfile for writing\n" if $debug;
            infobox( $mw, "Warning",
                "Could not open $rcfile for writing. Your preferences will not be saved\n"
            );
        }
        else
        {
            print "Writing config to $rcfile\n" if $debug;
            foreach my $key ( sort keys %config )
            {
                print "Writing key $key and value $config{$key}\n" if $debug;
                print $rcfile_fh "$key" . "::$config{$key}\n";
            }
        }
    }
    read_rcfile();
}

sub edit_song
{
    print "Editing song\n" if $debug;
    if ( ( $config{write_password} ) && ( !$authenticated ) )
    {
        print "There is a write_password of $config{write_password}\n"
          if $debug;
        if ( !authenticate_user() )
        {
            print "User authentication failed\n" if $debug;
            $status = "You do not have permission to edit songs";
            return;
        }
    }
    my (@selected) = $mainbox->info('selection');
    print "Selected items are " . join( ", ", @selected ) . "\n" if $debug;
    my ( $edit_title, $edit_artist, $edit_category, $edit_publisher,
        $edit_info );
    my $count = scalar @selected;
    if ( $count == 1 )
    {

        # We're looking to edit one song, so we can choose everything
        my $id = $mainbox->info( 'data', $selected[0] );
        print "Got song ID $id\n" if $debug;
        my $query =
          "SELECT title,artist,category,info,publisher from mrvoice where id=$id";
        my (
            $edit_title, $edit_artist, $edit_category,
            $edit_info,  $edit_publisher
          )
          = $dbh->selectrow_array($query);
        print
          "Got the following information about the song.  title: $edit_title, artist: $edit_artist, category: $edit_category, info: $edit_info, publisher: $edit_publisher\n"
          if $debug;

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
            -background   => 'white',
            -width        => 30,
            -textvariable => \$edit_title
        )->pack( -side => 'right' );
        my $frame2 = $box->add("Frame")->pack( -fill => 'x' );
        $frame2->Label( -text => "Artist" )->pack( -side => 'left' );
        $frame2->Entry(
            -background   => 'white',
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
            -background   => 'white',
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
        print "Showing dialog box..." if $debug;
        my $result = $box->Show();
        print "Showed\n" if $debug;
        if ( $result eq "Edit" )
        {
            $edit_artist = $dbh->quote($edit_artist);
            $edit_title  = $dbh->quote($edit_title);
            $edit_info   = $dbh->quote($edit_info);

            my $query =
              "UPDATE mrvoice SET artist=$edit_artist, title=$edit_title, info=$edit_info, category='$edit_category',modtime=(SELECT strftime('%s','now')) WHERE id=$id";
            print "Using update query $query\n" if $debug;
            if ( $dbh->do($query) )
            {
                print "Update query succeeded\n" if $debug;
                infobox(
                    $mw,
                    "Song Edited Successfully",
                    "The song was edited successfully."
                );
                $status = "Edited song";
            }
            else
            {
                print "There was an error with update query: $dbh->errstr\n"
                  if $debug;
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

        print "Editing multiple songs\n" if $debug;

        # We're editing multiple songs, so only put up a subset
        # First, convert the indices to song ID's
        my @songids;
        my (
            $clear_artist_cb, $clear_info_cb, $edit_artist,
            $edit_info,       $edit_category
        );
        foreach my $id (@selected)
        {
            my $songid = $mainbox->info( 'data', $id );
            print "Using Song ID $songid\n" if $debug;
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
            -background   => 'white',
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
            -background   => 'white',
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
        print "Showing dialog box..." if $debug;
        my $result = $box->Show();
        print "Showed\n" if $debug;
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
            push( @querystring, "modtime=(SELECT strftime('%s','now'))" );

            $string = join( ", ", @querystring );

            foreach my $songid (@songids)
            {
                my $query = "UPDATE mrvoice SET $string WHERE id=$songid";
                print "Running UPDATE query -->$query<-- ..." if $debug;
                $dbh->do($query);
                print "Error code: $dbh->errstr\n" if $debug;
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
    print "Deleting song\n" if $debug;
    if ( ( $config{write_password} ) && ( !$authenticated ) )
    {
        print "There is a write_password of $config{write_password}\n"
          if $debug;
        if ( !authenticate_user() )
        {
            print "User authentication failed\n" if $debug;
            $status = "You do not have permission to delete songs";
            return;
        }
    }
    my (@selection) = $mainbox->info('selection');
    print "Deleting songs " . join( ", ", @selection ) . "\n" if $debug;
    my $count = scalar @selection;
    my @ids;
    my $delete_file_cb;
    foreach my $index (@selection)
    {
        push( @ids, $mainbox->info( 'data', $index ) );
    }
    print "Got song IDs " . join( ", ", @ids ) . "\n" if $debug;
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
        print "Showing delete songs dialog box..." if $debug;
        my $result = $box->Show();
        print "Showed\n" if $debug;
        if ( $result eq "Delete" )
        {
            my $query = "DELETE FROM mrvoice WHERE id=?";
            my $sth   = $dbh->prepare($query);
            foreach my $id (@ids)
            {
                my $filename;
                if ( $delete_file_cb == 1 )
                {
                    my $filequery = "SELECT filename FROM mrvoice WHERE id=$id";
                    ($filename) = $dbh->selectrow_array($filequery);
                }
                print "Executing query -->$query<-- for song id $id\n"
                  if $debug;
                $sth->execute($id);
                $sth->finish;
                print "STH finished with error code: $sth->errstr\n" if $debug;
                if ( $delete_file_cb == 1 )
                {
                    my $file = catfile( $config{'filepath'}, $filename );
                    print "Deleting file $file\n" if $debug;
                    if ( -e $file )
                    {
                        unlink("$file");
                    }
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
    my @modules =
      qw/Tk DBI DBD::SQLite MPEG::MP3Info MP4::Info Audio::Wav Ogg::Vorbis::Header::PurePerl Date::Manip Time::Local Time::HiRes File::Glob File::Temp File::Basename File::Copy/;
    push( @modules,
        qw/LWP::UserAgent HTTP::Request Win32::Process Win32::FileOp Audio::WMA/
      )
      if ( $^O eq "MSWin32" );
    push( @modules, "Mac::Applescript" ) if ( $^O eq "darwin" );

    print "Showing about box\n" if $debug;
    my $rev = '$LastChangedRevision$';
    $rev =~ s/.*: (\d+).*/$1/;
    my $string =
      "Mr. Voice Version $version (Revision: $rev)\n\nBy H. Wade Minter <minter\@lunenburg.org>\n\nURL: http://www.lunenburg.org/mrvoice/\n\n(c)2001-2005, Released under the GNU General Public License.\n\n\nTechnical information below:";
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
    my $about_lb = $box->Scrolled(
        "Listbox",
        -scrollbars => "osoe",
        -background => 'white',
        -setgrid    => 1,
        -width      => 40,
        -height     => 8,
        -selectmode => "single"
    )->pack();

    $about_lb->insert( 'end', "Perl Version: $]" );
    $about_lb->insert( 'end', "Operating System: $^O" );
    foreach my $module (@modules)
    {
        no strict 'refs';
        my $versionstring = "${module}::VERSION";
        $about_lb->insert( 'end', "$module Version: $$versionstring" );
    }

    $box->Show;
}

sub wipe_tank
{
    print "Deleting all files from tankbox\n" if $debug;

    # Clears the holding tank
    $tankbox->delete('all');
}

sub clear_hotkeys
{

    print "Clearing hotkeys\n" if $debug;

    # Backs up the hotkeys, then deletes all of them.

    if ( $lock_hotkeys == 1 )
    {
        print "Lock Hotkeys is $lock_hotkeys, so doing nothing\n" if $debug;
        $status = "Can't clear all hotkeys - hotkeys locked";
        return;
    }

    backup_hotkeys();
    foreach my $fkeynum ( 1 .. 12 )
    {
        my $fkey = "f$fkeynum";
        print "Clearing $fkey\n" if $debug;
        $fkeys{$fkey}->{id}       = '';
        $fkeys{$fkey}->{filename} = '';
        $fkeys{$fkey}->{title}    = '';
    }
    $status = "All hotkeys cleared";
}

sub clear_selected
{
    print "Clearing selected hotkeys\n" if $debug;
    if ( $lock_hotkeys == 1 )
    {
        print "Lock Hotkeys is $lock_hotkeys, so doing nothing\n" if $debug;
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
            print "Clearing key $fkey\n" if $debug;
            $fkeys{$fkey}->{title}    = '';
            $fkeys{$fkey}->{id}       = '';
            $fkeys{$fkey}->{filename} = '';
        }
        $fkeys_cb{$fkey} = 0;
    }

    $status = "Selected hotkeys cleared";
}

sub return_all_indices
{
    print "Returning all indices for a hlist\n" if $debug;
    my $hlist = shift;
    my @indexes;
    my $curr_entry = ( $hlist->info("children") )[0];
    while ( defined $curr_entry )
    {
        my $data = $hlist->info( 'data', $curr_entry );
        push( @indexes, $data );
        $curr_entry = $hlist->info( "next", $curr_entry );
    }
    print "Returning " . join( ", " => @indexes ) . "\n";
    return (@indexes);
}

sub launch_tank_playlist
{

    print "Launching an M3U playlist from the holding tank\n" if $debug;

    # Launch an m3u playlist from the contents of the holding tank

    my @indices = return_all_indices($tankbox);
    return if ( $#indices < 0 );
    my ( $fh, $filename ) = tempfile( SUFFIX => '.m3u', UNLINK => 1 );
    print "Using temp filename $filename\n" if $debug;
    print $fh "#EXTM3U\n";
    foreach my $item (@indices)
    {
        my $file = get_info_from_id($item)->{filename};
        my $path = catfile( $config{filepath}, $file );
        print $fh "$path\n";
        print "Writing $path to m3u\n" if $debug;
    }
    close($fh) or die;
    print "Sending playlist command to MP3 player\n" if $debug;
    if ( $^O eq "darwin" )
    {
        RunAppleScript(
            qq( set unixFile to \"$filename\"\nset macFile to POSIX file unixFile\nset fileRef to (macFile as alias)\ntell application "Audion 3"\nplay fileRef in control window 1\nend tell)
          )
          or die "Can't play: $@";
    }
    else
    {
        system("$config{'mp3player'} $filename");
    }
}

sub holding_tank
{
    print "Showing holding tank\n" if $debug;
    if ( !Exists($holdingtank) )
    {
        print "Holding tank does not exist yet, creating it\n" if $debug;
        my $arrowdown = $mw->Photo( -data => <<'EOF');
R0lGODlhFgAWAIUAAPwCBAQCBAQGBBwaHDQyNExKTHx6fGxqbFxeXGRiZFRSVDw+PAwKDJSWlOzu7LSytJyenJSSlISGhISChIyOjFRWVDw6PPz+/MTCxLS2tGRmZDQ2NAwODJyanKSmpKSipIyKjHRydBQSFERCRExOTFxaXAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAWABYAAAasQIBwSCwah4FkQKBsDpoBIqFgOCASCYRWm1AUFgRGkdBwPCARiWRCaTwOFYvYSIhcMOiJpJGZaDYcR0IEHXceEQ0fICEWIoJDhHcQHxIHgI9SEHeVG46YUh8OISOen1INCqWmUnOYTUxQAU9NUlRWWFtbCiRgrYNlZ2lriG8lYUd1khETE24gCZeCkRgeFBAQIAeNn9OTlXKrBJoYnKrcoaPmpmSpq3S+7u50QQAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJzaW9uIDIuNQ0KqSBEZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVzZXJ2ZWQuDQpodHRwOi8vd3d3LmRldmVsY29yLmNvbQA7
EOF

        my $arrowup = $mw->Photo( -data => <<'EOF');
R0lGODlhFgAWAIUAAPwCBAQCBGReZDQyNMTCxHx6fPz+/JyWnKyurHx2fDw6PJSSlISGhIyKjIyGjISChLy6vJyanOTm5PTy9OTi5MzKzLSytKSepMTGxMzGzLS2tLSutKymrHRydCQiJCwmLBwWHAwODLy2vHx+fAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAWABYAAAajQIBwSCwaj8RAAMkUBgSDZdP4JBSi06TAcEAkFNLp07BgLLzY5njRcDzO3zB1C4lEGI83Wj58SiYUFRUWdg0XEXFFAwIYGRoWGxwRZQUFHZdgRAObmx4fHiChISFKpVlKWUdPaalOAlasp1sHG4myZGZ7Yltsbgu1mUhjdRF5egmxfQJ/gYOFdrZDi40iFgiSCw8jBQmYcpydn6Ego6WorUwGQQAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJzaW9uIDIuNQ0KqSBEZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVzZXJ2ZWQuDQpodHRwOi8vd3d3LmRldmVsY29yLmNvbQA7
EOF

        $holdingtank = $mw->Toplevel();
        print "Created toplevel\n" if $debug;
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
        $playlistbutton->configure( -state => 'disabled' )
          if ( $^O eq "darwin" );
        my $buttonframe = $holdingtank->Frame()->pack(
            -side => 'bottom',
            -fill => 'x'
        );
        $holdingtank->Button(
            -image   => $arrowup,
            -command => [ \&move_tank, "-before" ]
        )->pack( -side => 'left' );
        $holdingtank->Button(
            -image   => $arrowdown,
            -command => [ \&move_tank, "-after" ]
        )->pack( -side => 'right' );
        $tankbox = $holdingtank->Scrolled(
            'HList',
            -scrollbars       => 'osoe',
            -background       => 'white',
            -selectbackground => 'navy',
            -selectforeground => 'white',
            -width            => 50,
            -selectmode       => 'extended'
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
        print "Updating, deiconifying, and raising..." if $debug;
        $holdingtank->update();
        $holdingtank->deiconify();
        $holdingtank->raise();
        print "Done\n" if $debug;
    }
    else
    {
        print "Holding tank exists.  Deiconifying and raising..." if $debug;
        $holdingtank->deiconify();
        $holdingtank->raise();
        print "Done\n" if $debug;
    }
}

sub move_tank
{

    print "Reordering an item in the holding tank\n" if $debug;

    # Function courtesy of Kyle at sickduck.org
    my $h         = $tankbox;
    my $direction = shift;
    print "Moving in the direction: $direction\n" if $debug;

    #Do nothing unless an item is selected in the HList
    return unless my $target = $h->infoAnchor;

    #Based on direction to be moved, get index for prior/next item in HList
    my $neighbor;
    if ( $direction =~ /before/i )
    {
        $neighbor = $h->infoPrev($target);
    }
    else
    {
        $neighbor = $h->infoNext($target);
    }
    print "Neighbor is $neighbor\n" if $debug;

    #infoNext/infoPrev returns no value if there is no item after/before the
    #target entry.  This generally means we're already at the end/beginning
    #of list, so we can return with no action.
    return unless $neighbor;

    #We need to grab the text of the entry that needs to be moved
    my $targettext = $h->entrycget( $target, '-text' );

    #Now we can delete the entry...
    print "Deleting $targettext\n" if $debug;
    $h->delete( 'entry', $target );

    #then we use the passed direction ("-before" or "-after") to add
    #the entry information appropriately...
    $h->add(
        $target,
        -data => $target,
        -text => $targettext,
        $direction, $neighbor
    );

    print "Re-adding $targettext in the proper location\n" if $debug;

    my $info = get_info_from_id($target);
    if ( !-e catfile( $config{'filepath'}, $info->{filename} ) )
    {
        print "This item is inavlid, so turn it red\n" if $debug;
        my $style = $tankbox->ItemStyle(
            'text',
            -foreground       => 'red',
            -background       => 'white',
            -selectforeground => 'red'
        );
        $h->entryconfigure( $target, -style => $style );
    }

    #...and assumedly we want the newly re-inserted item to be selected...
    print "Anchorsetting..." if $debug;
    $h->anchorSet($target);

    #...and assumedly, in a scrolling list, we want to have the re-inserted
    #item be visible.
    print "and seeing\n" if $debug;
    $h->see($target);
    return;
}

sub clear_tank
{
    print "Clearing holding tank\n" if $debug;
    my @selected = reverse( $tankbox->info('selection') );
    foreach my $item (@selected)
    {
        print "Deleting $item\n" if $debug;
        $tankbox->delete( 'entry', $item );
    }
}

sub list_hotkeys
{
    print "Showing the hotkeys window\n" if $debug;
    if ( !Exists($hotkeysbox) )
    {
        print "The hotkeys window does not exist, so we create it\n" if $debug;
        my %fkeys_frame;
        my %fkeys_chkb;
        my %fkeys_label;
        print "Creating toplevel\n" if $debug;
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
        print "Updating, deiconifying, and raising..." if $debug;
        $hotkeysbox->update();
        $hotkeysbox->deiconify();
        $hotkeysbox->raise();
        print "Done\n" if $debug;
    }
    else
    {
        print "Hotkeys window exists, so deiconify and raise..." if $debug;
        $hotkeysbox->deiconify();
        $hotkeysbox->raise();
        print "Done\n" if $debug;
    }
}

sub update_time
{
    print "Updating song times\n";
    $mw->Busy( -recurse => 1 );
    print "Mainwindow now busy\n" if $debug;
    my $percent_done = 0;
    my $updated      = 0;
    print "Creating progressbox toplevel..." if $debug;
    my $progressbox = $mw->Toplevel();
    print "Done\n" if $debug;
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
    print "Updating, deiconifying, and raising..." if $debug;
    $progressbox->update();
    $progressbox->deiconify();
    $progressbox->raise();
    print "Done\n" if $debug;

    my $count        = 0;
    my $query        = "SELECT id,filename,time FROM mrvoice";
    my $arrayref     = $dbh->selectall_arrayref($query);
    my $numrows      = scalar @$arrayref;
    my $update_query =
      "UPDATE mrvoice SET time=?, modtime=(SELECT strftime('%s','now')) WHERE id=?";
    my $update_sth = $dbh->prepare($update_query);

    while ( my $table_row = shift @$arrayref )
    {
        $count++;
        my ( $id, $filename, $time ) = @$table_row;
        next if ( !-r catfile( $config{filepath}, $filename ) );
        my $newtime =
          get_songlength( catfile( $config{'filepath'}, $filename ) );
        if ( $newtime ne $time )
        {
            print
              "Song ID $id has database time $time but file time $newtime, so updating\n"
              if $debug;
            $update_sth->execute( $newtime, $id );
            $updated++;
        }
        $percent_done = int( ( $count / $numrows ) * 100 );
        $pb->set($percent_done);
        $progressbox->update();
    }
    $donebutton->configure( -state => 'active' );
    $donebutton->focus;
    $progressbox->update();
    $mw->Unbusy( -recurse => 1 );
    print "Updated $updated files\n" if $debug;
    $status = "Updated times on $updated files";
}

sub get_info_from_id
{

    print "Getting info from ID\n" if $debug;

    # Returns a hash reference containing all the info for a specified ID

    my $id = shift;
    print "Got song ID $id\n" if $debug;
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
    if ($debug)
    {
        foreach my $key ( keys %info )
        {
            print "Got info key $key, value $info{$key}\n";
        }
    }
    return \%info;
}

sub validate_id
{
    print "Validating ID\n" if $debug;
    my $id = shift;
    print "Got ID $id\n" if $debug;
    my $query   = "SELECT * FROM mrvoice WHERE id=$id";
    my $numrows = get_rows($query);
    print "Got result $numrows\n" if $debug;
    return $numrows == 1 ? 1 : 0;
}

sub stop_mp3
{
    print "Stopping MP3\n" if $debug;

    my $widget = shift;

    # Sends a stop command to the MP3 player.  Works for both xmms and WinAmp,
    # though not particularly cleanly.

    if ( $^O eq "darwin" )
    {
        RunAppleScript(
            qq( tell application "Audion 3" to stop in control window 1));
    }
    else
    {
        system("$config{'mp3player'} --stop");
    }
    $status = "Playing Stopped";

    # Manually give the mainbox focus
    print "Focusing on mainbox\n" if $debug;
    $mainbox->focus();
}

sub play_mp3
{

    print "Playing MP3\n" if $debug;
    my ( $statustitle, $statusartist, $filename );
    my $songstatusstring;
    my $widget = shift;
    my $action = shift;

    print "The action is $action\n" if $debug;

    # See if the request is coming from one our hotkeys first...
    if ( $action =~ /^f\d+/ )
    {
        $filename = $fkeys{$action}->{filename};
    }
    elsif ( $action eq "addsong" )
    {

        # if we're playing from the "add new song" dialog, the full path
        # will already be set.
        $filename = shift;
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
        my (@selection) = $box->info('selection');
        my $id = $box->info( 'data', $selection[0] );
        if ($id)
        {
            my $id_ref = get_info_from_id($id);
            $filename     = $id_ref->{filename};
            $statustitle  = $id_ref->{title};
            $statusartist = $id_ref->{artist};
            if ( !-e catfile( $config{'filepath'}, $id_ref->{filename} ) )
            {
                $status =
                  "Cannot play invalid entry - no file on disk to play!";
                return;
            }
        }
    }
    if ( $action eq "addsong" )
    {
        $status = "Previewing file $filename";
        if ( $^O eq "darwin" )
        {
            RunAppleScript(
                qq( set unixFile to \"$filename\"\nset macFile to POSIX file unixFile\nset fileRef to (macFile as alias)\ntell application "Audion 3"\nplay fileRef in control window 1\nend tell)
              )
              or die "Can't play: $@";
        }
        else
        {
            system("$config{'mp3player'} $filename");
        }
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
        print "Playing file $filename\n" if $debug;
        $status = "Playing $songstatusstring";
        my $file = catfile( $config{'filepath'}, $filename );
        if ( $^O eq "darwin" )
        {
            RunAppleScript(
                qq( set unixFile to \"$file\"\nset macFile to POSIX file unixFile\nset fileRef to (macFile as alias)\ntell application "Audion 3"\nplay fileRef in control window 1\nend tell)
              )
              or die "Can't play: $@";
        }
        else
        {
            system("$config{'mp3player'} $file");
        }
    }
}

sub get_songlength
{
    print "Getting the length of a song\n" if $debug;

    #Generic function to return the length of a song in mm:ss format.
    #Currently supports OGG, MP3 and WAV, with the appropriate modules.

    my $file = shift;
    print "File is $file\n" if $debug;
    my $time = "";
    if ( $file =~ /.*\.mp3$/i )
    {

        print "It's an MP3 file\n" if $debug;

        # It's an MP3 file
        my $info   = get_mp3info("$file");
        my $minute = $info->{MM};
        $minute = "0$minute" if ( $minute < 10 );
        my $second = $info->{SS};
        $second = "0$second" if ( $second < 10 );
        $time = "[$minute:$second]";
        print "Got time $time\n" if $debug;
    }
    elsif ( $file =~ /\.wav$/i )
    {

        print "It's a WAV file\n" if $debug;

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
        print "Time is $time\n" if $debug;
    }
    elsif ( $file =~ /\.ogg$/i )
    {

        print "It's an OGG file\n" if $debug;

        #It's an Ogg Vorbis file.
        my $ogg = Ogg::Vorbis::Header::PurePerl->new($file);

        my $audio_seconds = $ogg->info->{length};
        my $minute        = int( $audio_seconds / 60 );
        $minute = "0$minute" if ( $minute < 10 );
        my $second = $audio_seconds % 60;
        $second = "0$second" if ( $second < 10 );
        $time = "[$minute:$second]";
        print "Time is $time\n" if $debug;
    }
    elsif ( ( $file =~ /\.wma$/i ) && ( $^O eq "MSWin32" ) )
    {

        print "It's a WMA file\n" if $debug;

        # It's a Windows Media file
        my $wma           = Audio::WMA->new($file);
        my $info          = $wma->info();
        my $audio_seconds = $info->{playtime_seconds};
        my $minute        = int( $audio_seconds / 60 );
        $minute = "0$minute" if ( $minute < 10 );
        my $second = $audio_seconds % 60;
        $second = "0$second" if ( $second < 10 );
        $time = "[$minute:$second]";
        print "Time is $time\n" if $debug;
    }
    elsif ( ( $file =~ /\.m4a/i ) || ( $file =~ /\.mp4/i ) )
    {

        print "It's an AAC file\n" if $debug;

        # AAC/MP4 File
        my $info = get_mp4info($file);
        $time = "[$info->{TIME}]";
        print "Time is $time\n" if $debug;
    }
    elsif ( ( $file =~ /\.m3u$/i ) || ( $file =~ /\.pls$/i ) )
    {

        print "It's a playlist\n" if $debug;

        #It's a playlist
        $time = "[PLAYLIST]";
    }
    else
    {

        print "It's a nonsupported file type\n" if $debug;

        # Unsupported file type
        $time = "[??:??]";
    }
    return ($time);
}

sub do_search
{
    print "Doing search\n" if $debug;
    my ( $datestring, $startdate, $enddate );
    my $modifier = shift;
    print "Modifier is $modifier\n" if $debug;
    if ( $modifier eq "timespan" )
    {
        my $span = shift;
        print "Timespan is $span\n" if $debug;
        my $date;
        if ( $span eq "0" )
        {
            $date = DateTime->now;
        }
        else
        {
            $date = DateCalc( "today", "- $span" );
        }
        $datestring = UnixDate( $date, "%s" );
        print "Datestring is $datestring\n" if $debug;

        #        $date =~ /^(\d{4})(\d{2})(\d{2}).*?/;
        #        my $year  = $1;
        #        my $month = $2;
        #        my $day   = $3;
        #        $datestring = "$year-$month-$day";
    }
    elsif ( ( $modifier eq "range" ) )
    {
        $startdate = shift;
        $enddate   = shift;
        print "Start date is $startdate and end date is $enddate\n" if $debug;
    }
    $anyfield =~ s/^\s*(.*?)\s*$/$1/ if ($anyfield);
    $title    =~ s/^\s*(.*?)\s*$/$1/ if ($title);
    $artist   =~ s/^\s*(.*?)\s*$/$1/ if ($artist);
    $cattext  =~ s/^\s*(.*?)\s*$/$1/ if ($cattext);
    $status = "Starting search...";
    $mw->Busy( -recurse => 1 );
    $mainbox->delete('all');
    my $query =
      "SELECT mrvoice.id,categories.description,mrvoice.info,mrvoice.artist,mrvoice.title,mrvoice.filename,mrvoice.time,mrvoice.publisher FROM mrvoice,categories WHERE mrvoice.category=categories.code ";
    $query = $query . "AND publisher != 'ASCAP' "
      if ( $config{'search_ascap'} == 0 );
    $query = $query . "AND publisher != 'BMI' "
      if ( $config{'search_bmi'} == 0 );
    $query = $query . "AND publisher != 'OTHER' "
      if ( $config{'search_other'} == 0 );
    $query = $query . "AND modtime >= '$datestring' "
      if ( $modifier eq "timespan" );
    $query = $query . "AND modtime >= '$startdate' AND modtime <= '$enddate' "
      if ( $modifier eq "range" );
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
    print "Prepared query $query\n" if $debug;
    if ( !$sth->execute )
    {
        print "Database error: $sth->errstr\n" if $debug;
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
    my $numrows = 0;
    my $invalid = 0;
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
          if ( $config{'show_publisher'} == 1 );
        print "Adding ID $row_hashref->{id} and string $string\n" if $debug;
        $mainbox->add(
            $row_hashref->{id},
            -data => $row_hashref->{id},
            -text => $string
        );
        $numrows++;

        if ( !-e catfile( $config{'filepath'}, $row_hashref->{filename} ) )
        {
            print "$row_hashref->{id} is invalid, turning it red\n" if $debug;
            my $style = $mainbox->ItemStyle(
                'text',
                -foreground       => 'red',
                -background       => 'white',
                -selectforeground => 'red'
            );
            $mainbox->entryconfigure( $row_hashref->{id}, -style => $style );
            $invalid++;
        }
    }
    if ( $numrows > 0 )
    {
        my $curr_entry = ( $mainbox->info("children") )[0];
        $mainbox->selectionSet($curr_entry);
        $mainbox->see($curr_entry);
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
    print "MainWindow unbusy now\n" if $debug;

    $status = sprintf( "Displaying %d search result%s ",
        $numrows, $numrows == 1 ? "" : "s" );
    $status .= "($invalid invalid) " if $invalid;
    $status .= "($diff seconds elapsed)";
    $mainbox->yview( 'scroll', 1, 'units' );
    $mainbox->update;
    $mainbox->yview( 'scroll', -1, 'units' );
}

sub return_longcat
{
    print "Returning the long name of a category\n" if $debug;
    my $category = shift;
    my $query    = "SELECT description FROM categories WHERE code='$category'";
    print "Running query $query\n" if $debug;
    my $longcat_ref = $dbh->selectrow_hashref($query);
    print "Returning $longcat_ref->{description}\n" if $debug;
    return ( $longcat_ref->{description} );
}

sub build_main_categories_menu
{

    print "Building the main categories menu\n" if $debug;

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
        print
          "Adding radio button with label $cat_hashref->{description} and value $cat_hashref->{code}\n"
          if $debug;
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

    print "Doing exit\n" if $debug;

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
        print "Disconnecting from $dbh\n" if $debug;
        $dbh->disconnect;
        if ( $^O eq "MSWin32" )
        {

            # Close the MP3 player on a Windows system
            print "Killing process $mp3_pid on Win32\n" if $debug;
            Win32::Process::KillProcess( $mp3_pid, 1 );
        }
        elsif ( $^O eq "darwin" )
        {
            RunAppleScript(qq (tell application "Audion 3" to quit));
        }
        else
        {

            # Close the MP3 player on a Unix system.
            print "Kill -15 $mp3_pid\n" if $debug;
            kill( 15, $mp3_pid );
        }
        Tk::exit;
        close(STDERR);
        close(STDOUT);
    }
}

sub rightclick_menu
{

    print "Display menu on right click\n" if $debug;
    ###TAG###
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

    print "Created menu, setting Popup\n" if $debug;
    $rightmenu->Popup(
        -popover   => 'cursor',
        -popanchor => 'nw'
    );
}

sub read_rcfile
{

    print "Reading config file\n" if $debug;

    # Opens the configuration file, of the form var_name::value, and assigns
    # the value to the variable name.
    # On MS Windows, it also converts long pathnames to short ones.

    if ( -r $rcfile )
    {
        print "rcfile $rcfile is readable\n" if $debug;
        open( my $rcfile_fh, "<", $rcfile );
        print "rcfile open\n" if $debug;
        while (<$rcfile_fh>)
        {
            chomp;
            my ( $key, $value ) = split(/::/);
            print "Read key $key, value $value from rcfile\n" if $debug;
            $config{$key} = $value;
        }
    }
    else
    {
        print "rcfile $rcfile not found or unreadable.\n" if $debug;
        $mw->deiconify();
        $mw->raise();
        my $norcbox = $mw->Dialog(
            -title => "Configuration file not found",
            -text  =>
              "Could not find Mr. Voice configuration file at $rcfile\n\nIf this is your first time running Mr. Voice, we can perform a default configuration for you.  Or, we can open the preferences so that you can set the values yourself.",
            -buttons =>
              [ "Perform Default Configuration", "Manual Configuration" ]
        );
        print "Showing norcbox\n" if $debug;
        my $response = $norcbox->Show;
        if ( $response eq "Manual Configuration" )
        {
            print "Editing preferences from Manual Configuration\n" if $debug;
            edit_preferences();
            print "Done editing preferences from Manual Configuration\n"
              if $debug;
        }
        else
        {
            print "Performing default configuration\n" if $debug;
            $config{filepath} =
              ( $^O eq "MSWin32" )
              ? catfile( "C:",          "mp3" )
              : catfile( get_homedir(), "mp3" );
            print "Filepath is $config{filepath}\n" if $debug;
            my $string =
              "Performing default configuration.\n\nCreating MP3 directory $config{filepath}...";

            if ( -d $config{filepath} )
            {
                print "Filepath $config{filepath} already exists\n" if $debug;
                $string .= "Already exists, using it\n\n";
            }
            else
            {
                $string .=
                  mkdir( $config{filepath} )
                  ? "directory created\n\n"
                  : "directory creation failed!\n\n";
                print "Made directory $config{filepath}\n" if $debug;
            }

            $config{savedir} =
              ( $^O eq "MSWin32" )
              ? catfile( "C:",          "hotkeys" )
              : catfile( get_homedir(), "hotkeys" );
            print "Savedir is $config{savedir}\n" if $debug;
            $string .= "Creating hotkey directory $config{savedir}...";
            if ( -d $config{savedir} )
            {
                print "Savedir $config{savedir} already exists\n" if $debug;
                $string .= "Already exists, using it\n\n";
            }
            else
            {
                $string .=
                  mkdir( $config{savedir} )
                  ? "directory created\n\n"
                  : "directory creation failed!\n\n";
                print "Made savedir directory $config{savedir}\n" if $debug;
            }

            $config{db_file} =
              ( $^O eq "MSWin32" )
              ? catfile( "C:",          "mrvoice.db" )
              : catfile( get_homedir(), "mrvoice.db" );
            print "DB File is $config{db_file}\n" if $debug;
            $string .= "Setting database file $config{db_file}...";
            if ( -r $config{db_file} )
            {
                print "DB File $config{db_file} already exists\n" if $debug;
                $string .=
                  "Already exists, using it (but make sure it's really a Mr. Voice database file)\n\n";
            }
            else
            {
                print "DB File $config{db_file} does not already exists\n"
                  if $debug;
                $string .=
                  "Does not exist, so Mr. Voice will initialize it after you view the preferences\n\n";
            }

            if ( $^O eq "MSWin32" )
            {
                $config{mp3player} =
                  Win32::GetShortPathName("C:/Program Files/Winamp/Winamp.exe");
            }
            elsif ( $^O eq "darwin" )
            {
                $config{mp3player} = "Audion";
            }
            else
            {
                $config{mp3player} = "/usr/bin/xmms";
            }
            print "MP3 player is $config{mp3player}\n" if $debug;
            $string .= "Looking for MP3 player in $config{mp3player}...";
            if ( $^O eq "darwin" )
            {
                $string .= "Skipping\n\n";
            }
            else
            {
                $string .=
                  ( -f $config{mp3player} )
                  ? "found it\n\n"
                  : "nothing there!\n\n";
            }

            $string .=
              "Now, we will launch the preferences so that you can doublecheck everything.";

            my $defaultdonebox = $mw->Dialog(
                -title   => "Finished default setup",
                -text    => $string,
                -buttons => ["Launch Preferences"]
            );
            print "Showing defaultdonebox\n" if $debug;
            $defaultdonebox->Show;
            print "defaultdonebox shown, editing preferences\n" if $debug;
            edit_preferences();
            print "Editing preferences done\n" if $debug;
        }
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

    print "Starting the drag\n" if $debug;

    # Starts the drag for the hotkey drag-and-drop.
    my $sound_icon = $mw->Photo( -data => soundicon_gif() );

    my $token = shift;
    print "The token is $token\n" if $debug;
    $current_token = $token;
    my $widget = $current_token->parent;
    my $event  = $widget->XEvent;
    my $index  = $widget->nearest( $event->y );
    print "The index is $index\n" if $debug;
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

    print "Dropping onto a hotkey\n" if $debug;

    # Assigns the dragged token to the hotkey that it's dropped onto.

    if ( $lock_hotkeys == 1 )
    {
        print "Hotkeys are locked, doing nothing\n" if $debug;
        $status = "Can't drop hotkey - hotkeys locked";
        return;
    }
    my $fkey_var = shift;
    print "Fkey var is $fkey_var\n" if $debug;
    my $widget      = $current_token->parent;
    my (@selection) = $widget->info('selection');
    my $id          = $widget->info( 'data', $selection[0] );
    print "Got ID $id\n" if $debug;
    my $filename = get_info_from_id($id)->{filename};
    my $title    = get_info_from_id($id)->{fulltitle};
    $fkeys{$fkey_var}->{id}       = $id;
    $fkeys{$fkey_var}->{filename} = $filename;
    $fkeys{$fkey_var}->{title}    = $title;
}

sub Tank_Drop
{
    print "Dropping onto the holding tank\n" if $debug;
    my $dnd_source = shift;
    my $parent     = $dnd_source->parent;
    my (@indices)  = $parent->info('selection');
    foreach my $index (@indices)
    {
        print "Dropping index $index\n" if $debug;
        my $text = $parent->itemCget( $index, 0, '-text' );
        my $id = $parent->info( 'data', $index );
        $tankbox->add( $id, -data => $id, -text => $text );
        my $info = get_info_from_id($id);
        if ( !-e catfile( $config{'filepath'}, $info->{filename} ) )
        {
            my $style = $tankbox->ItemStyle(
                'text',
                -foreground       => 'red',
                -background       => 'white',
                -selectforeground => 'red'
            );
            $tankbox->entryconfigure( $id, -style => $style );
        }
    }
    if ( $#indices > 1 )
    {
        $parent->selectionClear();
    }
}

sub create_new_database
{
    my $dbfile = shift;
    my $create_dbh;
    my @queries;
    print "Connecting to dbi:SQLite:dbname=$dbfile\n" if $debug;
    if (
        !( $create_dbh = DBI->connect( "dbi:SQLite:dbname=$dbfile", "", "" ) ) )
    {
        die "Could not create new database file $dbfile via DBI";
    }
    print "Connected to dbi:SQLite:dbname=$dbfile\n" if $debug;

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
        print "Preparing query -->$query<--\n" if $debug;
        my $sth = $create_dbh->prepare($query);
        $sth->execute or die "Could not run database query $query";
        print "Executed query -->$query<--\n" if $debug;
    }

    $status = "New database $dbfile initialized successfully";
}

#########
# MAIN PROGRAM
#########
print "Starting Mr. Voice version $version at " . scalar(localtime) . "\n"
  if $debug;
$|  = 1;
$mw = MainWindow->new;
$mw->withdraw();
our $menubar = $mw->Menu;
$mw->configure( -menu => $menubar );
$mw->geometry("+0+0");
$mw->title("Mr. Voice");
$mw->minsize( 67, 2 );
$mw->protocol( 'WM_DELETE_WINDOW', \&do_exit );
$icon = $mw->Pixmap( -data => icon_data() );
$mw->Icon( -image => $icon );

print "Reading rcfile\n" if $debug;
read_rcfile();
print "Read rcfile\n" if $debug;

if ( !defined $config{db_file} )
{
    print "db_file not defined, doing database configuration\n" if $debug;
    $mw->deiconify();
    $mw->raise();
    print "MainWindow deiconified and raised\n" if $debug;
    my $box = $mw->DialogBox( -title => "Fatal Error", -buttons => ["Ok"] );
    $box->Icon( -image => $icon );
    $box->add( "Label",
        -text =>
          "You have not configured a location for your Mr. Voice database file.\nYou will now be taken to the preferences, where you can select the location\nof the file.  Then restart Mr. Voice to see the changes."
    )->pack();
    print "Showing 'Need to configure db location' box\n" if $debug;
    my $result = $box->Show();
    print "Finished showing 'Need to configure db location' box\n" if $debug;

    if ($result)
    {
        print "Editing preferences for db configuration\n" if $debug;
        edit_preferences();
        print "Finished editing preferences for db configuration\n" if $debug;
        die "Died because database file not set";
    }
}

if ( !( -e $config{db_file} ) )
{
    print "db_file $config{db_file} configured, but file does not exist\n"
      if $debug;
    my $box = $mw->DialogBox(
        -title          => "Database Error",
        -buttons        => [ "Create", "Cancel" ],
        -default_button => "Cancel"
    );
    $box->Icon( -image => $icon );
    $box->add( "Label",
        -text =>
          "You have chosen $config{db_file} as your database file,\nbut it does not exist.\n\nYou can either create and initialize a new Mr. Voice database at that location, or\nCancel and select the proper location of your database file"
    )->pack();
    print "Showing 'initialized database' box\n" if $debug;
    my $result = $box->Show();
    print "Finished showing 'initialized database' box\n" if $debug;
    if ( $result eq "Create" )
    {
        print "Creating new database $config{db_file}\n" if $debug;
        create_new_database( $config{db_file} );
        print "Finished creating new database $config{db_file}\n" if $debug;
    }
    else
    {
        print "Editing preferences to set database location manually\n"
          if $debug;
        edit_preferences();
        print
          "Finished editing preferences to set database location manually.  Dying.\n"
          if $debug;
        die "Died because we could not access database file $config{db_file}";
    }
}

if ( !( -w $config{db_file} ) )
{
    print "Could not write to db_file $config{db_file}\n" if $debug;
    my $box = $mw->DialogBox( -title => "Fatal Error", -buttons => ["Ok"] );
    $box->Icon( -image => $icon );
    $box->add( "Label",
        -text =>
          "Could not write to database file $config{db_file}\nYou have configured Mr. Voice to find its database file at the location above, but\nthe file cannot be written to.  Make sure that Mr. Voice has permission to write to\nthe file, or make sure that you are looking for the file in the right place.\nAfter fixing the problem, restart Mr. Voice."
    )->pack();
    print "Showing db_file write error box\n" if $debug;
    my $result = $box->Show();
    print "Showed db_file write error box\n" if $debug;

    if ($result)
    {
        print "Editing preferences for db_file write error\n" if $debug;
        edit_preferences();
        print "Edited preferences for db_file write error.  Dying.\n" if $debug;
        die "Died because we could not write to database file $config{db_file}";
    }
}

if ( !( $dbh = DBI->connect( "dbi:SQLite:dbname=$config{db_file}", "", "" ) ) )
{
    print
      "Could not connect to dbi:SQLite:dbname=$config{db_file} with error $DBI::errstr\n"
      if $debug;
    my $box = $mw->DialogBox( -title => "Fatal Error", -buttons => ["Ok"] );
    $box->Icon( -image => $icon );
    $box->add( "Label", -text => "Could not connect to database." )->pack();
    $box->add( "Label",
        -text => "Make sure your database configuration is correct." )->pack();
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
    print "Showing DBI connect error box\n" if $debug;
    my $result = $box->Show();
    print "Showed DBI connect error box\n" if $debug;

    if ($result)
    {
        print "Editing preferences after DBI error\n" if $debug;
        edit_preferences();
        print "Edited preferences after DBI error.  Dying\n" if $debug;
        die "Died with database error $DBI::errstr\n";
    }
}

if ( !-W $config{'filepath'} )
{
    print "Could not write to MP3 directory $config{'filepath'}\n" if $debug;
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
    print "Showing 'could not write to MP3 directory' box\n" if $debug;
    my $result = $box->Show();
    print "Showed 'could not write to MP3 directory' box\n" if $debug;

    if ($result)
    {
        print "Editing preferences after unable to write to MP3 directory\n"
          if $debug;
        edit_preferences();
        print
          "Edited preferences after unable to write to MP3 directory.  Dying\n"
          if $debug;
        die("Error accessing MP3 directory\n");
    }
}

if ( !-W $config{'savedir'} )
{
    print "Could not write to hotkey directory $config{savedir}\n" if $debug;
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
    print "Showing 'could not write to hotkey directory' box\n" if $debug;
    my $result = $box->Show();
    print "Showed 'could not write to hotkey directory' box\n" if $debug;
}

# We use the following statement to open the MP3 player asynchronously
# when the Mr. Voice app starts.

if ( ( !-x $config{'mp3player'} ) && ( $^O ne "darwin" ) )
{
    print "Could not execute MP3 player $config{'mp3player'}\n" if $debug;
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
        print "Creating Win32::Process for $config{'mp3player'}\n" if $debug;
        Win32::Process::Create( $object, $config{'mp3player'}, '', 1,
            NORMAL_PRIORITY_CLASS(), "." );
        $mp3_pid = $object->GetProcessID();
        print "Got Win32::Process id $mp3_pid\n" if $debug;
        sleep(1);
    }
    elsif ( $^O eq "darwin" )
    {
        RunAppleScript(qq( tell application "Audion 3" to activate));
    }
    else
    {

        # Start the MP3 player on a Unix system using fork/exec
        print "Forking to exec $config{'mp3player'}\n" if $debug;
        $mp3_pid = fork();
        print "Got PID $mp3_pid\n" if $debug;
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

    print "Processing orphans\n" if $debug;

    # Build up a list of all files in the filepath directory
    my @mp3files = glob( catfile( $config{filepath}, "*.mp3" ) );
    my @oggfiles = glob( catfile( $config{filepath}, "*.ogg" ) );
    my @wavfiles = glob( catfile( $config{filepath}, "*.wav" ) );
    my @m4afiles = glob( catfile( $config{filepath}, "*.m4a" ) );
    my @mp4files = glob( catfile( $config{filepath}, "*.mp4" ) );
    my @m3ufiles = glob( catfile( $config{filepath}, "*.m3u" ) );
    my @plsfiles = glob( catfile( $config{filepath}, "*.pls" ) );
    my @wmafiles = glob( catfile( $config{filepath}, "*.wma" ) )
      if ( $^O eq "MSWin32" );
    my @files = (
        @mp3files, @oggfiles, @wavfiles, @m3ufiles,
        @plsfiles, @m4afiles, @mp4files
    );
    push( @files, @wmafiles ) if ( $^O eq "MSWin32" );
    my @orphans;

    # Display a ProgressBar while we scan the files
    $mw->Busy( -recurse => 1 );
    my $percent_done = 0;
    my $file_count   = 0;
    print "Creating progressbox toplevel\n" if $debug;
    my $progressbox = $mw->Toplevel();
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
    print "Updated, deiconified, and raised progressbox\n" if $debug;

    # Cycle through each file and check whether or not a database entry
    # references it.
    foreach my $file (@files)
    {
        print "Checking file $file\n" if $debug;
        $file = basename($file);
        my $query = "SELECT * FROM mrvoice WHERE filename='$file'";
        if ( get_rows($query) == 0 )
        {
            push( @orphans, $file );
            print "File $file is an orphan\n" if $debug;
        }
        $file_count++;
        $percent_done = int( ( $file_count / $#files ) * 100 );
        $pb->set($percent_done);
        $progressbox->update();
    }
    print "Setting MainWindow to unbusy\n" if $debug;
    $mw->Unbusy( -recurse => 1 );
    print "MainWindow unbusy\n" if $debug;
    $progressbox->destroy();

    if ( $#orphans == -1 )
    {
        $status = "No orphaned files found";
        return;
    }

    print "We have orphans, so create a toplevel to report\n" if $debug;

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
        -background => 'white',
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

    print "Showing orphan report toplevel to report\n" if $debug;
    $orphanbox->update();
    $orphanbox->deiconify();
    $orphanbox->raise();
    print "Showed orphan report toplevel to report\n" if $debug;
}

sub advanced_search
{
    print "Running advanced search function\n" if $debug;
    my $query = "select modtime from mrvoice order by modtime asc limit 1";
    my $firstdate_ref = $dbh->selectrow_hashref($query);
    my $firstdate     = $firstdate_ref->{modtime};
    my @timearray     = localtime($firstdate);

    $firstdate =~ /(\d\d)(\d\d)(\d\d)/;

    my $start_month = $timearray[4] + 1;
    my $start_date  = $timearray[3];
    my $start_year  = $timearray[5] + 1900;

    my @today     = localtime();
    my $end_month = $today[4] + 1;
    my $end_date  = $today[3];
    my $end_year  = $today[5] + 1900;

    my @months = (
        '',    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
        'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    );

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
        -text        => "$months[$start_month]",
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
                update_button( $start_month_button, $months[$start_month] );
            }
        );
    }
    $adv_searchframe_start->Label( -text => "/" )->pack( -side => 'left' );

    my $start_date_button = $adv_searchframe_start->Menubutton(
        -text        => "$start_date",
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
              sub { update_button( $start_date_button, $start_date ); }
        );
    }
    $adv_searchframe_start->Label( -text => "/" )->pack( -side => 'left' );
    my $start_year_button = $adv_searchframe_start->Menubutton(
        -text        => "$start_year",
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
              sub { update_button( $start_year_button, $start_year ); }
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
        -text        => "$months[$end_month]",
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
            -command  => sub { update_button( $end_month_button, $end_month ); }
        );
    }
    $adv_searchframe_end->Label( -text => "/" )->pack( -side => 'left' );

    my $end_date_button = $adv_searchframe_end->Menubutton(
        -text        => "$end_date",
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
            -command  => sub { update_button( $end_date_button, $end_date ); }
        );
    }
    $adv_searchframe_end->Label( -text => "/" )->pack( -side => 'left' );
    my $end_year_button = $adv_searchframe_end->Menubutton(
        -text        => "$end_year",
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
            -command  => sub { update_button( $end_year_button, $end_year ); }
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
            my $startdate =
              UnixDate( ParseDate("$start_year-$start_month-$start_date 00:00"),
                "%s" );
            my $enddate =
              UnixDate( ParseDate("$end_year-$end_month-$end_date 23:59"),
                "%s" );
            do_search( "range", $startdate, $enddate );
        }
    }

    else
    {
        $status = "Advanced Search Cancelled";
    }
}

sub update_button()
{
    my ( $button, $value ) = @_;
    $button->configure( -text => "$value" );
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
$extrainfo_frame->Entry(
    -background   => 'white',
    -textvariable => \$cattext
)->pack( -side => 'left' );

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
$artist_frame->Entry(
    -background   => 'white',
    -textvariable => \$artist
)->pack( -side => 'left' );

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
$title_frame->Entry(
    -background   => 'white',
    -textvariable => \$title
)->pack( -side => 'left' );

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
$anyfield_frame->Entry(
    -background   => 'white',
    -textvariable => \$anyfield
)->pack( -side => 'left' );
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
    'HList',
    -scrollbars       => 'osoe',
    -background       => 'white',
    -selectbackground => 'navy',
    -selectforeground => 'white',
    -width            => 100,
    -selectmode       => "extended"
  )->pack(
    -fill   => 'both',
    -expand => 1,
    -side   => 'top'
  );
$mainbox->bind( "<Double-Button-1>", \&play_mp3 );
$mainbox->bind( "<Button-1>", sub { $mainbox->focus(); } );
$mainbox->bind( "<Button-3>", [ \&rightclick_menu ] );

$mainbox->DropSite(
    -dropcommand => [ \&accept_songdrop, $mainbox ],
    -droptypes => ( $^O eq 'MSWin32' ? 'Win32' : [ 'XDND', 'Sun' ] )
);

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
            $status = "Playing Fade-Stopped";
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

print "Binding hotkeys\n" if $debug;
bind_hotkeys($mw);
$mw->bind( "<Control-Key-p>", [ \&play_mp3, "Current" ] );
print "Bound hotkeys\n" if $debug;

# If the default hotkey file exists, load that up.
if ( -r catfile( $config{'savedir'}, "default.mrv" ) )
{
    print "Loading default hotkey file default.mrv\n" if $debug;
    open_file( $mw, catfile( $config{'savedir'}, "default.mrv" ) );
    print "Loaded default hotkey file default.mrv\n" if $debug;
}

print "Deiconifying and raising MainWindow\n" if $debug;
$mw->deiconify();
$mw->raise();
print "Deiconified and raised, running MainLoop now\n" if $debug;

foreach my $file ( glob( catfile( $config{plugin_dir}, "*.pl" ) ) )
{
    require $file;
}

MainLoop;

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

# We'll give you a default category to put things in.  It can
# be deleted from within the program if you don't want it.
INSERT INTO categories VALUES (
  'GEN','General Category'
);
