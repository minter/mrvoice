#!/usr/bin/perl
# $Id: quicksetup.pl,v 1.3 2003/09/01 22:21:15 minter Exp $

use warnings;
use DBI;
use Cwd;
use Win32::FileOp;

my $error = 0;

sub do_exit
{
  $exitcode = $_[0];
  print "\nPress Enter to exit.\n";
  my $exit = <STDIN>;
  exit($exitcode);
}
  
if ($^O ne "MSWin32")
{
  print "This utility can only be run on Windows systems\n";
  do_exit(1);
}

print <<EOF;
This utility will set up a fresh installation of Mr. Voice on your system.
Do not run this utility if you currently have a working Mr. Voice installation
on this system - bad things might happen!

If there are problems, feel free to email Wade at minter\@lunenburg.org

EOF
print "Continue with setup? [y/N] ";
my $choice = <STDIN>;
chomp ($choice);
unless ($choice =~ /^y/i)
{
  print "Setup cancelled\n";
  do_exit (1);
}

print "\n--> Checking for WinAmp and MySQL <--\n\n";
print "Checking for MySQL...";
if (-f 'C:/mysql/bin/mysql.exe')
{
  print "found at C:\\mysql\n";
}
else
{
  $error = 1;
  print "NOT FOUND at C:\\mysql\n";
}

print "Checking for WinAmp...";
if (-f 'C:/Program Files/Winamp/Winamp.exe')
{
  print "found at C:\\Program Files\\Winamp\\Winamp.exe\n";
}
else
{
  $error = 1;
  print "NOT FOUND at C:\\Program Files\\Winamp\\Winamp.exe\n";
}

if ($error == 1)
{
  print <<EOF;

One or more required components were not found in the expected locations.
Install and configure them first, then come back and run this utility again.

If you need to install them in a nonstandard location for some reason, you
will need to set up Mr. Voice manually according to the documentation.
EOF
  do_exit (2);
}

print "\n\n--> Setting up the database <--\n\n";
print "Connecting to the database with blank password...";
if (! ($dbh = DBI->connect("DBI:mysql:mysql","root","")))
{
  print "FAILED\n";
  print <<EOF;
Could not connect to the database with a blank superuser password. Have you 
perchance set up MySQL before?  If so, you will need to manually set up
Mr. Voice as described in the documentation - this quick setup script will
not work.
EOF
  do_exit (3);
}
else
{
  print "succeeded\n";
}

print "Setting a superuser password...";
if (! ($dbh->do("UPDATE user SET Password=password('mrvoice') WHERE User='root'")) )
{
  print "FAILED\n";
  print "Could not set the superuser password.  MySQL error follows:\n$DBI::errstr\n";
  do_exit (4);
}
else
{ 
  print "succeeded\n";
}

print "Creating the Mr. Voice database...";
if (! ($dbh->do("CREATE DATABASE mrvoice")) )
{
  print "FAILED\n";
  print "Could not create the database.  MySQL error follows:\n$DBI::errstr\n";
  do_exit (5);
}
else
{ 
  print "succeeded\n";
}

print "Creating the Mr. Voice DB user and granting...";
if (! ($dbh->do("GRANT ALL ON mrvoice.* TO mrvoice\@localhost IDENTIFIED BY 'mrvoice'")) )
{
  print "FAILED\n";
  print "Could not create the DB user.  MySQL error follows:\n$DBI::errstr\n";
  do_exit (6);
}
else
{ 
  print "succeeded\n";
  $dbh->do("FLUSH PRIVILEGES");
}

$dbh->disconnect;

print "Checking for Mr. Voice schema file...";
my $mrv_directory = Win32::GetShortPathName(getcwd);
my $path = File::Spec->catfile($mrv_directory,"dbinit.sql");
if (! -r $path )
{
  print "FAILED\n";
  print "Could not read the Mr. Voice schema file at $path\n";
  do_exit (8);
}
else
{ 
  print "succeeded\n";
}

$path =~ s/\\/\//g;
print "Loading the Mr. Voice schema...";
$result = `C:/mysql/bin/mysql -u mrvoice --password=mrvoice mrvoice < $path`;
if ($result ne "" )
{
  print "FAILED\n";
  print "Could not import Mr. Voice schema.  Error follows:\n$result\n";
  do_exit (9);
}
else
{ 
  print "succeeded\n";
}

print "\n\n--> Doing Filesystem work <--\n\n";
print "Creating default Mr. Voice directories...";
if (! mkdir("C:/mp3",0755) || ! mkdir("C:/hotkeys",0755) )
{
  print "FAILED\n";
  print "Could not create C:\\mp3 or C:\\hotkeys - please manually create these\ndirectories before running Mr. Voice\n";
}
else
{ 
  print "succeeded\n";
}

print "Writing Mr. Voice config file...";
open (OUTFILE,">C:/mrvoice.cfg") or die ("Could not open c:\\mrvoice.cfg for writing\n");
print OUTFILE <<EOF;
db_name::mrvoice
db_username::mrvoice
db_pass::mrvoice
filepath::c:/mp3
savedir::c:/hotkeys
mp3player::c:/progra~1/winamp/winamp.exe
savefile_max::4
httpq_pw::
EOF
print "succeeded\n";

print "\n\nHere is your Mr. Voice information - please save it for later reference.\n\n";
print "Superuser Password: mrvoice\n";
print "Database Username: mrvoice\n";
print "Database Password: mrvoice\n";
print "MP3 Directory: C:\\mp3\n";
print "Hotkey Directory: C:\\hotkeys\n";
print "\nYou can adjust non-password things by going to File->Preferences within\nMr. Voice\n";
print "At this point, Mr. Voice should be configured.  You may want to add the httpq\nplugin (if you haven't already) and set a password in the preferences.\nOtherwise, run mrvoice.exe and start Voicing!\n";
do_exit(0);
