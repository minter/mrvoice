#!/usr/bin/perl 

# The perl source for the Win32 setup/installer
# CVS ID: $Id: setup.pl,v 1.1 2003/08/07 20:32:11 minter Exp $

use warnings;
use Tk;
use Tk::Dialog;
use Tk::DialogBox;

our $logo_photo_data = <<end_of_data;
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
rM3qrM8KrdEqrdNKrdVqrdeKrdmqre8TCAA7
end_of_data


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

sub do_exit
{
  Tk::exit;
}

sub start_setup
{
  # Check and make sure everything's kosher before we start.  

  # First, are we running on Win32?
  if ($^O ne "MSWin32")
  {
    my $box = $mw->messageBox(-title=>"Fatal Error",
                          -icon=>"error",
                          -message=>"This installer can only be run on a Microsoft Windows platform.  For all other platforms (Linux, OS X), please read the documentation\n",
                          -type=>"Ok");
    Tk::exit;
  }

  # Next, make sure WinAmp and MySQL are installed

  my $no_winamp = 1 if (! -e "C:/Progra~1/Winamp/Winamp.exe");
  my $no_mysql  = 1 if (! -e "C:/Mysql/bin/mysql.exe");

  if ( ($no_winamp) || ($no_mysql) )
  {
    $string = "One or more required pieces of software were missing.\n\n";
    $string .= "Could not find WinAmp at C:/Program Files/Winamp/Winamp.exe - please install that before continuing.\n\n" if ($no_winamp);
    $string .= "Could not find MySQL at C:/mysql/bin/mysql.exe - please install that before continuing.\n\n" if ($no_mysql);
    $string .= "Please refer to the documentation if you have questions.";

    my $box = $mw->messageBox(-title=>"Fatal Error",
                          -icon=>"error",
                          -message=>$string,
                          -type=>"Ok");
    Tk::exit;
  }

  # IF we get here, we're on Win32, and we have MySQL/Winamp.  Time to start
  # asking questions.

  my $box1 = $mw->DialogBox(-title=>"Enter your database information",
                            -buttons=>["Continue"]);
  $box1->add("Label", -text=>"Now, we start setting up Mr. Voice for Windows.  Don't worry if you make a mistake, you'll get a chance to review at the end.\n")->pack(-side=>'top');
  $box1->add("Label", -text=>"Enter your Superuser password, Database username, and Database password.  The Superuser password will only be used if you")->pack(-side=>'top');
  $b1f1 = $box1->add("Frame")->pack(-side=>'top');
  $b1f1->add("Label", -text=>"Superuser Password")->pack(-side=>"left");
  $b1f1->add("Entry", -textvariable=>\$superuser_pw)->pack(-side=>'right');
  $b1f2 = $box1->add("Frame")->pack(-side=>'top');
  $b1f2->add("Label", -text=>"Database Username")->pack(-side=>"left");
  $b1f2->add("Entry", -textvariable=>\$database_user)->pack(-side=>'right');
  $b1f3 = $box1->add("Frame")->pack(-side=>'top');
  $b1f3->add("Label", -text=>"Database Password")->pack(-side=>"left");
  $b1f3->add("Entry", -textvariable=>\$database_pw)->pack(-side=>'right');

  my $answer1 = $box1->Show();
}

# Mainloop, which just puts up a pretty picture and starts the steps in motion.
$mw = MainWindow->new;
$mw->withdraw();
$mw->geometry("+0+0");
$mw->title("Mr. Voice Windows Setup");
$mw->protocol('WM_DELETE_WINDOW',\&do_exit);
$icon = $mw->Pixmap(-data=>$icon_data);
$mw->Icon(-image=>$icon);

my $logo_photo = $mw->Photo(-data=>$logo_photo_data);
$mw->Label(-image=>$logo_photo,
           -background=>'white')->pack();
$mw->Button(-text=>"Begin Setup",
            -command=>\&start_setup)->pack();

$mw->deiconify();
$mw->raise();
MainLoop;
