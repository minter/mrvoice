#!/usr/bin/perl 
use warnings;
use diagnostics;
#use strict; # Yeah right
use Tk;
use Tk::DialogBox;
use Tk::DragDrop;
use Tk::DropSite;
use Tk::NoteBook;
use Tk::BrowseEntry;
use Tk::ProgressBar;
use File::Basename;
use File::Copy;
use DBI;
use MPEG::MP3Info;
use Audio::Wav;
use Date::Manip;
use Time::Local;

# These modules need to be hardcoded into the script for perl2exe to 
# find them.
use Tk::Photo;
use Tk::Menu;
use Tk::Menubutton;
use Tk::Checkbutton;
use DBD::mysql;
use Carp::Heavy;

use subs qw/filemenu_items hotkeysmenu_items categoriesmenu_items songsmenu_items advancedmenu_items helpmenu_items/;

#########
# AUTHOR: H. Wade Minter <minter@lunenburg.org>
# TITLE: mrvoice.pl
# DESCRIPTION: A Perl/TK frontend for an MP3 database.  Written for
#              ComedyWorx, Raleigh, NC.
#              http://www.comedyworx.com/
# CVS ID: $Id: mrvoice.pl,v 1.188 2002/12/12 18:43:10 minter Exp $
# CHANGELOG:
#   See ChangeLog file
# CREDITS:
#   See Credits file
##########

# Declare global variables, until I'm good enough to work around them.
our ($db_name,$db_username,$db_pass,$category,$mp3player,$filepath,$savedir);

#####
# YOU SHOULD NOT NEED TO MODIFY ANYTHING BELOW HERE FOR NORMAL USE
#####

our $savefile_count = 0;		# Counter variables
our $savefile_max = 4;			# The maximum number of files to
					# keep in the "recently used" list.
    $category = 'Any';			# The default category to search
                                        # Initial status message
our $hotkeytypes = [
    ['Mr. Voice Hotkey Files', '.mrv'],
    ['All Files', '*'],
  ];

our $databasefiles = [
    ['Database Dump Files', '.sql'],
    ['All Files', '*'],
  ];

our $mp3types = [
    ['MP3 Files', ['*.mp3', '*.MP3']],
    ['WAV Files', ['*.wav', '*.WAV']],
    ['Vorbis Files', ['*.ogg', '*.OGG']],
    ['Playlists', ['*.m3u', '*.M3U', '*.pls', '*.PLS']],
    ['All Files', '*'],
  ];

# Check to see if we're on Windows or Linux, and set the RC file accordingly.
if ("$^O" eq "MSWin32")
{
  our $rcfile = "C:\\mrvoice.cfg";
  BEGIN 
  {
    if ($^O eq "MSWin32")
    {
      require LWP::UserAgent;
      LWP::UserAgent->import();
      require HTTP::Request;
      HTTP::Request->import();
      require Win32::Process;
      Win32::Process->import();
    }
  }
  $agent = LWP::UserAgent->new;
  $agent->agent("Mr. Voice Audio Software/$0 ");


  # You have to manually set the time zone for Windows.
  my ($l_min, $l_hour, $l_year, $l_yday) = (localtime $^T)[1, 2, 5, 7];
  my ($g_min, $g_hour, $g_year, $g_yday) = (   gmtime $^T)[1, 2, 5, 7];
  my $tzval = ($l_min - $g_min)/60 + $l_hour - $g_hour + 24 * ($l_year <=> $g_year || $l_yday <=> $g_yday);
  $tzval=sprintf( "%2.2d00", $tzval);
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
  our $rcfile = "$homedir/.mrvoicerc";
  require Ogg::Vorbis;
  Ogg::Vorbis->import();
}

#STARTCSZ
# The following variables set the locations of MP3s for static hotkey'd
# sounds
#$altt = "TaDa.mp3";
#$alty = "CalloutMusic.mp3";
#$altb = "BrownBag.mp3";
#$altg = "Groaner.mp3";
#$altv = "PriceIsRightTheme.mp3";
#ENDCSZ

#####

my $version = "1.7";			# Program version
our $status = "Welcome to Mr. Voice version $version";		

# Define 32x32 XPM icon data
our $icon_data = <<'end-of-icon-data';
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

our $sound_icon_data = <<end_of_data;
R0lGODlhGQAgAOcAAP/////////////////////////////3///3///3///3///3///3//f3//f3
//f3//f3//f3//f39/f39/f39/f39/f39/f39/fv9/fv9/fv9/fv9/fv9+/v9+/v9+/v9+/v9+/v
9+/v7+/v7+/v7+/v7+/v7+fn5+fn5+fn5+fn5+fn597e3t7e3t7e3t7e3t7e3t7e3s7O/87O/87O
/87O/87O/87O/87Ozs7Ozs7Ozs7Ozs7OzsbGxsbGxsbGxsbGxsbGxr29vb29vb29vb29vb29vbW1
tbW1tbW1tbW1tbW1ta21ta21ta21ta21ta21ta2tra2tra2tra2tra2tra2tra2lpa2lpa2lpa2l
pa2lpaWlpaWlpaWlpaWlpaWlpaWlpZyc/5yc/5yc/5yc/5yc/5yc/5SUlJSUlJSUlJSUlJSUlIyM
jIyMjIyMjIyMjIyMjISEhISEhISEhISEhISEhHt7e3t7e3t7e3t7e3t7e3Nzc3Nzc3Nzc3Nzc3Nz
c3Nzc2NjzmNjzmNjzmNjzmNjzmNjzmNjY2NjY2NjY2NjY2NjY1paWlpaWlpaWlpaWlpaWlpaWlJS
UlJSUlJSUlJSUlJSUkpSUkpSUkpSUkpSUkpSUkpKSkpKSkpKSkpKSkpKSkJKSkJKSkJKSkJKSkJK
SkJKSkJCQkJCQkJCQkJCQkJCQjk5OTk5OTk5OTk5OTk5OTExYzExYzExYzExYzExYzExMTExMTEx
MTExMTExMTEpKTEpKTEpKTEpKTEpKSkxKSkxKSkxKSkxKSkxKSkpKSkpKSkpKSkpKSkpKSEpISEp
ISEpISEpISEpISEhKSEhKSEhKSEhKSEhKSEhKSEhISEhISEhISEhISEhIRghIRghIRghIRghIRgh
IRgYGBgYGBgYGBgYGBgYGBAQEBAQEBAQEBAQEBAQEAgIEAgIEAgIEAgIEAgIEAgICAgICAgICAgI
CAgICAgAAAgAAAgAAAgAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAGQAgAAAI/gABCBTI
AhGiRggTdmrUqWHDVp1atRoIQIRBEQM7VKyIQYRHjCJY8BpoEUcjjxU/slAZkgULIRMBFBRikUXK
jyFzunQZxVhFRDQBnESJU+dKl0xazVwptGjRozuFGEO4EBNCpjiPtjzasxGaKF/R0CT61GgUiDI9
Hr2Z1SiLrhg3gqzIQlZOi1vfGusUlyRdWXbVirgDtSemviBDyhIUmO9KRC178qWIsa4gMYI+Oh7M
E9zkjTIXi5GRWXNIyHo/ExQtA0BmpSIauST81rNGAIBZAyAtwvHJxyKieI4rS4wYIQJl8BbRymOn
2bU/i6GoXEzg5ix+Exb+uThm48YbqK+UXVN4TAD/BKkHb90jdseE0QwX+K/++vDMPf5msR3ceQBC
CJHeZe1hRx5tUfzTHEUADtjeR+Qh0lknt80loHqBscBXSLTJ55NfFV34z3g5ofaWggwSJeA/LJl4
4oICxQWSgDihFhmKlCUmwlgrueUhZTGK0JFgbr04EAZysSUYVCyg8Y8xO0YhBBNRVGmllV+BpeVX
Chrj5ZfbgCPmmGL+UyY49dUXEAA7
end_of_data

our $logo_photo_data = <<end_of_data;
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
end_of_data

# If you have Tk800.024 with Nik's patch, you don't need this Tk::Wm
# patch.
#
#if ($^O ne "MSWin32")
#{
#  sub Tk::Wm::Post
#  {
#    my ($w,$X,$Y) = @_;
#    $X = int($X);
#    $Y = int($Y);
#    $w->positionfrom('user');
#    # $w->geometry('+$X+$Y');
#    $w->MoveToplevelWindow($X,$Y);
#    $w->deiconify;
#    # $w->idletasks; # to prevent problems with KDE's kwm etc.
#    # $w->raise;
#  }
#}

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
  if (defined $e)
  {
    my $X = $e->X;
    my $Y = $e->Y;
    $token->MoveToplevelWindow($X+3,$Y+3);
    $token->NewDrag;
    $token->FindSite($X,$Y,$e);
  }
}

sub BindMouseWheel {
 
  my($w) = @_;
  
  if ($^O eq 'MSWin32') 
  {
    $w->bind('<MouseWheel>' =>
    [ sub { $_[0]->yview('scroll', -($_[1] / 120) * 3, 'units') },
    Ev('D') ]);
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
    
    $w->bind('<4>' => sub {
      $_[0]->yview('scroll', -3, 'units') unless $Tk::strictMotif;
    });
     
    $w->bind('<5>' => sub {
      $_[0]->yview('scroll', +3, 'units') unless $Tk::strictMotif;
    });
  }
      
} # end BindMouseWheel


sub bind_hotkeys
{
  # This will set up hotkeybindings for the window that is passed
  # in as the first argument.

  my $window = $_[0];
  $window->bind("<Key-F1>", [\&play_mp3,"F1"]);
  $window->bind("<Key-F2>", [\&play_mp3,"F2"]);
  $window->bind("<Key-F3>", [\&play_mp3,"F3"]);
  $window->bind("<Key-F4>", [\&play_mp3,"F4"]);
  $window->bind("<Key-F5>", [\&play_mp3,"F5"]);
  $window->bind("<Key-F6>", [\&play_mp3,"F6"]);
  $window->bind("<Key-F7>", [\&play_mp3,"F7"]);
  $window->bind("<Key-F8>", [\&play_mp3,"F8"]);
  $window->bind("<Key-F9>", [\&play_mp3,"F9"]);
  $window->bind("<Key-F10>", [\&play_mp3,"F10"]);
  $window->bind("<Key-F11>", [\&play_mp3,"F11"]);
  $window->bind("<Key-F12>", [\&play_mp3,"F12"]);
  $window->bind("<Key-Escape>", [\&stop_mp3]);
  $window->bind("<Key-Return>", \&do_search);
  $window->bind("<Control-Key-x>", \&do_exit);
  $window->bind("<Control-Key-o>", \&open_file);
  $window->bind("<Control-Key-s>", \&save_file);
  $window->bind("<Control-Key-h>", \&list_hotkeys);
  #STARTCSZ
  #$window->bind("<Alt-Key-t>", [\&play_mp3,"ALT-T"]);
  #$window->bind("<Alt-Key-y>", [\&play_mp3,"ALT-Y"]);
  #$window->bind("<Alt-Key-b>", [\&play_mp3,"ALT-B"]);
  #$window->bind("<Alt-Key-g>", [\&play_mp3,"ALT-G"]);
  #$window->bind("<Alt-Key-v>", [\&play_mp3,"ALT-V"]);
  #ENDCSZ
  if ($^O eq "MSWin32")
  {
    $window->bind("<Shift-Key-Escape>", sub {
      $req = HTTP::Request->new(GET => "http://localhost:4800/fadeoutandstop?p=$httpq_pw");
      $res = $agent->request($req);
    });
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

  my $parentwidget = $_[0];
  my $selectedfile = $_[1];
  if (!$selectedfile)
  {
     $selectedfile = $mw->getOpenFile(-filetypes=>$hotkeytypes,
                                      -initialdir=>$savedir,
                                      -title=>'Open a File');
  }
                      
  if ($selectedfile)
  {
    if (! -r $selectedfile)
    {
      infobox($mw, "File Error", "Could not open file $selectedfile for reading");
    }
    else
    {
      backup_hotkeys();
      open (HOTKEYFILE,$selectedfile);
      while (<HOTKEYFILE>)
      {
        chomp;
        my ($var1,$var2) = split(/::/);
        $$var1=$var2;
      }
      close (HOTKEYFILE);
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
  # then write out the data in the form of hotkey_number::mp3_name.
  # Finally, we add this file to our dynamic documents menu.

  $selectedfile = $mw->getSaveFile(-title=>'Save a File',
                                   -defaultextension=>".mrv",
                                   -filetypes=>$hotkeytypes,
                                   -initialdir=>"$savedir");

  if ($selectedfile)
  {
    if ( (! -w $selectedfile) && (-e $selectedfile) )
    {
      infobox($mw, "File Error!", "Could not open file $selectedfile for writing");
    }
    elsif ( ! -w dirname($selectedfile) )
    {
      my $directory = dirname($selectedfile);
      infobox($mw, "Directory Error!", "Could not write new file to directory $directory");
    }
    else
    {
      $selectedfile = "$selectedfile.mrv" unless ($selectedfile =~ /.*\.mrv$/);
      open (HOTKEYFILE,">$selectedfile");
      print HOTKEYFILE "f1::$f1\n";
      print HOTKEYFILE "f2::$f2\n";
      print HOTKEYFILE "f3::$f3\n";
      print HOTKEYFILE "f4::$f4\n";
      print HOTKEYFILE "f5::$f5\n";
      print HOTKEYFILE "f6::$f6\n";
      print HOTKEYFILE "f7::$f7\n";
      print HOTKEYFILE "f8::$f8\n";
      print HOTKEYFILE "f9::$f9\n";
      print HOTKEYFILE "f10::$f10\n";
      print HOTKEYFILE "f11::$f11\n";
      print HOTKEYFILE "f12::$f12\n";
      close (HOTKEYFILE);
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
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  $year += 1900;
  $mon += 1;
  $defaultfilename = "database-$year-$mon-$mday.sql";
  my $dumpfile = $mw->getSaveFile(-title=>'Choose Database Export File',
                                 -defaultextension=>".sql",
                                 -initialfile=>$defaultfilename,
                                 -filetypes=>$databasefiles);

  if ($dumpfile)
  {
    if ( (! -w $dumpfile) && (-e $dumpfile) )
    {
      infobox($mw, "File Error!", "Could not open file $dumpfile for writing");
    }
    elsif ( ! -w dirname($dumpfile) )
    {
      my $directory = dirname($dumpfile);
      infobox($mw, "Directory Error!", "Could not write new file to directory $directory");
    }
    else
    {
      # Run the MySQL Dump
      if ($^O eq "MSWin32")
      {
        $dirname = Win32::GetShortPathName(dirname($dumpfile));
        $filename = basename($dumpfile);
        $shortdumpfile = "$dirname/$filename";
        my $rc = system ("C:/mysql/bin/mysqldump --add-drop-table --user=$db_username --password=$db_pass $db_name > $shortdumpfile");
        infobox($mw, "Database Dumped", "The contents of your database have been dumped to the file:\n$dumpfile\n\nNote: In order to have a full backup, you must also\nback up the files from the directory:\n$filepath\nas well as $rcfile and, optionally, the hotkeys from $savedir");
        $status = "Database dumped to $dumpfile";
      }
      else
      {
        my $rc = system ("mysqldump --add-drop-table --user=$db_username --password=$db_pass $db_name > $dumpfile");
        infobox($mw, "Database Dumped", "The contents of your database have been dumped to the file:\n$dumpfile\n\nNote: In order to have a full backup, you must also\nback up the files from the directory:\n$filepath\nas well as $rcfile");
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
  my $dumpfile = $mw->getOpenFile(-title=>'Choose Database Export File',
                                 -defaultextension=>".sql",
                                 -filetypes=>$databasefiles);

  if ($dumpfile)
  {
    if (! -r $dumpfile)
    {
      infobox($mw, "File Error", "Could not open file $dumpfile for reading.\nCheck permissions and try again.");
    }
    else
    {
      # We can read the file - pop up a warning before continuing.
      my $box = $mw->DialogBox(-title=>"Warning", 
                               -buttons=>["Ok","Cancel"],
                               -default_button=>"Cancel");  
      $box->Icon(-image=>$icon);
      my $frame1 = $box->add("Frame")->pack(-fill=>'x');
      $frame1->Label(-text=>"Warning!\nImporting this database dumpfile will completely\noverwrite your current Mr. Voice database.\n\nIf you are certain that you want to do this,\npress Ok.  Otherwise, press Cancel.")->pack(); 
      my $button = $box->Show;
      
      if ($button eq "Ok")
      {
        if ($^O eq "MSWin32")
        {
          $dirname = Win32::GetShortPathName(dirname($dumpfile));
          $filename = basename($dumpfile);
          $shortdumpfile = "$dirname/$filename";
          my $rc = system ("C:/mysql/bin/mysql --user=$db_username --password=$db_pass $db_name < $shortdumpfile");
          infobox($mw, "Database Imported", "The database backup file $dumpfile\nhas been imported.");
          $status = "Database imported from $dumpfile";
        }
        else
        {
          my $rc = system ("mysql --user=$db_username --password=$db_pass $db_name < $dumpfile");
          infobox($mw, "Database Imported", "The database backup file $dumpfile\nhas been imported.");
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

sub dynamic_documents
{
  # This function takes a filename as an argument.  It then increments
  # a counter to keep track of how many documents we've accessed in this
  # session.  
  # It adds the file to the "Recent Files" menu off of Files, and if we're
  # over the user-specified limit, removes the oldest file from the list.
  
  $file = $_[0];

  my $fileentry;
  my $counter = 0;
  my $success = 0;
  foreach $fileentry (@current)
  {
    if ($fileentry eq $file)
    {
      # The item is currently in the list.  Move it to the front of
      # the line.
      splice (@current, $counter, 1);
      @current = ($file,@current);
      $counter++;
      $success=1;
    }
    else
    {
      $counter++;
    }
  }

  if ($success != 1)
  {
    # The file isn't in our current list, so we need to add it.
    @current = ($file, @current);
    $savefile_count++;
  }

  if ($#current >= $savefile_max)
  {
    pop (@current);
  }

  # Get rid of the old menu and rebuild from our array
  $dynamicmenu->delete(0,'end');
  foreach $fileentry (@current)
  {
    $dynamicmenu->command(-label=>"$fileentry",
                          -command => [\&open_file, $mw, $fileentry]);
  }
}

sub infobox
{
  # A generic wrapper function to pop up an information box.  It takes
  # a reference to the parent widget, the title for the box, and a 
  # formatted string of data to display.
  
  my ($parent_window, $title, $string) = @_;
  my $box = $parent_window->DialogBox(-title=>"$title", -buttons=>["OK"]);
  $box->Icon(-image=>$icon);
  $box->add("Label",-text=>"$string")->pack();
  $box->Show;
}

sub backup_hotkeys
{
  # This saves the contents of the hotkeys to temporary variables, so 
  # you can restore them after a file open, etc.

  $old_f1 = $f1;
  $old_f2 = $f2;
  $old_f3 = $f3;
  $old_f4 = $f4;
  $old_f5 = $f5;
  $old_f6 = $f6;
  $old_f7 = $f7;
  $old_f8 = $f8;
  $old_f9 = $f9;
  $old_f10 = $f10;
  $old_f11 = $f11;
  $old_f12 = $f12;
  $hotkeysmenu->menu->entryconfigure("Restore Hotkeys", -state=>"normal");
}

sub restore_hotkeys
{
  # Replaces the hotkeys with the old ones from backup_hotkeys()

  $f1 = $old_f1;
  $f2 = $old_f2;
  $f3 = $old_f3;
  $f4 = $old_f4;
  $f5 = $old_f5;
  $f6 = $old_f6;
  $f7 = $old_f7;
  $f8 = $old_f8;
  $f9 = $old_f9;
  $f10 = $old_f10;
  $f11 = $old_f11;
  $f12 = $old_f12;
  $status = "Previous hotkeys restored.";
  $hotkeysmenu->menu->entryconfigure("Restore Hotkeys", -state=>"disabled");
}

sub bulk_add
{
  my $box1 = $mw->DialogBox(-title=>"Add all songs in directory",
                            -buttons=>["Continue","Cancel"]);
  $box1->Icon(-image=>$icon);
  my $box1frame1 = $box1->add("Frame")->pack(-fill=>'x');
  $box1frame1->Label(-text=>"This will allow you to add all songs in a directory to a particular\ncategory, using the information stored in MP3 or OGG files to fill in\nthe title and artist.  You will have to go back after the fact to add Extra Info or do any\nediting.  If a file does not have at least a title embedded in it, it will not be added.\n\nChoose your directory and category below.")->pack(-side=>'top');
  my $box1frame2 = $box1->add("Frame")->pack(-fill=>'x');
  $box1frame2->Label(-text=>"Add To Category: ")->pack(-side=>'left');
  my $menu = $box1frame2->Menubutton(-text=>"Choose Category",
                                     -relief=>'raised',
                                     -tearoff=>0,
                                     -indicatoron=>1)->pack(-side=>'left');
  my $query="SELECT * from categories ORDER BY description";
  my $sth=$dbh->prepare($query);
  $sth->execute or die "can't execute the query: $DBI::errstr\n";
  while (@table_row = $sth->fetchrow_array)
  {
    $code=$table_row[0];
    $name=$table_row[1];
    $menu->radiobutton(-label=>$name,
                       -value=>$code,
                       -variable=>\$addsong_cat);
  }
  $sth->finish;
  my $box1frame3 = $box1->add("Frame")->pack(-fill=>'x');
  $box1frame3->Label(-text=>"Choose Directory: ")->pack(-side=>'left');
  $box1frame3->Entry()->pack(-side=>'left');

  my $firstbutton = $box1->Show;
}

sub add_category
{
  my $box = $mw->DialogBox(-title=>"Add a category", -buttons=>["Ok","Cancel"]);
  $box->Icon(-image=>$icon);
  my $acframe1 = $box->add("Frame")->pack(-fill=>'x');
  $acframe1->Label(-text=>"Category Code:  ")->pack(-side=>'left');
  $acframe1->Entry(-width=>6,
                  -textvariable=>\$addcat_code)->pack(-side=>'left');
  my $acframe2 = $box->add("Frame")->pack(-fill=>'x');
  $acframe2->Label(-text=>"Category Description:  ")->pack(-side=>'left');
  $acframe2->Entry(-width=>25,
                  -textvariable=>\$addcat_desc)->pack(-side=>'left');
  my $button = $box->Show;
  if ($button eq "Ok")
  {
    if (($addcat_code) && ($addcat_desc))
    {
      $addcat_desc = $dbh->quote($addcat_desc);
      $addcat_code =~ tr/a-z/A-Z/;
      my $query = "INSERT INTO categories VALUES ('$addcat_code',$addcat_desc)";
      my $sth=$dbh->prepare($query);
      if (! $sth->execute)
      {
        my $error_message = $sth->errstr();
        infobox($mw, "Database Error","Database returned error: $error_message\non query $query");
      }
      else
      {
	$status = "Added category $addcat_desc";
        infobox($mw,"Success","Category added.");
      }
      $sth->finish;
    }
    else 
    {
      infobox($mw, "Error","You must enter both a category code and a description");
    }
  }
  else
  {
    $status = "Cancelled adding category.";
  }
  $addcat_code="";
  $addcat_desc="";
}

sub edit_category
{
  my $edit_cat;
  my %codehash;
  my $box = $mw->DialogBox(-title=>"Choose a category to edit", -buttons=>["Ok","Cancel"]);
  $box->Icon(-image=>$icon);
  $box->add("Label",-text=>"You may currently edit the long name,\nbut not the code, of a category.\n\nChoose the category to edit below.")->pack(); 
  my $query="SELECT * from categories ORDER BY description";
  my $sth=$dbh->prepare($query);
  $sth->execute or die "can't execute the query: $DBI::errstr\n";
  while (@table_row = $sth->fetchrow_array)
  {
    my $code=$table_row[0];
    my $name=$table_row[1];
    $codehash{$code} = $name;
    $box->add("Radiobutton",-text=>$name,
                            -value=>$code,
                            -variable=>\$edit_cat)->pack(-anchor=>"w");
  }
  $sth->finish;
  my $choice = $box->Show();

  if ($choice ne "Cancel")
  {
    # Throw up another dialog box to do the actual editing
    my $editbox = $mw->DialogBox(-title=>"Edit a category", -buttons=>["Ok","Cancel"]);
    $editbox->Icon(-image=>$icon);
    $editbox->add("Label",-text=>"Edit the long name of the category: $codehash{$edit_cat}.")->pack(); 
    my $new_desc = $codehash{$edit_cat};
    $editbox->add("Label",-text=>"CODE: $edit_cat", -anchor=>'w')->pack(-fill=>'x', -expand=>1);
    my $labelframe = $editbox->add("Frame")->pack(-fill=>'x');
    $labelframe->Label(-text=>"New Description: ")->pack(-side=>'left');
    $labelframe->Entry(-width=>25,
                       -textvariable=>\$new_desc)->pack(-side=>'left');
    my $editchoice = $editbox->Show();

    if ($editchoice ne "Cancel")
    {
      $query = "UPDATE categories SET description='$new_desc' WHERE code='$edit_cat'";
      $sth=$dbh->prepare($query);
      if (! $sth->execute)
      {
        my $error_message = $sth->errstr();
        infobox($mw, "Database Error","Database returned error: $error_message\n
on query $query");
      }
      else
      {
        $status = "Edited category: $new_desc";
        infobox($mw,"Success","Category edited.");
      }
      $sth->finish;
    }
  }
}

sub delete_category
{
  my $box = $mw->DialogBox(-title=>"Delete a category",-buttons=>["Ok","Cancel"]);
  $box->Icon(-image=>$icon);
  $box->add("Label",-text=>"Choose a category to delete.")->pack();

  my $query="SELECT * from categories ORDER BY description";
  my $sth=$dbh->prepare($query);
  $sth->execute or die "can't execute the query: $DBI::errstr\n";
  while (@table_row = $sth->fetchrow_array)
  {
    $code=$table_row[0];
    $name=$table_row[1];
    $box->add("Radiobutton",-text=>$name,
                            -value=>$code,
                            -variable=>\$del_cat)->pack(-anchor=>"w");
  }
  $sth->finish;
  my $choice = $box->Show();
  
  if ($choice ne "Cancel")
  {
    $query = "SELECT * FROM mrvoice WHERE category='$del_cat'";
    my $sth=$dbh->prepare($query);
    $sth->execute;
    $rows = $sth->rows;
    $sth->finish;
    if ($rows > 0)
    {
      infobox($mw, "Error","Could not delete category $del_cat because\nthere are still entries in the database\nusing it.  Delete all entries using\nthis category before deleting the category");
      $status = "Category not deleted";
    }
    else
    {
      $query = "DELETE FROM categories WHERE code='$del_cat'";
      my $sth=$dbh->prepare($query);
      if ($sth->execute)
      {
        $status = "Deleted category $del_cat";
        infobox ($mw, "Success","Category $del_cat has been deleted.");
      }
      $sth->finish;
    }
  }
  else
  {
    $status = "Category deletion cancelled";
  }

  $del_cat="";
}

sub add_new_song
{
  my $continue = 0;
  while ($continue != 1)
  {
    $box = $mw->DialogBox(-title=>"Add New Song", -buttons=>["OK","Cancel"]);
    $box->bind("<Key-Escape>", [\&stop_mp3]);
    $box->Icon(-image=>$icon);
    $box->add("Label",-text=>"Enter the following information for the new song,\nand choose the file to add.")->pack();
    $box->add("Label",-text=>"Items in red are required.\n")->pack();
    $frame1 = $box->add("Frame")->pack(-fill=>'x');
    $frame1->Label(-text=>"Song Title",
                   -foreground=>"#cdd226132613")->pack(-side=>'left');
    $frame1->Entry(-width=>30,
                   -textvariable=>\$addsong_title)->pack(-side=>'right');
    $frame2 = $box->add("Frame")->pack(-fill=>'x');
    $frame2->Label(-text=>"Artist")->pack(-side=>'left');
    $frame2->Entry(-width=>30,
                   -textvariable=>\$addsong_artist)->pack(-side=>'right');
    $frame3 = $box->add("Frame")->pack(-fill=>'x');
    $frame3->Label(-text=>"Category",
                   -foreground=>"#cdd226132613")->pack(-side=>'left');
    $menu=$frame3->Menubutton(-text=>"Choose Category",
                              -relief=>'raised',
                              -tearoff=>0,
                              -indicatoron=>1)->pack(-side=>'right');
    $query="SELECT * from categories ORDER BY description";
    my $sth=$dbh->prepare($query);
    $sth->execute or die "can't execute the query: $DBI::errstr\n";
    while (@table_row = $sth->fetchrow_array)
    {
      $code=$table_row[0];
      $name=$table_row[1];
      $menu->radiobutton(-label=>$name,
                         -value=>$code,
                         -variable=>\$addsong_cat);
    }
    $sth->finish;
    $frame4 = $box->add("Frame")->pack(-fill=>'x');
    $frame4->Label(-text=>"Category Extra Info")->pack(-side=>'left');
    $frame4->Entry(-width=>30,
                   -textvariable=>\$addsong_info)->pack(-side=>'right');
    $frame5 = $box->add("Frame")->pack(-fill=>'x');
    $frame5->Label(-text=>"File to add",
                   -foreground=>"#cdd226132613")->pack(-side=>'left');
    $frame6 = $box->add("Frame")->pack(-fill=>'x');
    $frame6->Button(-text=>"Select File",
                    -command=>sub { 
      $addsong_filename = $mw->getOpenFile(-title=>'Select File',
                                           -filetypes=>$mp3types);
      if ($addsong_filename =~ /.mp3$/i)
      {
        $addsong_filename = Win32::GetShortPathName($addsong_filename) if ($^O eq "MSWin32");
        my $tag = get_mp3tag($addsong_filename);
        $addsong_title = $tag->{TITLE};
        $addsong_artist = $tag->{ARTIST};
      }
      elsif ( ($addsong_filename =~ /.ogg/i) && ($^O ne "MSWin32") )
      {
        my $ogg = Ogg::Vorbis->new;
        open (INPUT,$addsong_filename) or die;
        $ogg->open(INPUT);
        %comments = %{$ogg->comment};
        $addsong_title = $comments{title};
        $addsong_artist = $comments{artist};
        close (INPUT);
      }
                                  })->pack(-side=>'right');
    $songentry = $frame5->Entry(-width=>30,
                   -textvariable=>\$addsong_filename)->pack(-side=>'right');
    $frame7 = $box->add("Frame")->pack(-fill=>'x');
    $frame7->Button(-text=>"Preview song",
#                    -command=>[\&play_mp3, "addsong", $songentry->cget(-textvariable)])->pack(-side=>'right');
                    -command=> sub {  my $tmpsong = $songentry->cget(-textvariable); play_mp3("addsong",$$tmpsong);})->pack(-side=>'right');

    $result = $box->Show();
  
    if ($result eq "OK")
    {
      if (! $addsong_cat)
      {
        infobox($mw, "Error","Could not add new song\n\nYou must choose a category");
      }
      elsif (! -r $addsong_filename)
      {
        infobox ($mw, "File Error","Could not open input file $addsong_filename\nfor reading.  Check file permissions"); 
      }
      elsif (! $addsong_title)
      {
        infobox ($mw, "File Error","You must provide the title for the song."); 
      }
      elsif (! -w $filepath)
      {
        infobox ($mw, "File Error","Could not write file to directory $filepath\nPlease check the permissions");
      }
      else
      {
        $continue = 1;
      }
    }
    else
    {
      $status = "Cancelled song add";
      $addsong_title="";
      $addsong_artist="";
      $addsong_info="";
      $addsong_cat="";
      $addsong_filename="";
      return (1);
    }
  } # End while continue loop
  if ($addsong_artist)
  {
    $newfilename = "$addsong_artist-$addsong_title";
  }
  else
  {
    $newfilename = $addsong_title;
  }
  $newfilename =~ s/[^a-zA-Z0-9\-]//g;

  our $path; # Only mentioned once
  ($name,$path,$extension) = fileparse($addsong_filename,'\.\w+');
  $extension=lc($extension);

  if ( -e "$filepath$newfilename$extension")
  {
    $i=0;
    while (1 == 1)
    {
      if (! -e "$filepath$newfilename-$i$extension")
      {
        $newfilename = "$newfilename-$i";
        last;
      }
      $i++;
    }
  }
  $newfilename = "$newfilename$extension";
  $addsong_title = $dbh->quote($addsong_title);
  if ($addsong_info eq "")
  {
    $addsong_info = "NULL";
  }
  else
  {
    $addsong_info = $dbh->quote($addsong_info);
  }
  if ($addsong_artist eq "")
  {
    $addsong_artist = "NULL";
  }
  else
  {
    $addsong_artist = $dbh->quote($addsong_artist);
  }
  $time = get_songlength($addsong_filename);
  $query = "INSERT INTO mrvoice VALUES (NULL,$addsong_title,$addsong_artist,'$addsong_cat',$addsong_info,'$newfilename','$time',NULL)";
  copy ($addsong_filename,"$filepath$newfilename");
  if ($dbh->do($query))
  {
    $addsong_filename = Win32::GetLongPathName($addsong_filename) if ($^O eq "MSWin32");
    infobox ($mw, "File Added Successfully","Successfully added new song into database.\n\nYou may now delete/move/etc. the file:\n$addsong_filename\nas it is no longer needed by Mr. Voice");
    $status = "File added";
  }
  else
  {
    infobox ($mw, "Error","Could not add song into database");
    $status = "File add exited on database error";
  }
  $addsong_title="";
  $addsong_artist="";
  $addsong_info="";
  $addsong_cat="";
  $addsong_filename="";
}

sub edit_preferences
{
  my $box = $mw->DialogBox(-title=>"Edit Preferences",
                           -buttons=>["Ok","Cancel"],
                           -default_button=>"Ok");
  $box->Icon(-image=>$icon);
  my $notebook = $box->add('NoteBook', -ipadx=>6, -ipady=>6);
  my $database_page = $notebook->add("database", 
                                     -label=>"Database Options", 
				     -underline=>0);
  my $filepath_page = $notebook->add("filepath",
                                     -label=>"File Paths",
				     -underline=>0);
  my $other_page = $notebook->add("other",
                                  -label=>"Other",
				  -underline=>0);

  my $db_name_frame = $database_page->Frame()->pack(-fill=>'x');
  $db_name_frame->Label(-text=>"Database Name")->pack(-side=>'left');
  $db_name_frame->Entry(-width=>30,
	                -textvariable=>\$db_name)->pack(-side=>'right');

  my $db_user_frame = $database_page->Frame()->pack(-fill=>'x');
  $db_user_frame->Label(-text=>"Database Username")->pack(-side=>'left');
  $db_user_frame->Entry(-width=>30,
	                -textvariable=>\$db_username)->pack(-side=>'right');

  my $db_pass_frame = $database_page->Frame()->pack(-fill=>'x');
  $db_pass_frame->Label(-text=>"Database Password")->pack(-side=>'left');
  $db_pass_frame->Entry(-width=>30,
	                -textvariable=>\$db_pass)->pack(-side=>'right');

  my $mp3dir_frame = $filepath_page->Frame()->pack(-fill=>'x');
  $mp3dir_frame->Label(-text=>"MP3 Directory")->pack(-side=>'left');
  $mp3dir_frame->Entry(-width=>30,
	               -textvariable=>\$filepath)->pack(-side=>'right');

  my $hotkeydir_frame = $filepath_page->Frame()->pack(-fill=>'x');
  $hotkeydir_frame->Label(-text=>"Hotkey Save Directory")->pack(-side=>'left');
  $hotkeydir_frame->Entry(-width=>30,
	                  -textvariable=>\$savedir)->pack(-side=>'right');

  my $mp3frame = $other_page->Frame()->pack(-fill=>'x');
  $mp3frame->Label(-text=>"MP3 Player")->pack(-side=>'left');
  $mp3frame->Button(-text=>"Choose",
                  -command=>sub { 
                     $mp3player = $mw->getOpenFile(-title=>'Select File');
                                })->pack(-side=>'right');
  $mp3frame->Entry(-width=>30,
                 -textvariable=>\$mp3player)->pack(-side=>'right'); 

  my $numdyn_frame = $other_page->Frame()->pack(-fill=>'x');
  $numdyn_frame->Label(-text=>"Number of Dynamic Documents To Show")->pack(-side=>'left');
  $numdyn_frame->Entry(-width=>2,
                 -textvariable=>\$savefile_max)->pack(-side=>'right');

  my $httpq_frame = $other_page->Frame()->pack(-fill=>'x');
  $httpq_frame->Label(-text=>"httpQ Password (WinAmp only, optional)")->pack(-side=>'left');
  $httpq_frame->Entry(-width=>8,
                      -textvariable=>\$httpq_pw)->pack(-side=>'right');

  $notebook->pack(-expand=>"yes",
                  -fill=>"both",
		  -padx=>5,
		  -pady=>5,
		  -side=>"top");
  my $result = $box->Show();

  if ($result eq "Ok")
  {
    if ( (! $db_name) || (! $db_username) || (! $db_pass) || (! $filepath) || (! $savedir) || (! $mp3player) )
    {
      infobox($mw, "Warning","All fields must be filled in\n");
      edit_preferences();
    }
    if (! open(RCFILE,">$rcfile"))
    {
      infobox($mw, "Warning","Could not open $rcfile for writing.\nYour preferences will not be saved\n");
    }
    else
    {
      print RCFILE "db_name::$db_name\n";
      print RCFILE "db_username::$db_username\n";
      print RCFILE "db_pass::$db_pass\n";
      print RCFILE "filepath::$filepath\n";
      print RCFILE "savedir::$savedir\n";
      print RCFILE "mp3player::$mp3player\n";
      print RCFILE "savefile_max::$savefile_max\n";
      print RCFILE "httpq_pw::$httpq_pw\n";
      close(RCFILE);
    }
  }
  read_rcfile();
}

sub edit_song
{
  my $id = get_song_id($mainbox);
  $query = "SELECT title,artist,category,info from mrvoice where id=$id";
  ($edit_title,$edit_artist,$edit_category,$edit_info) = $dbh->selectrow_array($query);

  $box = $mw->DialogBox(-title=>"Edit Song", -buttons=>["Edit","Cancel"],
                                             -default_button=>"Edit");
  $box->Icon(-image=>$icon);
  $box->add("Label",-text=>"You may use this form to modify information about\na song that is already in the database\n")->pack();
  $frame1 = $box->add("Frame")->pack(-fill=>'x');
  $frame1->Label(-text=>"Song Title")->pack(-side=>'left');
  $frame1->Entry(-width=>30,
                 -textvariable=>\$edit_title)->pack(-side=>'right');
  $frame2 = $box->add("Frame")->pack(-fill=>'x');
  $frame2->Label(-text=>"Artist")->pack(-side=>'left');
  $frame2->Entry(-width=>30,
                 -textvariable=>\$edit_artist)->pack(-side=>'right');
  $frame3 = $box->add("Frame")->pack(-fill=>'x');
  $frame3->Label(-text=>"Category")->pack(-side=>'left');
  $menu=$frame3->Menubutton(-text=>"Choose Category",
                            -relief=>'raised',
                            -tearoff=>0,
                            -indicatoron=>1)->pack(-side=>'right');
    $query="SELECT * from categories ORDER BY description";
    my $sth=$dbh->prepare($query);
    $sth->execute or die "can't execute the query: $DBI::errstr\n";
    while (@table_row = $sth->fetchrow_array)
    {
      $code=$table_row[0];
      $name=$table_row[1];
      $menu->radiobutton(-label=>$name,
                         -value=>$code,
                         -variable=>\$edit_category);
    }
    $sth->finish;

  $frame4 = $box->add("Frame")->pack(-fill=>'x');
  $frame4->Label(-text=>"Extra Info")->pack(-side=>'left');
  $frame4->Entry(-width=>30,
                 -textvariable=>\$edit_info)->pack(-side=>'right');
  $result = $box->Show();

  if ($result eq "Edit")
  {
    $edit_artist = $dbh->quote($edit_artist);
    $edit_title = $dbh->quote($edit_title);
    $edit_info = $dbh->quote($edit_info);
    $query = "UPDATE mrvoice SET artist=$edit_artist, title=$edit_title, info=$edit_info, category='$edit_category' WHERE id=$id";
    if ($dbh->do($query))
    {
      infobox ($mw, "Song Edited Successfully","The song was edited successfully.");
      $status = "Edited song";
    }
    else
    {
      infobox ($mw, "Error","There was an error editing the song.\nNo changes made.");
      $status = "Error editing song - no changes made";
    }
  }
  else
  {
    $status = "Cancelled song edit.";
  }

  $edit_title="";
  $edit_artist="";
  $edit_category="";
  $edit_info="";
}

sub delete_song
{
  my $id = get_song_id($mainbox);
  if ($id)
  {  
    $box = $mw->DialogBox(-title=>"Confirm Deletion", 
                          -default_button=>"Cancel",
                          -buttons=>["Delete","Cancel"]);
    $box->Icon(-image=>$icon);
    $box->add("Label",-text=>"About to delete song id $id from the database\nBe sure this is what you want to do!")->pack();
    $box->add("Checkbutton",-text=>"Delete file on disk",
                            -variable=>\$delete_file_cb)->pack();
    $result = $box->Show();
    if ($result eq "Delete")
    {
      if ($delete_file_cb == 1)
      {
        $filequery = "SELECT filename FROM mrvoice WHERE id=$id";
        ($filename) = $dbh->selectrow_array($filequery);
      }
      $query = "DELETE FROM mrvoice WHERE id=$id";
      my $sth=$dbh->prepare($query);
      $sth->execute;
      $sth->finish;
      if ($delete_file_cb == 1)
      {
        infobox($mw, "File Deletion Error","Could not delete file $filepath$filename from the disk\n\nEntry was removed from the database") unless ( unlink("$filepath$filename") );
      }
      infobox($mw, "Song Deleted","Deleted song with ID $id");
      $status = "Deleted song id $id";
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
  $delete_file_cb = 0;
}

sub show_about
{
  $rev = '$Revision: 1.188 $';
  $rev =~ s/.*(\d+\.\d+).*/$1/;
  my $string = "Mr. Voice Version $version (Revision: $rev)\n\nBy H. Wade Minter <minter\@lunenburg.org>\n\nURL: http://www.lunenburg.org/mrvoice/\n\n(c)2001, Released under the GNU General Public License";
  my $box = $mw->DialogBox(-title=>"About Mr. Voice", 
                           -buttons=>["OK"],
                           -background=>'white');
  $logo_photo = $mw->Photo(-data=>$logo_photo_data);
  $box->Icon(-image=>$icon);
  $box->add("Label",-image=>$logo_photo,
                    -background=>'white')->pack();
  $box->add("Label",-text=>"$string",
                    -background=>'white')->pack();
  $box->Show;
}

#STARTCSZ
#sub show_predefined_hotkeys
#{
#  $box = $mw->DialogBox(-title=>"Predefined Hotkeys", -buttons=>["Close"]);
#  $box->Icon(-image=>$icon);
#  $box->add("Label",-text=>"The following hotkeys are always available\nand may not be changed")->pack();
#  $box->add("Label",-text=>"<Escape> - Stop the currently playing MP3",-anchor=>'nw')->pack(-fill=>'x');
#  $box->add("Label",-text=>"<Control-P> - Play the currently selected song",-anchor=>'nw')->pack(-fill=>'x');
#  $box->add("Label",-text=>"<Enter> - Perform the currently entered search",-anchor=>'nw')->pack(-fill=>'x');
#  $box->add("Label",-text=>"<ALT-t> - The \"Ta-Da\" MIDI",-anchor=>'nw')->pack(-fill=>'x');
#  $box->add("Label",-text=>"<ALT-y> - The \"You're Out\" MIDI",-anchor=>'nw')->pack(-fill=>'x');
#  $box->add("Label",-text=>"<ALT-b> - The Brown Bag MIDI",-anchor=>'nw')->pack(-fill=>'x');
#  $box->add("Label",-text=>"<ALT-g> - The Groaner MIDI",-anchor=>'nw')->pack(-fill=>'x');
#  $box->add("Label",-text=>"<ALT-v> - The Price Is Right theme (Volunteer photos)",-anchor=>'nw')->pack(-fill=>'x');
#  $box->Show;
#}
#ENDCSZ

sub clear_hotkeys
{
  # Backs up the hotkeys, then deletes all of them.

  backup_hotkeys();
  $f1="";
  $f2="";
  $f3="";
  $f4="";
  $f5="";
  $f6="";
  $f7="";
  $f8="";
  $f9="";
  $f10="";
  $f11="";
  $f12="";
  $status = "All hotkeys cleared";
}

sub clear_selected
{
  # If a hotkey has its checkbox activated, then that hotkey will have
  # its entry cleared.  Then all checkboxes are unselected.

  $f1="" if ($f1_cb);
  $f2="" if ($f2_cb);
  $f3="" if ($f3_cb);
  $f4="" if ($f4_cb);
  $f5="" if ($f5_cb);
  $f6="" if ($f6_cb);
  $f7="" if ($f7_cb);
  $f8="" if ($f8_cb);
  $f9="" if ($f9_cb);
  $f10="" if ($f10_cb);
  $f11="" if ($f11_cb);
  $f12="" if ($f12_cb);
  $f1_cb=0;
  $f2_cb=0;
  $f3_cb=0;
  $f4_cb=0;
  $f5_cb=0;
  $f6_cb=0;
  $f7_cb=0;
  $f8_cb=0;
  $f9_cb=0;
  $f10_cb=0;
  $f11_cb=0;
  $f12_cb=0;
  $status="Selected hotkeys cleared";
}

sub holding_tank
{
  if (Exists($holdingtank))
  {
    # Only once copy on the screen at a time
    return;
  }
  $holdingtank = $mw->Toplevel();
  $holdingtank->withdraw();
  $holdingtank->Icon(-image=>$icon);
  bind_hotkeys($holdingtank);              
  $holdingtank->bind("<Control-Key-p>", [\&play_mp3,"Holding"]);
  $holdingtank->title("Holding Tank");
  $holdingtank->Label(-text=>"A place to store songs for later use")->pack;
  $holdingtank->Label(-text=>"Drag a song here from the main search box to store it")->pack;
  $tankbox = $holdingtank->Scrolled('Listbox',
                         -scrollbars=>'osoe',
			 -width=>50,
			 -setgrid=>1,
			 -selectmode=>'extended')->pack(-fill=>'both',
			                              -expand=>1,
						      -padx=>10,
						      -side=>'top');
  $tankbox->DropSite(-droptypes=>['Local'],
                     -dropcommand=>[\&Tank_Drop, $dnd_token ]);
  $tankbox->bind("<Double-Button-1>", \&play_mp3);
#  $tankbox->bind("<Control-Key-p>", [\&play_mp3, "Holding"]);
  &BindMouseWheel($tankbox);
  my $buttonframe = $holdingtank->Frame()->pack(-side=>'bottom',
                                             -fill=>'x');
  my $playbutton = $buttonframe->Button(-text=>"Play Now",
                                        -command=>[\&play_mp3,$tankbox])->pack(-side=>'left');
  $playbutton->configure(-bg=>'green',
                       -activebackground=>'SpringGreen2');
  my $stopbutton = $buttonframe->Button(-text=>"Stop Now",
                                        -command=>\&stop_mp3)->pack(-side=>'left');
  $stopbutton->configure(-bg=>'red',
                       -activebackground=>'tomato3');
  $buttonframe->Button(-text=>"Close",
                       -command=>sub {$holdingtank->destroy})->pack(-side=>'right');
  $buttonframe->Button(-text=>"Clear Selected",
                       -command=>\&clear_tank)->pack(-side=>'right');
  $holdingtank->update();
  $holdingtank->deiconify();
  $holdingtank->raise();
}

sub clear_tank
{
  @selected = reverse($tankbox->curselection());
  foreach $item (@selected)
  {
    $tankbox->delete($item);
  }
}
  
sub list_hotkeys
{
  if (!Exists($hotkeysbox))
  {
    $hotkeysbox=$mw->Toplevel();
    $hotkeysbox->withdraw();
    $hotkeysbox->Icon(-image=>$icon);
    bind_hotkeys($hotkeysbox);
    $hotkeysbox->bind("<Control-Key-p>", [\&play_mp3,"Current"]);
    $hotkeysbox->title("Hotkeys");
    $hotkeysbox->Label(-text=>"Currently defined hotkeys:")->pack;
    my $f1_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
    $f1_frame->Checkbutton(-text=>"F1: ",
                           -variable=>\$f1_cb)->pack(-side=>'left');
    $f1_frame->Label(-textvariable=>\$f1, 
                     -anchor=>'w')->pack(-side=>'left');
    $f1_frame->DropSite(-droptypes=>['Local'],
                        -dropcommand=>[\&Hotkey_Drop, \$f1, $dnd_token ]);
    my $f2_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
    $f2_frame->Checkbutton(-text=>"F2: ",
                           -variable=>\$f2_cb)->pack(-side=>'left');
    $f2_frame->Label(-textvariable=>\$f2,
                     -anchor=>'w')->pack(-side=>'left');
    $f2_frame->DropSite(-droptypes=>['Local'],
                        -dropcommand=>[\&Hotkey_Drop, \$f2, $dnd_token ]);
    my $f3_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
    $f3_frame->Checkbutton(-text=>"F3: ",
                           -variable=>\$f3_cb)->pack(-side=>'left');
    $f3_frame->Label(-textvariable=>\$f3,
                     -anchor=>'w')->pack(-side=>'left');
    $f3_frame->DropSite(-droptypes=>['Local'],
                        -dropcommand=>[\&Hotkey_Drop, \$f3, $dnd_token ]);
    my $f4_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
    $f4_frame->Checkbutton(-text=>"F4: ",
                           -variable=>\$f4_cb)->pack(-side=>'left');
    $f4_frame->Label(-textvariable=>\$f4,
                     -anchor=>'w')->pack(-side=>'left');
    $f4_frame->DropSite(-droptypes=>['Local'],
                        -dropcommand=>[\&Hotkey_Drop, \$f4, $dnd_token ]);
    my $f5_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
    $f5_frame->Checkbutton(-text=>"F5: ",
                           -variable=>\$f5_cb)->pack(-side=>'left');
    $f5_frame->Label(-textvariable=>\$f5,
                     -anchor=>'w')->pack(-side=>'left');
    $f5_frame->DropSite(-droptypes=>['Local'],
                        -dropcommand=>[\&Hotkey_Drop, \$f5, $dnd_token ]);
    my $f6_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
    $f6_frame->Checkbutton(-text=>"F6: ",
                           -variable=>\$f6_cb)->pack(-side=>'left');
    $f6_frame->Label(-textvariable=>\$f6,
                     -anchor=>'w')->pack(-side=>'left');
    $f6_frame->DropSite(-droptypes=>['Local'],
                        -dropcommand=>[\&Hotkey_Drop, \$f6, $dnd_token ]);
    my $f7_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
    $f7_frame->Checkbutton(-text=>"F7: ",
                           -variable=>\$f7_cb)->pack(-side=>'left');
    $f7_frame->Label(-textvariable=>\$f7,
                     -anchor=>'w')->pack(-side=>'left');
    $f7_frame->DropSite(-droptypes=>['Local'],
                        -dropcommand=>[\&Hotkey_Drop, \$f7, $dnd_token ]);
    my $f8_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
    $f8_frame->Checkbutton(-text=>"F8: ",
                           -variable=>\$f8_cb)->pack(-side=>'left');
    $f8_frame->Label(-textvariable=>\$f8,
                     -anchor=>'w')->pack(-side=>'left');
    $f8_frame->DropSite(-droptypes=>['Local'],
                        -dropcommand=>[\&Hotkey_Drop, \$f8, $dnd_token ]);
    my $f9_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
    $f9_frame->Checkbutton(-text=>"F9: ",
                           -variable=>\$f9_cb)->pack(-side=>'left');
    $f9_frame->Label(-textvariable=>\$f9,
                     -anchor=>'w')->pack(-side=>'left');
    $f9_frame->DropSite(-droptypes=>['Local'],
                        -dropcommand=>[\&Hotkey_Drop, \$f9, $dnd_token ]);
    my $f10_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
    $f10_frame->Checkbutton(-text=>"F10:",
                            -variable=>\$f10_cb)->pack(-side=>'left');
    $f10_frame->Label(-textvariable=>\$f10,
                      -anchor=>'w')->pack(-side=>'left');
    $f10_frame->DropSite(-droptypes=>['Local'],
                         -dropcommand=>[\&Hotkey_Drop, \$f10, $dnd_token ]);
    my $f11_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
    $f11_frame->Checkbutton(-text=>"F11:",
                            -variable=>\$f11_cb)->pack(-side=>'left');
    $f11_frame->Label(-textvariable=>\$f11,
                      -anchor=>'w')->pack(-side=>'left');
    $f11_frame->DropSite(-droptypes=>['Local'],
                         -dropcommand=>[\&Hotkey_Drop, \$f11, $dnd_token ]);
    my $f12_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
    $f12_frame->Checkbutton(-text=>"F12:",
                            -variable=>\$f12_cb)->pack(-side=>'left');
    $f12_frame->Label(-textvariable=>\$f12,
                      -anchor=>'w')->pack(-side=>'left');
    $f12_frame->DropSite(-droptypes=>['Local'],
                         -dropcommand=>[\&Hotkey_Drop, \$f12, $dnd_token ]);
    my $buttonframe = $hotkeysbox->Frame()->pack(-side=>'bottom',
                                                 -fill=>'x');
    $buttonframe->Button(-text=>"Close",
                         -command=>sub { $hotkeysbox->withdraw})->pack(-side=>'left');
    $buttonframe->Button(-text=>"Clear Selected",
                         -command=>\&clear_selected)->pack(-side=>'right');
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
  # This gets the current selection from the search results box, and returns
  # the database ID for that song.

  $box = $_[0];
  # When playing a song, we only take the first index, even if
  # multiple selections are allowed
  my @index = $box->curselection();
  my $selection = $box->get($index[0]);
  my ($id) = split /:/,$selection;
  return ($id);
}

sub update_time
{
  $mw->Busy(-recurse=>1);
  my $count = 0;
  my $query = "SELECT id,filename,time FROM mrvoice";
  my $sth=$dbh->prepare($query);
  $sth->execute;
  while (@table_row = $sth->fetchrow_array)
  {
    ($id,$filename,$time) = @table_row;
    $newtime = get_songlength("$filepath/$filename");
    if ($newtime ne $time)
    {
      $query = "UPDATE mrvoice SET time='$newtime' WHERE id='$id'";
      my $sth=$dbh->prepare($query);
      $sth->execute;
      $sth->finish;
      $count++;
    }
  }
  $mw->Unbusy(-recurse=>1);
  $box = $mw->DialogBox(-title=>"Updating Song Times", -buttons=>["Ok"]);
  $box->Icon(-image=>$icon);
  $box->add("Label",-text=>"Updated times on $count files")->pack();
  $box->Show();
}    
  
sub get_filename
{
  # Takes a database ID as an argument, queries the database, and returns
  # the MP3 filename for that song.

  my $id = $_[0];
  my $query = "SELECT filename FROM mrvoice WHERE id=$id";
  my $sth=$dbh->prepare($query);
  $sth->execute or die "can't execute the query: $DBI::errstr\n";
  @result = $sth->fetchrow_array;
  $sth->finish;
  my $filename = $result[0];
  return ($filename);
}

sub stop_mp3
{
  # Sends a stop command to the MP3 player.  Works for both xmms and WinAmp,
  # though not particularly cleanly.

  system ("$mp3player --stop");
  $status = "Playing Stopped";
}

sub play_mp3 
{
  # See if the request is coming from one our hotkeys first...
  if ( ($_[1] ) && ( ($_[1] =~ /^F.*/) || ($_[1] =~ /^ALT.*/) ) )
  {
    if ($_[1] eq "F1") { $filename = $f1; }
    elsif ($_[1] eq "F2") { $filename = $f2; }
    elsif ($_[1] eq "F3") { $filename = $f3; }
    elsif ($_[1] eq "F4") { $filename = $f4; }
    elsif ($_[1] eq "F5") { $filename = $f5; }
    elsif ($_[1] eq "F6") { $filename = $f6; }
    elsif ($_[1] eq "F7") { $filename = $f7; }
    elsif ($_[1] eq "F8") { $filename = $f8; }
    elsif ($_[1] eq "F9") { $filename = $f9; }
    elsif ($_[1] eq "F10") { $filename = $f10; }
    elsif ($_[1] eq "F11") { $filename = $f11; }
    elsif ($_[1] eq "F12") { $filename = $f12; }
  #STARTCSZ
  #  elsif ($_[1] eq "ALT-T") { $filename = $altt; }
  #  elsif ($_[1] eq "ALT-Y") { $filename = $alty; }
  #  elsif ($_[1] eq "ALT-B") { $filename = $altb; }
  #  elsif ($_[1] eq "ALT-G") { $filename = $altg; }
  #  elsif ($_[1] eq "ALT-V") { $filename = $altv; }
  #ENDCSZ
  }
  elsif ($_[0] eq "addsong")
  {
    # if we're playin from the "add new song dialog, the full path
    # will already be set.
    $filename = $_[1];
    if ($^O eq "MSWin32")
    {
      $filename = Win32::GetShortPathName($filename);
    }
  }
  else
  {
    if ( ($_[1]) && ($_[1] eq "Current") )
    {
      $box = $mainbox;
    }
    elsif ( ($_[1]) && ($_[1] eq "Holding") )
    {
      $box = $tankbox;
    }
    else
    {
      $box = $_[0];
    }
    my $id = get_song_id($box);
    if ($id)
    {
      $query = "SELECT filename,title,artist from mrvoice WHERE id=$id";
      my $sth=$dbh->prepare($query);
      $sth->execute or die "can't execute the query: $DBI::errstr\n";
      @result = $sth->fetchrow_array;
      $sth->finish;
      $filename = $result[0];
      $statustitle = $result[1];
      $statusartist = $result[2];
    }
  }
  if ( ($filename) && ($_[0] eq "addsong") )
  {
    $status = "Previewing file $filename";
    system ("$mp3player $filename");
  }
  elsif ($filename)
  {
    if ($_[1] =~ /^F.*/)
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
    system ("$mp3player $filepath$filename");
    $statustitle = "";
    $statusartist = "";
  }
}

sub get_songlength
{
  #Generic function to return the length of a song in mm:ss format.
  #Currently supports MP3 and WAV, with the appropriate modules.

  $file = $_[0];
  my $time = "";
  if ($file =~ /.*\.mp3$/i)
  {
    # It's an MP3 file
    my $info = get_mp3info("$file");
    $minute = $info->{MM};
    $minute = "0$minute" if ($minute < 10);
    $second = $info->{SS};
    $second = "0$second" if ($second < 10);
    $time = "[$minute:$second]";
  }
  elsif ($file =~ /\.wav$/i)
  {
    # It's a WAV file
    my $wav = new Audio::Wav;
    my $read = $wav -> read( "$file" );
    my $audio_seconds = int ( $read -> length_seconds() );
    $minute = int ($audio_seconds / 60);
    $minute = "0$minute" if ($minute < 10);
    $second = $audio_seconds % 60;
    $second = "0$second" if ($second < 10);
    $time = "[$minute:$second]";
  }
  elsif ( ($file =~ /\.ogg$/i) && ($^O eq "linux") )
  {
    #It's an Ogg Vorbis file.  No Ogg Vorbis module for Windows yet.
    my $ogg = Ogg::Vorbis->new;
    open (OGG_IN,$file);
    $ogg->open(OGG_IN);
    my $audio_seconds = $ogg->time_total;
    $minute = int($audio_seconds / 60);
    $minute = "0$minute" if ($minute < 10);
    $second = $audio_seconds % 60;
    $second = "0$second" if ($second < 10);
    $time = "[$minute:$second]";
    close (OGG_IN);
  }
  elsif ( ($file =~ /\.m3u$/i) || ($file =~ /\.pls$/i) )
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
  if ( ($_[0]) && ($_[0] eq "timespan") )
  {
    $date = DateCalc("today","- $_[1]"); 
    $date =~ /^(\d{4})(\d{2})(\d{2}).*?/;
    $year = $1;
    $month = $2;
    $date = $3;
    $datestring = "$year-$month-$date";
  }
  elsif ( ($_[0]) && ($_[0] eq "range") )
  {
    $startdate = $_[1];
    $enddate = $_[2];
  }
  if ($anyfield)
  {
    $anyfield_box->insert(0,$anyfield);
    $anyfield =~ s/^\s*(.*?)\s*$/$1/;
  }
  if ($title)
  {
    $title_box->insert(0,$title);
    $title =~ s/^\s*(.*?)\s*$/$1/;
  }
  if ($artist)
  {
    $artist_box->insert(0,$artist);
    $artist =~ s/^\s*(.*?)\s*$/$1/;
  }
  if ($cattext)
  {
    $cattext_box->insert(0,$cattext);
    $cattext =~ s/^\s*(.*?)\s*$/$1/;
  }
  $status="Starting search...";
  $mw->Busy(-recurse=>1);
  $mainbox->delete(0,'end');
  my $query = "SELECT mrvoice.id,categories.description,mrvoice.info,mrvoice.artist,mrvoice.title,mrvoice.filename,mrvoice.time from mrvoice,categories where mrvoice.category=categories.code ";
  $query = $query . "AND modtime >= '$datestring'" if ( ($_[0]) && ($_[0] eq "timespan"));
  $query = $query . "AND modtime >= '$startdate' AND modtime <= '$enddate'" if (($_[0]) && ($_[0] eq "range"));
  $query = $query . "AND category='$category' " if ($category ne "Any");
  if ($anyfield)
  {
    $query = $query . "AND ( info LIKE '%$anyfield%' OR title LIKE '%$anyfield%' OR artist LIKE '%$anyfield%') ";
  }
  else
  {
    $query = $query . "AND info LIKE '%$cattext%' " if ($cattext);
    $query = $query . "AND title LIKE '%$title%' " if ($title);
    $query = $query . "AND artist LIKE '%$artist%' " if ($artist);
  }
  $query = $query . "ORDER BY category,info,title";
  my $starttime = timelocal(localtime());
  my $sth=$dbh->prepare($query);
  $sth->execute or die "can't execute the query: $DBI::errstr\n";
  $numrows = $sth->rows;
  while (@table_row = $sth->fetchrow_array)
  {
    if (-e "$filepath$table_row[5]")
    {
      $string="$table_row[0]:($table_row[1]";
      $string = $string . " - $table_row[2]" if ($table_row[2]);
      $string = $string . ") - \"$table_row[4]\"";
      $string = $string. " by $table_row[3]" if ($table_row[3]);
      #my $songstring = get_songlength("$filepath$table_row[5]");
      $string = $string . " $table_row[6]";
      $mainbox->insert('end',$string); 
    }
    else
    {
      $numrows--;
    }
  }
  if ($numrows > 0)
  {
    $mainbox->selectionSet(0);
  }
  $sth->finish;
  my $endtime = timelocal(localtime());
  my $diff = $endtime - $starttime;
  $cattext="";
  $title="";
  $artist="";
  $anyfield="";
  $category="Any";
  $mw->Unbusy(-recurse=>1);
  if ($numrows == 1)     
  {       
    $status="Displaying $numrows search result ";     
  }     
  else     
  {       
    $status="Displaying $numrows search results ";     
  }
  if ($diff == 1)
  {
    $status .= "($diff second elapsed)";
  }
  else
  {
    $status .= "($diff seconds elapsed)";
  }
}

sub build_categories_menu
{
  # This builds the categories menu in the search area.  First, it deletes
  # all entries from the menu.  Then it queries the categories table in 
  # the database and builds a menu, with one radiobutton entry per
  # category.  This ensures that adding or deleting categories will 
  # cause the menu to reflect the most current information.

  # Remove old entries
  $catmenu->delete(0,'end');
  $catmenu->configure(-tearoff=>0);

  # Query the database for new ones.
  $catmenu->radiobutton(-label=>"Any category",
                        -value=>"Any",
                        -variable=>\$category);
  $query="SELECT * from categories ORDER BY description";
  my $sth=$dbh->prepare($query);
  $sth->execute or die "can't execute the query: $DBI::errstr\n";
  while (@table_row = $sth->fetchrow_array)
  {
    $code=$table_row[0];
    $name=$table_row[1];
    $catmenu->radiobutton(-label=>$name,
                          -value=>$code,
                          -variable=>\$category);
  }
  $sth->finish;
}

sub do_exit
{
 # Disconnects from the database, attempts to close the MP3 player, and 
 # exits the program.

 $dbh->disconnect;
 if ("$^O" eq "MSWin32")
 {
   # Close the MP3 player on a Windows system
   Win32::Process::KillProcess($mp3_pid,1);
 }
 else
 {
   # Close the MP3 player on a Unix system.
   kill (15,$mp3_pid);
 }
 Tk::exit;
} 

sub rightclick_menu
{
  # Bound to the search results box, this function binds the creation
  # of a popup menu to the right mouse button. The menu allows you to
  # play, edit, or delete the current song.  The right-click finds the
  # nearest search result to your mouse, and activates it.

  my $rightmenu = $mw->Menu(-menuitems=>[
                                        ["command" => "Play This Song",
                                        -command => [\&play_mp3,$mainbox]],
                                        ["command" => "Edit This Song",
                                        -command => \&edit_song],
                                        ["command" => "Delete This Song",
                                        -command => \&delete_song]
                                        ],
                            -tearoff=>0);

  my $w=shift;
  my $ev=$w->XEvent;
  my $index=$w->nearest($ev->y);

  $w->selectionClear(0,'end');
  $w->selectionSet($index);

  $rightmenu->Popup(-popover=>'cursor',
                    -popanchor=>'nw');
}

sub read_rcfile
{
  # Opens the configuration file, of the form var_name::value, and assigns
  # the value to the variable name.
  # On MS Windows, it also converts long pathnames to short ones.

  if (-r $rcfile)
  {
    open (RCFILE,$rcfile);
    while (<RCFILE>)
    {
      chomp;
      ($var1,$var2) = split(/::/);
      $$var1=$var2;
    }
    close (RCFILE);
  }
  else
  {
    infobox($mw, "Configuration not found","You don't appear to have configured Mr. Voice before.\nStarting configuration now\n");
    edit_preferences();
  }
  if ($^O eq "MSWin32")
  {
    $filepath = $filepath . "\\" unless ($filepath =~ /\\$/);
    $filepath = Win32::GetShortPathName($filepath);
    $savedir = $savedir . "\\" unless ($savedir =~ /\\$/);
    $savedir = Win32::GetShortPathName($savedir);
    $mp3player = Win32::GetShortPathName($mp3player);
  }
  else
  {
    $filepath = $filepath . "/" unless ($filepath =~ /\/$/);
    $savedir =~ s#(.*)/$#$1#;
  }
}

sub StartDrag
{
  # Starts the drag for the hotkey drag-and-drop.
  $sound_icon = $mw->Photo(-data=>$sound_icon_data);

  my ($token) = @_;
  my $widget = $token->parent;
  my $event = $widget->XEvent;
  my $index = $widget->nearest($event->y);
  if (defined $index)
  {
    my $text = $widget->get($index);
    $text =~ s/.*?(".*?").*/$1/;
    $token->configure(-image=>$sound_icon);
    my ($X, $Y) = ($event->X, $event->Y);
    $token->raise;
    $token->deiconify;
    $token->FindSite($X, $Y, $event);
  }
}

sub Hotkey_Drop {
  # Assigns the dragged token to the hotkey that it's dropped onto.

  my ($fkey_var, $dnd_source) = @_;
  my $id = get_song_id($mainbox, $dnd_source->cget(-text));
  my $filename = get_filename($id);
  $$fkey_var = $filename;
}

sub Tank_Drop 
{
  my ($dnd_source) = @_;
  my $selection = $mainbox->get($mainbox->curselection());
  $tankbox->insert('end',$selection);
}

#########
# MAIN PROGRAM
#########
$mw = MainWindow->new;
$mw->withdraw();
$mw->configure(-menu=>$menubar = $mw->Menu);
$mw->geometry("+0+0");
$mw->title("Mr. Voice");
$mw->minsize(67,2);
$mw->protocol('WM_DELETE_WINDOW',\&do_exit);
$icon = $mw->Pixmap(-data=>$icon_data);
$mw->Icon(-image=>$icon);

read_rcfile();

if (! ($dbh = DBI->connect("DBI:mysql:$db_name",$db_username,$db_pass)))
{
  $box = $mw->DialogBox(-title=>"Fatal Error", -buttons=>["Ok"]);
  $box->Icon(-image=>$icon);
  $box->add("Label",-text=>"Could not connect to database.")->pack();
  $box->add("Label",-text=>"Make sure your database configuration is correct,\nand that your database is running.")->pack();
  $box->add("Label",-text=>"The preferences menu will now pop up for you to\ncheck or set any configuration options.")->pack();
  $box->add("Label",-text=>"After you set the preferences, Mr. Voice will exit.\nYou will need to restart to test your changes.")->pack();
  $box->add("Label",-text=>"Database returned error: $DBI::errstr")->pack();
  $result = $box->Show();
  if ($result)
  {
    edit_preferences();
    die "Died with database error $DBI::errstr\n";
  }
}

if (! -W $filepath)
{
  $box = $mw->DialogBox(-title=>"Fatal Error", -buttons=>["Exit"]);
  $box->Icon(-image=>$icon);
  $box->add("Label",-text=>"MP3 Directory unavailable")->pack();
  $box->add("Label",-text=>"The MP3 directory that you set is unavailable.  Check\nto make sure the directory is correct, and you have\npermission to access it.")->pack();
  $box->add("Label",-text=>"The preferences menu will now pop up for you to\ncheck or set any configuration options.")->pack();
  $box->add("Label",-text=>"After you set the preferences, Mr. Voice will exit.\nYou will need to restart to test your changes.")->pack();
  $box->add("Label",-text=>"Current MP3 Directory: $filepath")->pack();
  $result = $box->Show();
  if ($result)
  {
    edit_preferences();
    die ("Error accessing MP3 directory\n");
  }
}

if (! -W $savedir)
{
  $box = $mw->DialogBox(-title=>"Warning", -buttons=>["Continue"]);
  $box->Icon(-image=>$icon);
  $box->add("Label",-text=>"Hotkey save directory unavailable")->pack();
  $box->add("Label",-text=>"The hotkey save directory is unset or you do not\nhave permission to write to it.")->pack();
  $box->add("Label",-text=>"While this will not impact the operation of Mr. Voice,\nyou should probably fix it in the File->Preferences menu.")->pack();
  $box->add("Label",-text=>"Current Hotkey Directory: $savedir")->pack();
  $result = $box->Show();
}

# Check to see if the database is compatible with version 1.7+
$query = "SELECT time FROM mrvoice LIMIT 1";
my $sth=$dbh->prepare($query);
if (! $sth->execute)
{
  $box = $mw->DialogBox(-title=>"Database Update Needed", -buttons=>["Continue","Quit"]);
  $box->Icon(-image=>$icon);
  $box->add("Label",-text=>"Your database is not compatible with Mr. Voice 1.7")->pack();
  $box->add("Label",-text=>"With the 1.7 release, some database changes were introduced.\nPress the Continue button to automatically update your database, or Quit to exit.")->pack();
  $box->add("Label",-text=>"Continuing will update your tables and record the song times into the database\nThis process may take upwards of a few minutes, depending on the number of songs in your database.")->pack();
  $result = $box->Show();
  if ($result eq "Continue")
  {
    $box = $mw->DialogBox(-title=>"Updating Database", -buttons=>["Continue"]);
    $box->Icon(-image=>$icon);
    $box->add("Label",-text=>"Creating temp database...")->pack();
    $query = "CREATE TABLE mrvoice2 (
   id int(8) NOT NULL auto_increment,
   title varchar(255) NOT NULL,
   artist varchar(255),
   category varchar(8) NOT NULL,
   info varchar(255),
   filename varchar(255) NOT NULL,
   time varchar(10),
   modtime timestamp(6),
   PRIMARY KEY (id))";

    my $sth=$dbh->prepare($query);
    $sth->execute;
    if ($DBI::err)
    {
      $string = "$DBI::errstr";
      $box->add("Label",-text=>"FAILED: $string")->pack();
    }
    else
    {
      $box->add("Label",-text=>"SUCCEEDED")->pack();
    }
    $sth->finish;
 
    $query = "SELECT * from mrvoice";
    
    $percent_done = 0;
    $progressbox=$mw->Toplevel();
    $progressbox->withdraw();
    $progressbox->Icon(-image=>$icon);
    $progressbox->title("Song Conversion Status");
    $progressbox->ProgressBar(
      -width => 20,
      -length => 200,
      -from => 0,
      -to => 100,
      -blocks => 10,
      -colors => [0, 'green'],
      -variable=>\$percent_done)->pack(-side=>'top');
    $progressbox->Label(-text=>"Song Conversion Status (Percentage)")->pack(-side=>'top');
    $donebutton = $progressbox->Button(
      -text => "Done",
      -state => 'disabled',
      -command=>sub { $progressbox->destroy})->pack(-side=>'top');
    $progressbox->deiconify();
    $progressbox->raise();

    $sth=$dbh->prepare($query);
    $sth->execute;
    $numrows = $sth->rows;
    $rowcount = 0;
    while (@table_row = $sth->fetchrow_array)
    {
      $tmpid = $dbh->quote($table_row[0]);
      $tmptitle = $dbh->quote($table_row[1]);
      $tmpartist = $dbh->quote($table_row[2]);
      $tmpcategory = $dbh->quote($table_row[3]);
      $tmpinfo = $dbh->quote($table_row[4]);
      $tmpfilename = $dbh->quote($table_row[5]);
      $tmpmodtime = $dbh->quote($table_row[6]);
    
      $query = "INSERT INTO mrvoice2 (id,title,artist,category,info,filename,time,modtime) VALUES ($tmpid, $tmptitle,";
      if ($tmpartist eq "")
      {
        $query .= "NULL,";
      }
      else
      {
        $query .= "$tmpartist,";
      }
      $query .= "$tmpcategory,";
      if ($tmpinfo eq "")
      {
        $query .= "NULL,";
      }
      else
      {
        $query .= "$tmpinfo,";
      }
      $query .= "$tmpfilename,";
      $length = get_songlength("$filepath$table_row[5]");
      $query .= "'$length',$tmpmodtime)";
      $sth2=$dbh->prepare($query);
      $sth2->execute;
      $sth2->finish;
      $rowcount++;
      $percent_done = int ( ($rowcount / $numrows) * 100);
      $progressbox->update();
    }
    $donebutton->configure(-state=>'active');
    $progressbox->update();
    while (Exists($progressbox))
    {
      $progressbox->update();
    }
    $box->add("Label",-text=>"Building new table...SUCCEEDED")->pack();
    $sth->finish;
    $dbh->do("RENAME TABLE mrvoice TO oldmrvoice");
    $dbh->do("RENAME TABLE mrvoice2 TO mrvoice");
    $box->add("Label",-text=>"Renaming tables...SUCCEEDED")->pack();
    $box->add("Label",-text=>"The database has been updated - song times are now stored in the database itself\nIn the future, if you modify a file in $filepath directly,\nyou will need to run the Update Song Times function from the Songs menu.")->pack();
    $box->Show();
    $sth->finish;
  }
  else
  {
    do_exit;
  }
}


# We use the following statement to open the MP3 player asynchronously
# when the Mr. Voice app starts.

if ("$^O" eq "MSWin32")
{
  # Start the MP3 player on a Windows system
  my $object;
  Win32::Process::Create($object, $mp3player,'',1, NORMAL_PRIORITY_CLASS, ".");
  $mp3_pid=$object->GetProcessID();
  sleep(1);
}
else
{
  # Start the MP3 player on a Unix system using fork/exec
  $mp3_pid = fork();
  if ($mp3_pid == 0) 
  {
    # We're the child of the fork
    exec ("$mp3player");
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

$filemenu = $menubar->cascade(-label=>'~File',
                              -tearoff=>0,
                              -menuitems=> filemenu_items);
$dynamicmenu=$menubar->entrycget('File', -menu)->entrycget('Recent Files', -menu);
$hotkeysmenu = $menubar->cascade(-label=>'~Hotkeys',
                                 -tearoff=>0,
                                 -menuitems=> hotkeysmenu_items);
$hotkeysmenu->menu->entryconfigure("Restore Hotkeys", -state=>"disabled");
$categoriesmenu = $menubar->cascade(-label=>'~Categories',
                                    -tearoff=>0,
                                    -menuitems=> categoriesmenu_items);
$songsmenu = $menubar->cascade(-label=>'~Songs',
                               -tearoff=>0,
                               -menuitems=> songsmenu_items);
$advancedmenu = $menubar->cascade(-label=>'~Advanced Search',
                                  -tearoff=>0,
				  -menuitems=> advancedmenu_items);
$helpmenu = $menubar->cascade(-label=>'Help',
                              -tearoff=>0,
                              -menuitems=> helpmenu_items);

sub filemenu_items
{
  [
    ['command', 'Open Hotkey File', -command=>\&open_file, -accelerator=>'Ctrl-O'],
    ['command', 'Save Hotkeys To A File', -command=>\&save_file, -accelerator=>'Ctrl-S'],
    ['command', 'Backup Database To A File', -command=>\&dump_database],
    ['command', 'Import Database Backup File', -command=>\&import_database],
    ['command', 'Preferences', -command=>\&edit_preferences],
    ['cascade', 'Recent Files', -tearoff=>0],
    '',
    ['command', 'Exit', -command=>\&do_exit, -accelerator=>'Ctrl-X'],
  ];
}

sub hotkeysmenu_items
{
  [
    ['command', 'Show Hotkeys', -command=>\&list_hotkeys, -accelerator=>'Ctrl-H'],
    ['command', 'Clear All Hotkeys', -command=>\&clear_hotkeys],
    ['command', 'Show Holding Tank', -command=>\&holding_tank],
#STARTCSZ
#    ['command', 'Show Predefined Hotkeys', -command=>\&show_predefined_hotkeys],
#ENDCSZ
    "",
    ['command', 'Restore Hotkeys', -command=>\&restore_hotkeys],
  ];
}

sub categoriesmenu_items
{
  [
    ['command', 'Add Category', -command=>\&add_category],
    ['command', 'Delete Category', -command=>\&delete_category],
    ['command', 'Edit Category', -command=>\&edit_category],
  ];
}

sub songsmenu_items
{
  [
    ['command', 'Add New Song', -command=>\&add_new_song],
    ['command', 'Edit Currently Selected Song', -command=>\&edit_song],
    ['command', 'Delete Currently Selected Song', -command=>\&delete_song],
    ['command', 'Update Song Times', -command=>\&update_time],
  ];
}

sub advanced_search
{
  my $query="select modtime from mrvoice order by modtime asc limit 1";
  my $sth=$dbh->prepare($query);
  $sth->execute or die "can't execute the query: $DBI::errstr\n";
  my @table_row = $sth->fetchrow_array;
  my $firstdate=$table_row[0];
  $sth->finish;

  $firstdate =~ /(\d\d)(\d\d)(\d\d)/;

  $start_month = $2;
  $start_date = $3;
  $start_year = "20$1"; 

  my @today = localtime();
  $end_month = $today[4] + 1;
  $end_date = $today[3];
  $end_year = $today[5] + 1900;

  my $box = $mw->DialogBox(-title=>"Advanced Search", -buttons=>["Ok","Cancel"]);
  $box->Icon(-image=>$icon);
  $box->add("Label",-text=>"Use this form to search for songs modified between specific dates.")->pack();
  my $adv_searchframe_start = $box->add("Frame",-borderwidth=>5)
                                      ->pack(-side=>'top',
                                             -anchor=>'w',
					     -fill=>'x');
  $adv_searchframe_start->Label(-text=>"Start date: ")->pack(-side=>'left');
  my $start_month_button = $adv_searchframe_start->Menubutton(-text=>"Month ($start_month)",
                                                        -relief=>'raised',
		                                        -indicatoron=>1)->pack(-side=>"left");
  $start_month_menu = $start_month_button->menu(-tearoff=>0);
  $start_month_button->configure(-menu=>$start_month_menu);
  for ($i=1; $i<=12; $i++)
  {
    $start_month_menu->radiobutton(-label=>$i,
                                   -value=>$i,
                                   -variable=>\$start_month,
				   -command=>sub {update_button($start_month_button, "Month", $start_month); });
  }
  $adv_searchframe_start->Label(-text=>"/")->pack(-side=>'left');

  my $start_date_button = $adv_searchframe_start->Menubutton(-text=>"Date ($start_date)",
                                                       -relief=>'raised',
                                                       -indicatoron=>1)->pack(-side=>"left");
  $start_date_menu = $start_date_button->menu(-tearoff=>0);
  $start_date_button->configure(-menu=>$start_date_menu);
  for ($i=1; $i<=31; $i++)
  {
    $start_date_menu->radiobutton(-label=>$i,
                                   -value=>$i,
                                   -variable=>\$start_date,
				   -command=>sub {update_button($start_date_button, "Date", $start_date); });
  }
  $adv_searchframe_start->Label(-text=>"/")->pack(-side=>'left');
  my $start_year_button = $adv_searchframe_start->Menubutton(-text=>"Year ($start_year)",
                                                       -relief=>'raised',
                                                       -indicatoron=>1)->pack(-side=>"left");
  $start_year_menu = $start_year_button->menu(-tearoff=>0);
  $start_year_button->configure(-menu=>$start_year_menu);
  for ($i=2000; $i<=2003; $i++)
  {
    $start_year_menu->radiobutton(-label=>$i,
                                   -value=>$i,
                                   -variable=>\$start_year,
				   -command=>sub {update_button($start_year_button, "Year", $start_year); });
  }

  my $adv_searchframe_end = $box->add("Frame",-borderwidth=>5)
                                                     ->pack(-side=>'top',
                                                     -anchor=>'w',
  				                     -fill=>'x');
  $adv_searchframe_end->Label(-text=>"End date:   ")->pack(-side=>'left');
  my $end_month_button = $adv_searchframe_end->Menubutton(-text=>"Month ($end_month)",
                                                        -relief=>'raised',
		                                        -indicatoron=>1)->pack(-side=>"left");
  $end_month_menu = $end_month_button->menu(-tearoff=>0);
  $end_month_button->configure(-menu=>$end_month_menu);
  for ($i=1; $i<=12; $i++)
  {
    $end_month_menu->radiobutton(-label=>$i,
                                   -value=>$i,
                                   -variable=>\$end_month,
				   -command=>sub {update_button($end_month_button, "Month", $end_month); });
  }
  $adv_searchframe_end->Label(-text=>"/")->pack(-side=>'left');

  my $end_date_button = $adv_searchframe_end->Menubutton(-text=>"Date ($end_date)",
                                                       -relief=>'raised',
                                                       -indicatoron=>1)->pack(-side=>"left");
  $end_date_menu = $end_date_button->menu(-tearoff=>0);
  $end_date_button->configure(-menu=>$end_date_menu);
  for ($i=1; $i<=31; $i++)
  {
    $end_date_menu->radiobutton(-label=>$i,
                                   -value=>$i,
                                   -variable=>\$end_date,
				   -command=>sub {update_button($end_date_button, "Date", $end_date); });
  }
  $adv_searchframe_end->Label(-text=>"/")->pack(-side=>'left');
  my $end_year_button = $adv_searchframe_end->Menubutton(-text=>"Year ($end_year)",
                                                       -relief=>'raised',
                                                       -indicatoron=>1)->pack(-side=>"left");
  $end_year_menu = $end_year_button->menu(-tearoff=>0);
  $end_year_button->configure(-menu=>$end_year_menu);
  for ($i=2000; $i<=2003; $i++)
  {
    $end_year_menu->radiobutton(-label=>$i,
                                -value=>$i,
                                -variable=>\$end_year,
                                -command=>sub {update_button($end_year_button, "Year", $end_year); });
  }

  my $button = $box->Show;

  if ($button eq "Ok")
  {
    my $errorcode = 0;
    my $errorstring = "";

    # Check for invalid dates before we send stuff over to the database
    if ( ! ParseDate("$start_month/$start_date/$start_year") )
    {
      $errorcode = 1; 
      $errorstring .= "Your start date of $start_month/$start_date/$start_year is invalid!\n";
    }
    if ( ! ParseDate("$end_month/$end_date/$end_year") )
    {
      $errorcode = 1;
      $errorstring .= "Your end date of $end_month/$end_date/$end_year is invalid!\n";
    }

    if ($errorcode == 1)
    {
      $errorstring .= "Search cancelled - please try again.";
      infobox($mw,"Invalid dates entered",$errorstring);
    }
    else
    {
      # Go on and do the search - data checks out
      do_search("range","$start_year-$start_month-$start_date","$end_year-$end_month-$end_date");
    }
  }

  else
  {
    $status = "Advanced Search Cancelled";
  }
}

sub update_button()
{
  $button = $_[0];
  $label = $_[1];
  $value = $_[2];
  $button->configure(-text=>"$label ($value)");
}

sub advancedmenu_items
{
  [
    ['command','Show songs added/changed today', -command=>[\&do_search,"timespan","0 days"]],
    ['command','Show songs added/changed in past 7 days', -command=>[\&do_search,"timespan","7 days"]],
    ['command','Show songs added/changed in past 14 days', -command=>[\&do_search,"timespan","14 days"]],
    ['command','Show songs added/changed in past 30 days', -command=>[\&do_search,"timespan","30 days"]],
    ['command','Advanced date search', -command=>\&advanced_search],
  ];
}

sub helpmenu_items
{
  [
    ['command', 'About', -command=>\&show_about],
  ];
}
			      
#####
# The search frame
$searchframe=$mw->Frame()->pack(-side=>'top',
                                -anchor=>'n',
                                -fill=>'x');


$catmenubutton=$searchframe->Menubutton(-text=>"Choose Category",
                                        -relief=>'raised',
                                        -indicatoron=>1)->pack(-side=>'left',
                                                               -anchor=>'n');
$catmenu = $catmenubutton->menu();
$catmenubutton->configure(-menu=>$catmenu);
$catmenubutton->menu()->configure(-postcommand=>\&build_categories_menu);

$searchframe->Label(-text=>"Currently Selected: ")->pack(-side=>'left',
                                                         -anchor=>'n');
$searchframe->Label(-textvariable=>\$category)->pack(-side=>'left',
                                                     -anchor=>'n');
#
######

#####
# Extra Info
$searchframe1=$mw->Frame()->pack(-side=>'top',
                                 -fill=>'x',
                                 -anchor=>'n');
$searchframe1->Label(-text=>"where extra info contains",
                     -width=>25,
                     -anchor=>'w')->pack(-side=>'left');
$cattext_box = $searchframe1->BrowseEntry(-variable=>\$cattext)->pack(-side=>'left');

#####
# Artist
$searchframe2=$mw->Frame()->pack(-side=>'top',
                                 -fill=>'x',
                                 -anchor=>'n');
$searchframe2->Label(-text=>"Artist contains",
                     -width=>25,
                     -anchor=>"w")->pack(-side=>'left');
$artist_box = $searchframe2->BrowseEntry(-variable=>\$artist)->pack(-side=>'left');
#
#####

#####
# Title
$searchframe3=$mw->Frame()->pack(-side=>'top',
                                -fill=>'x');
$searchframe3->Label(-text=>"Title contains",
                     -width=>25,
                     -anchor=>'w')->pack(-side=>'left');
$title_box = $searchframe3->BrowseEntry(-variable=>\$title)->pack(-side=>'left');
#
#####

#####
# Any Field
$searchframe4=$mw->Frame()->pack(-side=>'top',
                                -fill=>'x');
$searchframe4->Label(-text=>"OR any field contains",
                     -width=>25,
                     -anchor=>'w')->pack(-side=>'left');
$anyfield_box = $searchframe4->BrowseEntry(-variable=>\$anyfield)->pack(-side=>'left');
#####

#####
# Search Button
$searchbuttonframe=$mw->Frame()->pack(-side=>'top',
                                      -fill=>'x');
$searchbuttonframe->Button(-text=>"Do Search",
                           -cursor=>'question_arrow',
                           -command=>\&do_search)->pack();
#
#####

#####
# Main display area - search results
$searchboxframe=$mw->Frame();
$mainbox = $searchboxframe->Scrolled('Listbox',
                       -scrollbars=>'osoe',
                       -width=>100,
                       -setgrid=>1,
                       -selectmode=>"single")->pack(-fill=>'both',
                                                    -expand=>1,
                                                    -side=>'top');
$mainbox->bind("<Double-Button-1>", \&play_mp3);

$mainbox->bind("<Button-3>", [\&rightclick_menu]);

$dnd_token = $mainbox->DragDrop(-event => '<B1-Motion>',
                                -sitetypes => ['Local'],
                                -startcommand => sub { StartDrag($dnd_token) });

&BindMouseWheel($mainbox);
#
#####

#####
# Status Frame

$statusframe = $mw->Frame()->pack(-side=>'bottom',
                                  -anchor=>'s',
                                  -fill=>'x');
$playbutton = $statusframe->Button(-text=>"Play Now",
                     -command=>[\&play_mp3,$mainbox])->pack(-side=>'left');
$playbutton->configure(-bg=>'green',
                       -activebackground=>'SpringGreen2');
$stopbutton = $statusframe->Button(-text=>"Stop Now",
                     -command=>\&stop_mp3)->pack(-side=>'right');
if ($^O eq "MSWin32")
{
  # Windows users can shift-click on the stop button to activate WinAmp's
  # automatic fadeout function.
  # It's not changing the relief back after it's done, though.
  $stopbutton->bindtags([$stopbutton,ref($stopbutton),$stopbutton->toplevel,'all']);
  $stopbutton->bind("<Shift-ButtonRelease-1>" => sub {
      $req = HTTP::Request->new(GET => "http://localhost:4800/fadeoutandstop?p=$httpq_pw");
      $res = $agent->request($req);
    });
}

$stopbutton->configure(-bg=>'red',
                       -activebackground=>'tomato3');

$statusframe->Label(-textvariable=>\$status,
                    -relief=>'sunken')->pack(-anchor=>'center',
                                             -expand=>1,
                                             -padx=>5,
                                             -fill=>'x');
#
#####

$searchboxframe->pack(-side=>'bottom',
                      -fill=>'both',
	              -expand=>1);



bind_hotkeys($mw);
$mw->bind("<Control-Key-p>", [\&play_mp3,"Current"]);

# If the default hotkey file exists, load that up.
if (-r "$savedir/default.mrv")
{
  open_file ($mw,"$savedir/default.mrv");
}

if (! -x $mp3player)
{
  my $box = $mw->DialogBox(-title=>"Warning - MP3 player not found", -buttons=>["OK"]);
  $box->Icon(-image=>$icon);
  $box->add("Label",-text=>"Warning - Could not execute your defined MP3 player:")->pack();
  $box->add("Label",-text=>"$mp3player")->pack();
  $box->add("Label",-text=>"You may need to select the proper file in the preferences.")->pack();
  $box->Show;
}

$mw->deiconify();
$mw->raise();
MainLoop;
