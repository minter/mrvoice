#!/usr/bin/perl 
use Tk;
use Tk::DialogBox;
use Tk::DragDrop;
use Tk::DropSite;
use File::Basename;
use File::Copy;
use DBI;
use MPEG::MP3Info;

#########
# AUTHOR: H. Wade Minter <minter@lunenburg.org>
# TITLE: mrvoice.pl
# DESCRIPTION: A Perl/TK frontend for an MP3 database.  Written for
#              ComedyWorx, Raleigh, NC.
#              http://www.comedyworx.com/
# CVS ID: $Id: mrvoice.pl,v 1.91 2001/12/05 02:29:02 minter Exp $
# CHANGELOG:
#   See ChangeLog file
# CREDITS:
#   See Credits file
##########

#####
# CONFIGURATION VARIABLES
# It is probably best to set this in your external config file, either
# ~/.mrvoicerc (Unix) or C:\mrvoice.cfg (Windows)
# NOTE: This section is deprecated and will be removed from future
#       versions.  Use the preferences option under the File menu instead.
#####
$db_name = '';				# In the form DBNAME:HOSTNAME:PORT
$db_username = '';                      # The username used to connect
                                        # to the database.
$db_pass = '';                      	# The password used to connect
                                        # to the database.
$category = 'Any';			# The default category to search
                                        # Initial status message

$mp3player = '';			# Full path to MP3 player
$filepath = '';				# Path that will be prepended onto
					# the filename retrieved from the
					# database, to find the actual
					# MP3 on the local system.
					# MUST END WITH TRAILING /
$savedir = '';				# The default directory where 
                                        # hotkey save files will live.

#####
# YOU SHOULD NOT NEED TO MODIFY ANYTHING BELOW HERE FOR NORMAL USE
#####

$savefile_count = 0;			# Counter variables
$savefile_max = 4;			# The maximum number of files to
					# keep in the "recently used" list.
$hotkeytypes = [
    ['Mr. Voice Hotkey Files', '.mrv'],
    ['All Files', '*'],
  ];

$mp3types = [
    ['MP3 Files', '*.mp3'],
    ['All Files', '*'],
  ];

# Check to see if we're on Windows or Linux, and set the RC file accordingly.
if ("$^O" eq "MSWin32")
{
  $rcfile = "C:\\mrvoice.cfg";
  eval "use Win32::Process";
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
  $rcfile = "$homedir/.mrvoicerc";
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

my $version = "1.3.1";			# Program version
$status = "Welcome to Mr. Voice version $version";		

# This function is redefined due to evilness that keeps the focus on 
# the dragged token.  Thanks to Slaven Rezic <slaven.rezic@berlin.de>
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
  $window->bind("<Key-Return>", [\&do_search]);
  $window->bind("<Key-Escape>", [\&stop_mp3]);
  $window->bind("<Control-Key-x>", [\&do_exit]);
  $window->bind("<Control-Key-o>", [\&open_file]);
  $window->bind("<Control-Key-s>", [\&save_file]);
  $window->bind("<Control-Key-h>", [\&list_hotkeys]);
  #STARTCSZ
  #$window->bind("<Alt-Key-t>", [\&play_mp3,"ALT-T"]);
  #$window->bind("<Alt-Key-y>", [\&play_mp3,"ALT-Y"]);
  #$window->bind("<Alt-Key-b>", [\&play_mp3,"ALT-B"]);
  #$window->bind("<Alt-Key-g>", [\&play_mp3,"ALT-G"]);
  #$window->bind("<Alt-Key-v>", [\&play_mp3,"ALT-V"]);
  #ENDCSZ
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
      infobox($window, "File Error", "Could not open file $selectedfile for reading");
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
      $status = "Loaded hotkey file $selectedfile successfully";
      dynamic_documents($selectedfile);
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
      infobox($mw, "File Error!", "Could not write new file to directory dirname($selectedfile)");
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

sub dynamic_documents
{
  # This function takes a filename as an argument.  It then increments
  # a counter to keep track of how many documents we've accessed in this
  # session.  
  # It adds the file to the "Recent Files" menu off of Files, and if we're
  # over the user-specified limit, removes the oldest file from the list.
  
  $file = $_[0];
  $savefile_count++;

  push (@current, $file);

  $dynamicmenu->command(-label=>"$file",
                        -command => [\&open_file, $mw, $file]);

  if ($#current >= $savefile_max)
  {
    $dynamicmenu->delete(0);
    shift (@current);
  }
}

sub infobox
{
  # A generic wrapper function to pop up an information box.  It takes
  # a reference to the parent widget, the title for the box, and a 
  # formatted string of data to display.
  
  my ($parent_window, $title, $string) = @_;
  my $box = $parent_window->DialogBox(-title=>"$title", -buttons=>["OK"]);
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
  $hotmenu->menu->entryconfigure("Restore Hotkeys", -state=>"normal");
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
  $hotmenu->menu->entryconfigure("Restore Hotkeys", -state=>"disabled");
}

sub add_category
{
  my $box = $mw->DialogBox(-title=>"Add a category", -buttons=>["Ok","Cancel"]);
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
        infobox($mw,"Success","Category successfully added.");
      }
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

}

sub delete_category
{
  my $box = $mw->DialogBox(-title=>"Delete a category",-buttons=>["Ok","Cancel"]);
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
  $box = $mw->DialogBox(-title=>"Add New Song", -buttons=>["OK","Cancel"]);
  $box->add("Label",-text=>"Enter the following information for the new song,\nand choose the file to add.")->pack();
  $box->add("Label",-text=>"Items marked with a * are required.\n")->pack();
  $frame1 = $box->add("Frame")->pack(-fill=>'x');
  $frame1->Label(-text=>"* Song Title")->pack(-side=>'left');
  $frame1->Entry(-width=>30,
                 -textvariable=>\$addsong_title)->pack(-side=>'right');
  $frame2 = $box->add("Frame")->pack(-fill=>'x');
  $frame2->Label(-text=>"Artist")->pack(-side=>'left');
  $frame2->Entry(-width=>30,
                 -textvariable=>\$addsong_artist)->pack(-side=>'right');
  $frame3 = $box->add("Frame")->pack(-fill=>'x');
  $frame3->Label(-text=>"* Category")->pack(-side=>'left');
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
  $frame5->Label(-text=>"* File to add")->pack(-side=>'left');
  $frame6 = $box->add("Frame")->pack(-fill=>'x');
  $frame6->Button(-text=>"Select File",
                  -command=>sub { 
                     $addsong_filename = $mw->getOpenFile(-title=>'Select File',
                                                          -initialdir=>$homedir,
                                                          -filetypes=>$mp3types);
                                })->pack(-side=>'right');
  $frame5->Entry(-width=>30,
                 -textvariable=>\$addsong_filename)->pack(-side=>'right');

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
      if ($addsong_artist)
      {
        $newfilename = "$addsong_artist-$addsong_title";
      }
      else
      {
        $newfilename = $addsong_title;
      }
      $newfilename =~ s/[^a-zA-Z0-9\-]//g;

      if ( -e "$filepath$newfilename.mp3")
      {
        $i=0;
        while (1 == 1)
        {
          if (! -e "$filepath$newfilename-$i.mp3")
          {
            $newfilename = "$newfilename-$i";
            last;
          }
          $i++;
        }
      }
      $newfilename = "$newfilename.mp3";
      $addsong_title = $dbh->quote($addsong_title);
      $addsong_artist = $dbh->quote($addsong_artist);
      $addsong_info = $dbh->quote($addsong_info);
      $query = "INSERT INTO mrvoice VALUES (NULL,$addsong_title,$addsong_artist,'$addsong_cat',$addsong_info,'$newfilename',NULL)";
      copy ($addsong_filename,"$filepath$newfilename");
      if ($dbh->do($query))
      {
        infobox ($mw, "File Added Successfully","Successfully added new song into database");
        $status = "File added successfully";
      }
      else
      {
        infobox ($mw, "Error","Could not add song into database");
        $status = "File add exited on database error";
      }
    }
  }
  else
  {
    $status = "Cancelled song add";
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
  $box->add("Label",-text=>"You may use this form to modify the operating\npreferences for the Mr. Voice software.\n")->pack();
  my $frame1 = $box->add("Frame")->pack(-fill=>'x');
  $frame1->Label(-text=>"Database Name")->pack(-side=>'left');
  $frame1->Entry(-width=>30,
                 -textvariable=>\$db_name)->pack(-side=>'right'); 
  my $frame2 = $box->add("Frame")->pack(-fill=>'x');
  $frame2->Label(-text=>"Database User Name")->pack(-side=>'left');
  $frame2->Entry(-width=>30,
                 -textvariable=>\$db_username)->pack(-side=>'right'); 
  my $frame3 = $box->add("Frame")->pack(-fill=>'x');
  $frame3->Label(-text=>"Database Password")->pack(-side=>'left');
  $frame3->Entry(-width=>30,
                 -textvariable=>\$db_pass)->pack(-side=>'right'); 
  my $frame4 = $box->add("Frame")->pack(-fill=>'x');
  $frame4->Label(-text=>"MP3 Directory")->pack(-side=>'left');
  $frame4->Entry(-width=>30,
                 -textvariable=>\$filepath)->pack(-side=>'right'); 
  my $frame5 = $box->add("Frame")->pack(-fill=>'x');
  $frame5->Label(-text=>"Hotkey Directory")->pack(-side=>'left');
  $frame5->Entry(-width=>30,
                 -textvariable=>\$savedir)->pack(-side=>'right'); 
  my $frame6 = $box->add("Frame")->pack(-fill=>'x');
  $frame6->Label(-text=>"MP3 Player")->pack(-side=>'left');
  $frame6->Button(-text=>"Choose",
                  -command=>sub { 
                     $mp3player = $mw->getOpenFile(-title=>'Select File');
                                })->pack(-side=>'right');
  $frame6->Entry(-width=>30,
                 -textvariable=>\$mp3player)->pack(-side=>'right'); 
  my $frame7 = $box->add("Frame")->pack(-fill=>'x');
  $frame7->Label(-text=>"Number of Dynamic Documents To Show")->pack(-side=>'left');
  $frame7->Entry(-width=>2,
                 -textvariable=>\$savefile_max)->pack(-side=>'right');

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
                                             -default_button=>"Cancel");
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
      $status = "Edited song successfully";
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
  infobox($mw, "About Mr. Voice","Mr. Voice Version $version\n\nBy H. Wade Minter <minter\@lunenburg.org>\n\nURL: http://www.lunenburg.org/mrvoice/\n\n(c)2001, Released under the GNU General Public License");
}

#STARTCSZ
#sub show_predefined_hotkeys
#{
#  $box = $mw->DialogBox(-title=>"Predefined Hotkeys", -buttons=>["Close"]);
#  $box->add("Label",-text=>"The following hotkeys are always available\nand
#may not be changed")->pack();
#  $box->add("Label",-text=>"<Escape> - Stop the currently playing MP3")->pack();
#  $box->add("Label",-text=>"<Enter> - Perform the currently entered search")->pack();
#  $box->add("Label",-text=>"<ALT-t> - The \"Ta-Da\" MIDI")->pack();
#  $box->add("Label",-text=>"<ALT-y> - The \"You're Out\" MIDI")->pack();
#  $box->add("Label",-text=>"<ALT-b> - The Brown Bag MIDI")->pack();
#  $box->add("Label",-text=>"<ALT-v> - The Price Is Right theme (Volunteer photos)")->pack();
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
  bind_hotkeys($holdingtank);              
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
  my $buttonframe = $holdingtank->Frame()->pack(-side=>'bottom',
                                             -fill=>'x');
  my $playbutton = $buttonframe->Button(-text=>"Play Now",
                                        -command=>[\&play_mp3,$tankbox])->pack(-side=>'left');
  $playbutton->configure(-bg=>'green',
                       -activebackground=>'SpringGreen2');
  my $stopbutton = $buttonframe->Button(-text=>"Stop Now",
                                        -command=>[\&stop_mp3])->pack(-side=>'left');
  $stopbutton->configure(-bg=>'red',
                       -activebackground=>'tomato3');
  $buttonframe->Button(-text=>"Close",
                       -command=>sub {$holdingtank->destroy})->pack(-side=>'right');
  $buttonframe->Button(-text=>"Clear Selected",
                       -command=>[\&clear_tank])->pack(-side=>'right');
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
  if (Exists($hotkeysbox))
  {
    # We only want one copy on the screen at a time.
    return;
  }
  $hotkeysbox=$mw->Toplevel();
  bind_hotkeys($hotkeysbox);
  $hotkeysbox->title("Hotkeys");
  $hotkeysbox->Label(-text=>"Currently defined hotkeys:")->pack;
  my $f1_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
  $f1_frame->Checkbutton(-text=>"F1: ",
                         -variable=>\$f1_cb)->pack(-side=>'left');
  $f1_frame->Label(-textvariable=>\$f1)->pack(-side=>'left');
  $f1_frame->DropSite(-droptypes=>['Local'],
                      -dropcommand=>[\&Hotkey_Drop, \$f1, $dnd_token ]);
  my $f2_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
  $f2_frame->Checkbutton(-text=>"F2: ",
                         -variable=>\$f2_cb)->pack(-side=>'left');
  $f2_frame->Label(-textvariable=>\$f2)->pack(-side=>'left');
  $f2_frame->DropSite(-droptypes=>['Local'],
                      -dropcommand=>[\&Hotkey_Drop, \$f2, $dnd_token ]);
  my $f3_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
  $f3_frame->Checkbutton(-text=>"F3: ",
                         -variable=>\$f3_cb)->pack(-side=>'left');
  $f3_frame->Label(-textvariable=>\$f3)->pack(-side=>'left');
  $f3_frame->DropSite(-droptypes=>['Local'],
                      -dropcommand=>[\&Hotkey_Drop, \$f3, $dnd_token ]);
  my $f4_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
  $f4_frame->Checkbutton(-text=>"F4: ",
                         -variable=>\$f4_cb)->pack(-side=>'left');
  $f4_frame->Label(-textvariable=>\$f4)->pack(-side=>'left');
  $f4_frame->DropSite(-droptypes=>['Local'],
                      -dropcommand=>[\&Hotkey_Drop, \$f4, $dnd_token ]);
  my $f5_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
  $f5_frame->Checkbutton(-text=>"F5: ",
                         -variable=>\$f5_cb)->pack(-side=>'left');
  $f5_frame->Label(-textvariable=>\$f5)->pack(-side=>'left');
  $f5_frame->DropSite(-droptypes=>['Local'],
                      -dropcommand=>[\&Hotkey_Drop, \$f5, $dnd_token ]);
  my $f6_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
  $f6_frame->Checkbutton(-text=>"F6: ",
                         -variable=>\$f6_cb)->pack(-side=>'left');
  $f6_frame->Label(-textvariable=>\$f6)->pack(-side=>'left');
  $f6_frame->DropSite(-droptypes=>['Local'],
                      -dropcommand=>[\&Hotkey_Drop, \$f6, $dnd_token ]);
  my $f7_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
  $f7_frame->Checkbutton(-text=>"F7: ",
                         -variable=>\$f7_cb)->pack(-side=>'left');
  $f7_frame->Label(-textvariable=>\$f7)->pack(-side=>'left');
  $f7_frame->DropSite(-droptypes=>['Local'],
                      -dropcommand=>[\&Hotkey_Drop, \$f7, $dnd_token ]);
  my $f8_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
  $f8_frame->Checkbutton(-text=>"F8: ",
                         -variable=>\$f8_cb)->pack(-side=>'left');
  $f8_frame->Label(-textvariable=>\$f8)->pack(-side=>'left');
  $f8_frame->DropSite(-droptypes=>['Local'],
                      -dropcommand=>[\&Hotkey_Drop, \$f8, $dnd_token ]);
  my $f9_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
  $f9_frame->Checkbutton(-text=>"F9: ",
                         -variable=>\$f9_cb)->pack(-side=>'left');
  $f9_frame->Label(-textvariable=>\$f9)->pack(-side=>'left');
  $f9_frame->DropSite(-droptypes=>['Local'],
                      -dropcommand=>[\&Hotkey_Drop, \$f9, $dnd_token ]);
  my $f10_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
  $f10_frame->Checkbutton(-text=>"F10:",
                          -variable=>\$f10_cb)->pack(-side=>'left');
  $f10_frame->Label(-textvariable=>\$f10)->pack(-side=>'left');
  $f10_frame->DropSite(-droptypes=>['Local'],
                      -dropcommand=>[\&Hotkey_Drop, \$f10, $dnd_token ]);
  my $f11_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
  $f11_frame->Checkbutton(-text=>"F11:",
                          -variable=>\$f11_cb)->pack(-side=>'left');
  $f11_frame->Label(-textvariable=>\$f11)->pack(-side=>'left');
  $f11_frame->DropSite(-droptypes=>['Local'],
                      -dropcommand=>[\&Hotkey_Drop, \$f11, $dnd_token ]);
  my $f12_frame = $hotkeysbox->Frame()->pack(-fill=>'x');
  $f12_frame->Checkbutton(-text=>"F12:",
                          -variable=>\$f12_cb)->pack(-side=>'left');
  $f12_frame->Label(-textvariable=>\$f12)->pack(-side=>'left');
  $f12_frame->DropSite(-droptypes=>['Local'],
                      -dropcommand=>[\&Hotkey_Drop, \$f12, $dnd_token ]);
  $hotkeysbox->Button(-text=>"Close",
                      -command=>sub { $hotkeysbox->destroy})->pack(-side=>'left');
  $hotkeysbox->Button(-text=>"Clear Selected",
                      -command=>[\&clear_selected])->pack(-side=>'right');
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

sub set_hotkey
{
  my $id = get_song_id($mainbox);
  $box = $mw->DialogBox(-title=>"Bind Hotkeys", -buttons=>["Apply","Cancel"]);
  $box->add("Label",-text=>"Choose the keys to bind song $id to:")->pack();
  $box->add("Checkbutton",-text=>"F1",
                          -variable=>\$f1_cb)->pack();
  $box->add("Checkbutton",-text=>"F2",
                          -variable=>\$f2_cb)->pack();
  $box->add("Checkbutton",-text=>"F3",
                          -variable=>\$f3_cb)->pack();
  $box->add("Checkbutton",-text=>"F4",
                          -variable=>\$f4_cb)->pack();
  $box->add("Checkbutton",-text=>"F5",
                          -variable=>\$f5_cb)->pack();
  $box->add("Checkbutton",-text=>"F6",
                          -variable=>\$f6_cb)->pack();
  $box->add("Checkbutton",-text=>"F7",
                          -variable=>\$f7_cb)->pack();
  $box->add("Checkbutton",-text=>"F8",
                          -variable=>\$f8_cb)->pack();
  $box->add("Checkbutton",-text=>"F9",
                          -variable=>\$f9_cb)->pack();
  $box->add("Checkbutton",-text=>"F10",
                          -variable=>\$f10_cb)->pack();
  $box->add("Checkbutton",-text=>"F11",
                          -variable=>\$f11_cb)->pack();
  $box->add("Checkbutton",-text=>"F12",
                          -variable=>\$f12_cb)->pack();
  $result = $box->Show();

  if ($result eq "Apply")
  {
    $filename = get_filename($id);
    $f1=$filename if ($f1_cb);
    $f2=$filename if ($f2_cb);
    $f3=$filename if ($f3_cb);
    $f4=$filename if ($f4_cb);
    $f5=$filename if ($f5_cb);
    $f6=$filename if ($f6_cb);
    $f7=$filename if ($f7_cb);
    $f8=$filename if ($f8_cb);
    $f9=$filename if ($f9_cb);
    $f10=$filename if ($f10_cb);
    $f11=$filename if ($f11_cb);
    $f12=$filename if ($f12_cb);
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
    $status = "Hotkey assigned";
  }
  else
  {
    $status = "Hotkey assignment cancelled";
  }

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
  if ($_[1])
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
  else
  {
    # If not, find the selected song.
    #@list = $mainbox->curselection();
    $box = $_[0];
    my $id = get_song_id($box);
    if ($id)
    {
      $query = "SELECT filename from mrvoice WHERE id=$id";
      my $sth=$dbh->prepare($query);
      $sth->execute or die "can't execute the query: $DBI::errstr\n";
      @result = $sth->fetchrow_array;
      $sth->finish;
      $filename = $result[0];
    }
  }
  if ($filename)
  {
    $status = "Playing file $filename";
    system ("$mp3player $filepath$filename");
  }
}

sub do_search
{
  $status="Starting search...";
  $mw->Busy(-recurse=>1);
  $mainbox->delete(0,'end');
  my $query = "SELECT mrvoice.id,categories.description,mrvoice.info,mrvoice.artist,mrvoice.title,mrvoice.filename from mrvoice,categories where mrvoice.category=categories.code ";
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
  my $sth=$dbh->prepare($query);
  $sth->execute or die "can't execute the query: $DBI::errstr\n";
  while (@table_row = $sth->fetchrow_array)
  {
    if (-e "$filepath$table_row[5]")
    {
      $string="$table_row[0]:($table_row[1]";
      $string = $string . " - $table_row[2]" if ($table_row[2]);
      $string = $string . ") - \"$table_row[4]\"";
      $string = $string. " by $table_row[3]" if ($table_row[3]);
      my $info = get_mp3info("$filepath$table_row[5]");
      $minute = $info->{MM};
      $minute = "0$minute" if ($minute < 10);
      $second = $info->{SS};
      $second = "0$second" if ($second < 10);
      $string = $string . " [$minute:$second]";
      $mainbox->insert('end',$string); 
    }
  }
  $numrows = $sth->rows;
  $sth->finish;
  $cattext="";
  $title="";
  $artist="";
  $anyfield="";
  $category="Any";
  if ($numrows == 1)     
  {       
    $status="Displaying $numrows search result";     
  }     
  else     
  {       
    $status="Displaying $numrows search results";     
  }
  $mw->Unbusy(-recurse=>1);
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
                                        -command => \&play_mp3],
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

  my ($token) = @_;
  my $widget = $token->parent;
  my $event = $widget->XEvent;
  my $index = $widget->nearest($event->y);
  if (defined $index)
  {
    my $text = $widget->get($index);
    $text =~ s/.*?(".*?").*/$1/;
    $token->configure(-text=>$text);
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
  $tankbox->insert(end,$selection);
}

#########
# MAIN PROGRAM
#########
$mw = MainWindow->new;
$mw->geometry("+0+0");
$mw->title("Mr. Voice");
$mw->minsize(67,2);
$mw->protocol('WM_DELETE_WINDOW',\&do_exit);

read_rcfile();

if (! ($dbh = DBI->connect("DBI:mysql:$db_name",$db_username,$db_pass)))
{
  $box = $mw->DialogBox(-title=>"Fatal Error", -buttons=>["Ok"]);
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
  $box->add("Label",-text=>"Hotkey save directory unavailable")->pack();
  $box->add("Label",-text=>"The hotkey save directory is unset or you do not\nhave permission to write to it.")->pack();
  $box->add("Label",-text=>"While this will not impact the operation of Mr. Voice,\nyou should probably fix it in the File->Preferences menu.")->pack();
  $box->add("Label",-text=>"Current Hotkey Directory: $savedir")->pack();
  $result = $box->Show();
}

# We use the following statement to open the MP3 player asynchronously
# when the Mr. Voice app starts.

if ("$^O" eq "MSWin32")
{
  # Start the MP3 player on a Windows system
  my $object;
  Win32::Process::Create($object, $mp3player,'',0, NORMAL_PRIORITY_CLASS, ".");
  $mp3_pid=$object->GetProcessID();
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


$menuframe=$mw->Frame(-relief=>'ridge',
                      -borderwidth=>2)->pack(-side=>'top',
                                            -fill=>'x',
                                            -anchor=>'n');
$filemenu = $menuframe->Menubutton(-text=>"File",
                                   -tearoff=>0)->pack(-side=>'left');
$dynamicmenu=$filemenu->menu->Menu(-tearoff=>0);
$filemenu->AddItems(["command"=>"Open Hotkey File",
                    -command=>\&open_file,
		    -accelerator=>"Ctrl-O"]); 
$filemenu->AddItems(["command"=>"Save Hotkeys To A File",
                    -command=>\&save_file,
		    -accelerator=>"Ctrl-S"]); 
$filemenu->AddItems("-");
$filemenu->AddItems(["command"=>"Preferences",
                    -command=>\&edit_preferences]);
$filemenu->cascade(-label=>"Recent Files");
$filemenu->entryconfigure("Recent Files", -menu=>$dynamicmenu);
$filemenu->AddItems("-");
$exititem = $filemenu->AddItems(["command"=>"Exit", 
                                -command=>\&do_exit,
				-accelerator=>"Ctrl-X"]);
$hotmenu = $menuframe->Menubutton(-text=>"Hotkeys",
                                  -tearoff=>0)->pack(-side=>'left');
$hotmenu->AddItems(["command"=>"Show Hotkeys",
                    -command=>\&list_hotkeys,
		    -accelerator=>"Ctrl-H"]);
$hotmenu->AddItems(["command"=>"Clear All Hotkeys",
                    -command=>\&clear_hotkeys]);
$hotmenu->AddItems(["command"=>"Show Holding Tank",
                    -command=>\&holding_tank]);
#STARTCSZ
#$hotmenu->AddItems(["command"=>"Show Predefined Hotkeys",
#                    -command=>\&show_predefined_hotkeys]);
#ENDCSZ
$hotmenu->AddItems("-");
$hotmenu->AddItems(["command"=>"Restore Hotkeys",
                   -command=>\&restore_hotkeys]);
$hotmenu->menu->entryconfigure("Restore Hotkeys", -state=>"disabled");
$catmenu = $menuframe->Menubutton(-text=>"Categories",
                                  -tearoff=>0)->pack(-side=>'left');
$catmenu->AddItems(["command"=>"Add Category",
                   -command=>\&add_category]);
# Holding off on this feature for a bit.
#$catmenu->AddItems(["command"=>"Edit Category",
#                   -command=>\&edit_category]);
$catmenu->AddItems(["command"=>"Delete Category",
                   -command=>\&delete_category]);

$songmenu = $menuframe->Menubutton(-text=>"Songs",
                                   -tearoff=>0)->pack(-side=>'left');
$songmenu->AddItems(["command"=>"Add New Song",
                    -command=>\&add_new_song]);
$songmenu->AddItems(["command"=>"Edit Currently Selected Song",
                    -command=>\&edit_song]);
$songmenu->AddItems(["command"=>"Delete Currently Selected Song",
                    -command=>\&delete_song]);

$helpmenu = $menuframe->Menubutton(-text=>"Help",
                                   -tearoff=>0)->pack(-side=>'right');
$helpmenu->AddItems(["command"=>"About",
                     -command=>\&show_about]);

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
$searchframe1->Entry(-textvariable=>\$cattext,
                     -width=>20)->pack(-side=>'left');

#####
# Artist
$searchframe2=$mw->Frame()->pack(-side=>'top',
                                 -fill=>'x',
                                 -anchor=>'n');
$searchframe2->Label(-text=>"Artist contains",
                     -width=>25,
                     -anchor=>"w")->pack(-side=>'left');
$searchframe2->Entry(-textvariable=>\$artist,
                     -width=>20)->pack(-side=>'left');
#
#####

#####
# Title
$searchframe3=$mw->Frame()->pack(-side=>'top',
                                -fill=>'x');
$searchframe3->Label(-text=>"Title contains",
                     -width=>25,
                     -anchor=>'w')->pack(-side=>'left');
$searchframe3->Entry(-textvariable=>\$title,
                     -width=>20)->pack(-side=>'left');
#
#####

#####
# Any Field
$searchframe4=$mw->Frame()->pack(-side=>'top',
                                -fill=>'x');
$searchframe4->Label(-text=>"OR any field contains",
                     -width=>25,
                     -anchor=>'w')->pack(-side=>'left');
$searchframe4->Entry(-textvariable=>\$anyfield,
                     -width=>20)->pack(-side=>'left');
#
#####

#####
# Search Button
$searchbuttonframe=$mw->Frame()->pack(-side=>'top',
                                      -fill=>'x');
$searchbuttonframe->Button(-text=>"Do Search",
                           -cursor=>'question_arrow',
                           -command=>\&do_search)->pack(-fill=>'x',-expand=>1);
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
                     -command=>[\&stop_mp3])->pack(-side=>'left');
$stopbutton->configure(-bg=>'red',
                       -activebackground=>'tomato3');
$statusframe->Button(-text=>"Assign Hotkey",
                     -command=>[\&set_hotkey])->pack(-side=>'right');

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

if (! -x $mp3player)
{
  my $box = $mw->DialogBox(-title=>"Warning - MP3 player not found", -buttons=>["OK"]);
  $box->add("Label",-text=>"Warning - Could not execute your defined MP3 player:")->pack();
  $box->add("Label",-text=>"$mp3player")->pack();
  $box->add("Label",-text=>"You may need to select the proper file in the preferences.")->pack();
  $box->Show;
}

MainLoop;
