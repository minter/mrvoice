#!/usr/bin/perl
use Tk;
#use Tk::FileSelect;
use Tk::DialogBox;
use Tk::FileDialog;
use File::Basename;
use DBI;
use MPEG::MP3Info;

#########
# AUTHOR: H. Wade Minter <minter@lunenburg.org>
# TITLE: mrvoice.pl
# DESCRIPTION: A Perl/TK frontend for an MP3 database.  Written for The
#              Great American Comedy Company, Raleigh, NC.
#              http://www.greatamericancomedy.com/
# CVS INFORMATION:
#	LAST COMMIT BY AUTHOR:  $Author: minter $
#	LAST COMMIT DATE (GMT): $Date: 2001/03/05 02:05:32 $
#	CVS REVISION NUMBER:    $Revision: 1.20 $
# CHANGELOG:
#   See ChangeLog file
# CREDITS:
#   See Credits file
##########

#####
# CONFIGURATION VARIABLES
#####
my $db_name = "comedysportz";			# In the form DBNAME:HOSTNAME:PORT
my $db_username = "root";                   # The username used to connect
                                        # to the database.
my $db_pass = "rangers";                       # The password used to connect
                                        # to the database.
$category = "Any";			# The default category to search
                                        # Initial status message

$mp3player = "/usr/bin/xmms";		# Full path to MP3 player
$filepath = "/mp3/";				# Path that will be prepended onto
					# the filename retrieved from the
					# database, to find the actual
					# MP3 on the local system.
					# MUST END WITH TRAILING /
$savedir = "/tmp/";				# The default directory where 
                                        # hotkey save files will live.

#####
# YOU SHOULD NOT NEED TO MODIFY ANYTHING BELOW HERE FOR NORMAL USE
#####

# The following variables set the locations of MP3s for static hotkey'd 
# sounds
#$altt = "TaDa.mp3";
#$alty = "CalloutMusic.mp3";
#$altb = "BrownBag.mp3";
#$altg = "Groaner.mp3";
#$altv = "PriceIsRightTheme.mp3";

#####

my $version = "0.9devel";			# Program version
$status = "Welcome to Mr. Voice version $version";		

$filepath = "$filepath/" unless ($filepath =~ "/.*\/$/");
$savedir = "$savedir/" unless ($savedir =~ "/.*\/$/");

sub open_file
{
  if ($ostype eq "windows")
  {
    $fileselectw = $mw->FileSelect(-directory=>"$savedir",
                                   -acceptlabel=>"Load File",
                                   -filelabel=>'The file to open:',
                                   -defaultextension => "mrv");
    $fileselectw->configure(-title=>"Open A File...");
    $selectedfile = $fileselectw->Show;
  }
  else
  {
    $fileselectw = $mw->FileDialog(-Title=>'Open a File',
                                   -FPat=>"*.mrv",
                                   -OKButtonLabel=>"Open File",
                                   -Path=>$savedir);
    $selectedfile = $fileselectw->Show;
  }
                      
  if ($selectedfile)
  {
    if (! -r $selectedfile)
    {
      $box = $mw->DialogBox(-title=>"File Error!", -buttons=>["OK"]);
      $box->add("Label",-text=>"Could not open file $selectedfile for reading")->pack();
      $box->Show;
    }
    else
    {
      open (HOTKEYFILE,$selectedfile);
      while (<HOTKEYFILE>)
      {
        chomp;
        ($var1,$var2) = split(/::/);
        $$var1=$var2;
      }
      close (HOTKEYFILE);
      $status = "Loaded hotkey file $selectedfile successfully";
    } 
  }
  else
  {
    $status = "File load cancelled."; 
  }
}

sub save_file
{
  if ($ostype eq "windows")
  {
    $fileselectw = $mw->FileSelect(-directory => "$savedir",
                                   -acceptlabel => "Save File",
                                   -filelabel => 'The file to save:',
                                   -defaultextension => "mrv");
    $fileselectw->configure(-title=>"Save A File...");
    $selectedfile = $fileselectw->Show;
  }
  else
  {
    $fileselectw = $mw->FileDialog(-Title=>'Save a File',
                                   -FPat=>"*.mrv",
                                   -OKButtonLabel=>"Save File",
                                   -Path=>$savedir);
    $selectedfile = $fileselectw->Show;
  }

  if ($selectedfile)
  {
    if ( (! -w $selectedfile) && (-e $selectedfile) )
    {
      $box = $mw->DialogBox(-title=>"File Error!", -buttons=>["OK"]);
      $box->add("Label",-text=>"Could not open file $selectedfile for writing")->pack();
      $box->Show;
    }
    elsif ( ! -w dirname($selectedfile) )
    {
      $box = $mw->DialogBox(-title=>"File Error!", -buttons=>["OK"]);
      $box->add("Label",-text=>"Could not write new file to directory dirname($selectedfile)")->pack();
      $box->Show;
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
      $status = "Finished saving hotkeys to $selectedfile\n";
    }
  }
  else
  {
    $status = "File save cancelled.";
  }
}

sub infobox
{
  $box = $mw->DialogBox(-title=>"$_[0]", -buttons=>["OK"]);
  $box->add("Label",-text=>"$_[1]")->pack();
  $box->Show;
}

sub add_category
{
  $box = $mw->DialogBox(-title=>"Add a category", -buttons=>["Ok","Cancel"]);
  $acframe1 = $box->add("Frame")->pack(-fill=>'x');
  $acframe1->Label(-text=>"Category Code:  ")->pack(-side=>'left');
  $acframe1->Entry(-width=>6,
                  -textvariable=>\$addcat_code)->pack(-side=>'left');
  $acframe2 = $box->add("Frame")->pack(-fill=>'x');
  $acframe2->Label(-text=>"Category Description:  ")->pack(-side=>'left');
  $acframe2->Entry(-width=>25,
                  -textvariable=>\$addcat_desc)->pack(-side=>'left');
  $button = $box->Show;
  if ($button eq "Ok")
  {
    if (($addcat_code) && ($addcat_desc))
    {
      $addcat_code =~ tr/a-z/A-Z/;
      $query = "INSERT INTO categories VALUES ('$addcat_code','$addcat_desc')";
      my $sth=$dbh->prepare($query);
      if (! $sth->execute)
      {
        $error_message = $sth->errstr();
        infobox("Database Error","Database returned error: $error_message\non query $query");
      }
      else
      {
        infobox("Success","Category successfully added.\nYou will need to restart to see the change");
      }
    }
    else 
    {
      infobox("Error","You must enter both a category code and a description");
    }
  }
  else
  {
    $status = "Cancelled adding category.";
  }
  $addcat_code="";
  $addcat_desc="";
}

sub delete_category
{
  $box = $mw->DialogBox(-title=>"Delete a category",-buttons=>["Ok","Cancel"]);
  $box->add("Label",-text=>"Choose a category to delete.")->pack();

  $query="SELECT * from categories ORDER BY description";
  my $sth=$dbh->prepare($query);
  $sth->execute or die "can't execute the query: $DBI::errstr\n";
  while (@table_row = $sth->fetchrow_array)
  {
    $code=$table_row[0];
    $name=$table_row[1];
    $box->add("Radiobutton",-text=>$name,
                            -value=>$code,
                            -variable=>\$del_cat)->pack(-expand=>"x",
                                                        -anchor=>"w");
  }
  $sth->finish;
  $choice = $box->Show();
  
  if ($choice ne "Cancel")
  {
    $query = "SELECT * FROM mrvoice WHERE category='$del_cat'";
    my $sth=$dbh->prepare($query);
    $sth->execute;
    $rows = $sth->rows;
    if ($rows > 0)
    {
      infobox("Error","Could not delete category $del_cat because\nthere are still entries in the database\nusing it.  Delete all entries using\nthis category before deleting the category");
      $status = "Category not deleted";
    }
    else
    {
      $query = "DELETE FROM categories WHERE code='$del_cat'";
      my $sth=$dbh->prepare($query);
      infobox ("Success","Category $del_cat has been deleted.\n\nYou will need to restart Mr. Voice after\nyou finish deleting categories.") if ($sth->execute);
      $status = "Deleted category";
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

}

sub edit_song
{

}

sub delete_song
{
  my $id = get_song_id();
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
        infobox("File Deletion Error","Could not delete file $filepath$filename from the disk\n\nEntry was removed from the database") unless ( unlink("$filepath$filename") );
      }
      infobox("Song Deleted","Deleted song with ID $id");
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
  infobox("About Mr. Voice","Mr. Voice Version $version\n\nBy H. Wade Minter <minter\@lunenburg.org>");
}

#sub show_predefined_hotkeys
#{
#      $box = $mw->DialogBox(-title=>"Predefined Hotkeys", -buttons=>["Close"]);
#      $box->add("Label",-text=>"The following hotkeys are always available\nand may not be changed")->pack();
#      $box->add("Label",-text=>"<Escape> - Stop the currently playing MP3")->pack();
#      $box->add("Label",-text=>"<Enter> - Perform the currently entered search")->pack();
#      $box->add("Label",-text=>"<ALT-t> - The \"Ta-Da\" MIDI")->pack();
#      $box->add("Label",-text=>"<ALT-y> - The \"You're Out\" MIDI")->pack();
#      $box->add("Label",-text=>"<ALT-b> - The Brown Bag MIDI")->pack();
#      $box->add("Label",-text=>"<ALT-v> - The Price Is Right theme (Volunteer photos)")->pack();
#      $box->Show;
#}

sub clear_hotkeys
{
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

sub list_hotkeys
{
  $hotkeysbox=$mw->Toplevel();
  $hotkeysbox->title("Hotkeys");
  $hotkeysbox->Label(-text=>"Currently defined hotkeys:")->pack;
  $hotkeysbox->Checkbutton(-text=>"F1:",
                           -variable=>\$f1_cb)->pack();
  $hotkeysbox->Label(-textvariable=>\$f1)->pack();
  $hotkeysbox->Checkbutton(-text=>"F2:",
                           -variable=>\$f2_cb)->pack();
  $hotkeysbox->Label(-textvariable=>\$f2)->pack();
  $hotkeysbox->Checkbutton(-text=>"F3:",
                           -variable=>\$f3_cb)->pack();
  $hotkeysbox->Label(-textvariable=>\$f3)->pack();
  $hotkeysbox->Checkbutton(-text=>"F4:",
                           -variable=>\$f4_cb)->pack();
  $hotkeysbox->Label(-textvariable=>\$f4)->pack();
  $hotkeysbox->Checkbutton(-text=>"F5:",
                           -variable=>\$f5_cb)->pack();
  $hotkeysbox->Label(-textvariable=>\$f5)->pack();
  $hotkeysbox->Checkbutton(-text=>"F6:",
                           -variable=>\$f6_cb)->pack();
  $hotkeysbox->Label(-textvariable=>\$f6)->pack();
  $hotkeysbox->Checkbutton(-text=>"F7:",
                           -variable=>\$f7_cb)->pack();
  $hotkeysbox->Label(-textvariable=>\$f7)->pack();
  $hotkeysbox->Checkbutton(-text=>"F8:",
                           -variable=>\$f8_cb)->pack();
  $hotkeysbox->Label(-textvariable=>\$f8)->pack();
  $hotkeysbox->Checkbutton(-text=>"F9:",
                           -variable=>\$f9_cb)->pack();
  $hotkeysbox->Label(-textvariable=>\$f9)->pack();
  $hotkeysbox->Checkbutton(-text=>"F10:",
                           -variable=>\$f10_cb)->pack();
  $hotkeysbox->Label(-textvariable=>\$f10)->pack();
  $hotkeysbox->Checkbutton(-text=>"F11:",
                           -variable=>\$f11_cb)->pack();
  $hotkeysbox->Label(-textvariable=>\$f11)->pack();
  $hotkeysbox->Checkbutton(-text=>"F12:",
                           -variable=>\$f12_cb)->pack();
  $hotkeysbox->Label(-textvariable=>\$f12)->pack();
  $hotkeysbox->Button(-text=>"Close",
                      -command=>sub { $hotkeysbox->destroy})->pack(-side=>'left');
  $hotkeysbox->Button(-text=>"Clear Selected",
                      -command=>[\&clear_selected])->pack(-side=>'right');
}

sub get_song_id
{
  @list = $mainbox->curselection();
  my $selection = $mainbox->get($list['end']);
  my ($id) = split /:/,$selection;
  return ($id);
}

sub set_hotkey
{
  #@list = $mainbox->curselection();
  my $id = get_song_id;

  if (! Exists($hotkeybox))
  {
    $hotkeybox = $mw->Toplevel();
    $hotkeybox->title("Bind hotkeys");
    $hotkeybox->Label(-text=>"Choose the keys to bind the song:")->pack();
    $hotkeybox->Label(-textvariable=>\$selection)->pack();
    $hotkeybox->Checkbutton(-text=>"F1",
                            -variable=>\$f1_cb)->pack();
    $hotkeybox->Checkbutton(-text=>"F2",
                            -variable=>\$f2_cb)->pack();
    $hotkeybox->Checkbutton(-text=>"F3",
                            -variable=>\$f3_cb)->pack();
    $hotkeybox->Checkbutton(-text=>"F4",
                            -variable=>\$f4_cb)->pack();
    $hotkeybox->Checkbutton(-text=>"F5",
                            -variable=>\$f5_cb)->pack();
    $hotkeybox->Checkbutton(-text=>"F6",
                            -variable=>\$f6_cb)->pack();
    $hotkeybox->Checkbutton(-text=>"F7",
                            -variable=>\$f7_cb)->pack();
    $hotkeybox->Checkbutton(-text=>"F8",
                            -variable=>\$f8_cb)->pack();
    $hotkeybox->Checkbutton(-text=>"F9",
                            -variable=>\$f9_cb)->pack();
    $hotkeybox->Checkbutton(-text=>"F10",
                            -variable=>\$f10_cb)->pack();
    $hotkeybox->Checkbutton(-text=>"F11",
                            -variable=>\$f11_cb)->pack();
    $hotkeybox->Checkbutton(-text=>"F12",
                            -variable=>\$f12_cb)->pack();
    $hotkeybox->Button(-text=>"Apply",
                       -command=>[\&do_hotkey,"$id"])->pack(-side=>'left');
    $hotkeybox->Button(-text=>"Cancel",
                       -command=> sub { $hotkeybox->withdraw(); })->pack(-side=>'right');
  }
  else
  {
    $hotkeybox->deiconify();
    $hotkeybox->raise();
  }
}

sub do_hotkey
{
  # Do the actual assignment of the hotkey in this function.  We only 
  # have the file ID number, so we have to get the filename from that.
  my $id = $_[0];
  my $query = "SELECT filename FROM mrvoice WHERE id=$id";
  my $sth=$dbh->prepare($query);
  $sth->execute or die "can't execute the query: $DBI::errstr\n";
  @result = $sth->fetchrow_array;
  $sth->finish;
  $filename = $result[0];
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
  $hotkeybox->destroy;
  $status = "Hotkey assigned";
}

sub stop_mp3
{
  system ("$mp3player --stop");
  $status = "Playing Stopped";
}

sub play_mp3 
{
  # See if the request is coming from one our hotkeys first...
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
#  elsif ($_[1] eq "ALT-T") { $filename = $altt; }
#  elsif ($_[1] eq "ALT-Y") { $filename = $alty; }
#  elsif ($_[1] eq "ALT-B") { $filename = $altb; }
#  elsif ($_[1] eq "ALT-G") { $filename = $altg; }
#  elsif ($_[1] eq "ALT-V") { $filename = $altv; }
  else
  {
    # If not, find the selected song.
    #@list = $mainbox->curselection();
    my $id = get_song_id;
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
    system ("$mp3player --play $filepath$filename");
  }
}

sub do_search
{
  $status="Starting search";
  $mainbox->delete(0,'end');
  $query = "SELECT mrvoice.id,categories.description,mrvoice.info,mrvoice.artist,mrvoice.title,mrvoice.filename from mrvoice,categories where mrvoice.category=categories.code ";
  $query = $query . "AND category='$category' " if ($category ne "Any");
  if ($anyfield)
  {
    $query = $query . "AND ( info LIKE '%$anyfield%' OR title LIKE '%$anyfield%' OR artist LIKE '%$anyfield%')";
  }
  else
  {
    $query = $query . "AND info LIKE '%$cattext%' " if ($cattext);
    $query = $query . "AND title LIKE '%$title%' " if ($title);
    $query = $query . "AND artist LIKE '%$artist%' " if ($artist);
    $query = $query . "ORDER BY category,info,title";
  }
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
  $sth->finish;
  $cattext="";
  $title="";
  $artist="";
  $anyfield="";
  $category="Any";
  $status="Displaying search results";
}

sub do_exit
{
 $dbh->disconnect;
 close (XMMS);
 exit;
} 

#########
# MAIN PROGRAM
#########

$dbh = DBI->connect("DBI:mysql:$db_name",$db_username,$db_pass) or die "Couldn't connect to database: $DBI::errstr\n";
# We use the following statement to open the MP3 player asynchronously
# when the Mr. Voice app starts.
open (XMMS,"$mp3player|");

$mw = MainWindow->new;
$mw->geometry("+0+0");
$mw->title("Mr. Voice");
$mw->minsize(68,10);
$menuframe=$mw->Frame(-relief=>'ridge',
                      -borderwidth=>2)->pack(-side=>'top',
                                            -fill=>'x',
                                            -anchor=>'n',
                                            -expand=>0);
$filemenu = $menuframe->Menubutton(-text=>"File",
                                   -tearoff=>0)->pack(-side=>'left');
$filemenu->AddItems(["command"=>"Open Hotkey File",
                    -command=>\&open_file]); 
$filemenu->AddItems(["command"=>"Save Hotkeys To A File",
                    -command=>\&save_file]); 
$filemenu->AddItems("-");
$filemenu->AddItems(["command"=>"Exit", 
                     -command=>sub { 
                                     $dbh->disconnect;
                                      exit;
                                    }]);
$hotmenu = $menuframe->Menubutton(-text=>"Hotkeys",
                                  -tearoff=>0)->pack(-side=>'left');
$hotmenu->AddItems(["command"=>"Show Hotkeys",
                    -command=>\&list_hotkeys]);
$hotmenu->AddItems(["command"=>"Clear All Hotkeys",
                    -command=>\&clear_hotkeys]);
#$hotmenu->AddItems(["command"=>"Show Predefined Hotkeys",
#                    -command=>\&show_predefined_hotkeys]);
$catmenu = $menuframe->Menubutton(-text=>"Categories",
                                  -tearoff=>0)->pack(-side=>'left');
$catmenu->AddItems(["command"=>"Add Category",
                   -command=>\&add_category]);
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

$catmenu=$searchframe->Menubutton(-text=>"Choose Category",
                                  -relief=>'raised',
                                  -indicatoron=>1)->pack(-side=>'left',
                                                         -anchor=>'n');
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
$searchframe->Label(-text=>"where extra info contains ")->pack(-side=>'left',
                                                               -anchor=>'n');
$searchframe->Entry(-textvariable=>\$cattext)->pack(-side=>'left',
                                                    -anchor=>'n');
#
######

#####
# Artist
$searchframe2=$mw->Frame()->pack(-side=>'top',
                                 -fill=>'x',
                                 -anchor=>'n');
$searchframe2->Label(-text=>"Artist contains ")->pack(-side=>'left');
$searchframe2->Entry(-textvariable=>\$artist)->pack(-side=>'left');
#
#####

#####
# Title
$searchframe3=$mw->Frame()->pack(-side=>'top',
                                -fill=>'x');
$searchframe3->Label(-text=>"Title contains   ")->pack(-side=>'left');
$searchframe3->Entry(-textvariable=>\$title)->pack(-side=>'left');
#
#####

#####
# Title
$searchframe4=$mw->Frame()->pack(-side=>'top',
                                -fill=>'x');
$searchframe4->Label(-text=>"OR any field contains   ")->pack(-side=>'left');
$searchframe4->Entry(-textvariable=>\$anyfield)->pack(-side=>'left');
#
#####

#####
# Search Button
$mw->Button(-text=>"Do Search",
            -command=>\&do_search)->pack();
#
#####

#####
# Main display area - search results
$mainbox=$mw->Scrolled('Listbox',
                       -scrollbars=>'osoe',
                       -width=>100,
                       -setgrid=>1,
                       -selectmode=>"single")->pack(-fill=>'both',
                                                    -expand=>1,
                                                    -side=>'top');
$mainbox->bind("<Double-Button-1>", \&play_mp3);
#
#####

$mw->Button(-text=>"Play now",
            -command=>[\&play_mp3,"play"])->pack(-side=>'left');
$mw->Button(-text=>"Stop now",
            -command=>[\&stop_mp3])->pack(-side=>'left');
$mw->Button(-text=>"Assign Hotkey",
            -command=>[\&set_hotkey])->pack(-side=>'right');

$mw->Label(-textvariable=>\$status)->pack(-side=>'bottom');

#####
# Bind hotkeys
$mw->bind("<Key-F1>", [\&play_mp3,"F1"]);
$mw->bind("<Key-F2>", [\&play_mp3,"F2"]);
$mw->bind("<Key-F3>", [\&play_mp3,"F3"]);
$mw->bind("<Key-F4>", [\&play_mp3,"F4"]);
$mw->bind("<Key-F5>", [\&play_mp3,"F5"]);
$mw->bind("<Key-F6>", [\&play_mp3,"F6"]);
$mw->bind("<Key-F7>", [\&play_mp3,"F7"]);
$mw->bind("<Key-F8>", [\&play_mp3,"F8"]);
$mw->bind("<Key-F9>", [\&play_mp3,"F9"]);
$mw->bind("<Key-F10>", [\&play_mp3,"F10"]);
$mw->bind("<Key-F11>", [\&play_mp3,"F11"]);
$mw->bind("<Key-F12>", [\&play_mp3,"F12"]);
$mw->bind("<Key-Return>", [\&do_search]);
$mw->bind("<Key-Escape>", [\&stop_mp3]);
#$mw->bind("<Alt-Key-t>", [\&play_mp3,"ALT-T"]);
#$mw->bind("<Alt-Key-y>", [\&play_mp3,"ALT-Y"]);
#$mw->bind("<Alt-Key-b>", [\&play_mp3,"ALT-B"]);
#$mw->bind("<Alt-Key-g>", [\&play_mp3,"ALT-G"]);
#$mw->bind("<Alt-Key-v>", [\&play_mp3,"ALT-V"]);
#
#####

if (! -x $mp3player)
{
  $box = $mw->DialogBox(-title=>"Warning - MP3 player not found", -buttons=>["OK"]);
  $box->add("Label",-text=>"Warning - Could not execute your defined MP3 player:")->pack();
  $box->add("Label",-text=>"$mp3player")->pack();
  $box->add("Label",-text=>"You may need to edit the mp3player variable at the top of mrvoice.pl")->pack();
  $box->Show;
}

MainLoop;
