#!/usr/bin/perl
# NAME: converthotkeys.pl
# DESCRIPTION: Converts hotkeys files in your save directory from pre-1.8
#              format to 1.8 format.
# SVN ID: $Id$

use DBI;
use DBD::mysql;
use File::Basename;
use File::Copy;
use File::Spec::Functions;
use File::Glob qw(:globally :nocase);
use Getopt::Std;
use Carp::Heavy;

getopts('hv');

if ($opt_h)
{
  print "USAGE: $0 [-v] [-h]\n";
  print "       -v     Be verbose about what you're doing\n";
  print "       -h     Prints this help message\n";
  exit 0;
}

# Source variables from the config file
# Check to see if we're on Windows or Linux, and set the RC file accordingly.
if ("$^O" eq "MSWin32")
{
  $rcfile = "C:\\mrvoice.cfg";
}
else
{
  my $homedir = "~";
  $homedir =~ s{ ^ ~ ( [^/]* ) }
              { $1
                   ? (getpwnam($1))[7]
                   : ( $ENV{HOME} || $ENV{LOGDIR}
                        || (getpwuid($>))[7]
                     )
              }ex;
  $rcfile = "$homedir/.mrvoicerc";
}
print "-->Setting config file to $rcfile\n" if ($opt_v);

# Opens the configuration file, of the form var_name::value, and assigns
# the value to the variable name.
# On MS Windows, it also converts long pathnames to short ones.

if (-r $rcfile)
{
  open (RCFILE,$rcfile);
  while (<RCFILE>)
  {
    chomp;
    my ($var1,$var2) = split(/::/);
    $$var1=$var2;
    print "-->$var1 is $var2\n" if ($opt_v);
  }
  close (RCFILE);
}
else
{
  print "Config file $rcfile not found - you need to run Mr. Voice and\n";
  print "create one before using $0\n";
  print "Exiting now...\n";
  exit 1;
}
if ($^O eq "MSWin32")
{
  $savedir = Win32::GetShortPathName($savedir);
}

my $dbh = DBI->connect("DBI:mysql:$db_name",$db_username,$db_pass) or die ("Could not connect to database.  Exiting...");
print "-->Connected to database\n" if ( ($dbh) && ($opt_v) );

my @files = glob( catfile($savedir, "*.mrv") ) or die "ERROR: No .mrv files in $savedir to convert!";

foreach my $hotkeyfile (@files)
{
  my %fkeys;
  print "Converting hotkey file $hotkeyfile\n";

  # Backup hotkey file
  copy ($hotkeyfile, "$hotkeyfile.bak");

  open (HOTKEYFILE, $hotkeyfile);
  while (my $line = <HOTKEYFILE>)
  {
    chomp ($line);
    my ($fkey,$file) = split (/::/, $line);
    if ($file)
    {
      my $query = "SELECT id FROM mrvoice WHERE filename='$file'";
      my $sth=$dbh->prepare($query);
      $sth->execute or die "can't execute the query: $DBI::errstr\n";
      my @table_row = $sth->fetchrow_array;
      $sth->finish;
      print "-->The id for $fkey is $table_row[0]\n" if ($opt_v);
      if ($table_row[0])
      {
        $fkeys{$fkey}=$table_row[0];
      }
      else
      {
        print "NOTE: The hotkey $fkey ($file) was not found in the database, so it will not be converted.  Check to make sure that either the file has not bee renamed, or if the song is still valid in your database.\n";
      }
    }
  }
  close (HOTKEYFILE);
  open (HOTKEYFILE, ">$hotkeyfile");
  print HOTKEYFILE "f1::$fkeys{f1}\n";
  print HOTKEYFILE "f2::$fkeys{f2}\n";
  print HOTKEYFILE "f3::$fkeys{f3}\n";
  print HOTKEYFILE "f4::$fkeys{f4}\n";
  print HOTKEYFILE "f5::$fkeys{f5}\n";
  print HOTKEYFILE "f6::$fkeys{f6}\n";
  print HOTKEYFILE "f7::$fkeys{f7}\n";
  print HOTKEYFILE "f8::$fkeys{f8}\n";
  print HOTKEYFILE "f9::$fkeys{f9}\n";
  print HOTKEYFILE "f10::$fkeys{f10}\n";
  print HOTKEYFILE "f11::$fkeys{f11}\n";
  print HOTKEYFILE "f12::$fkeys{f12}\n";

  close (HOTKEYFILE);
  $dbh->disconnect;
  print "Conversion done.\n\n";
}

print "Finishing successfully!\n";
