#!/usr/bin/perl
# NAME: orphans.pl
# DESCRIPTION: A little tool to identify or delete "orphaned" Mr. Voice
#              files (files that exist on disk but are not referenced 
#              in the database.
# CVS ID: $Id: orphans.pl,v 1.2 2003/04/09 14:01:16 minter Exp $

use DBI;
use DBD::mysql;
use File::Basename;
use File::Glob qw(:globally :nocase);
use Carp::Heavy;
use Getopt::Std;

getopts('dhv');

if ($opt_h)
{
  print "USAGE: orphans.pl [-v] [-d] [-h]\n";
  print "       -d     Also delete files from disk (default just prints report)\n";
  print "       -v     Be verbose about what you're doing\n";
  print "       -h     Prints this help message\n";
  exit 0;
}

# Source variables from the config file
# Check to see if we're on Windows or Linux, and set the RC file accordingly.
if ("$^O" eq "MSWin32")
{
  $rcfile = "C:/mrvoice.cfg";
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
    ($var1,$var2) = split(/::/);
    $$var1=$var2;
    print "-->$var1 is $var2\n" if ($opt_v);
  }
  close (RCFILE);
}
else
{
  print "Config file $rcfile not found - you need to run Mr. Voice and\n";
  print "create one before using orphans.pl\n";
  print "Exiting now...\n";
  exit 1;
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


$dbh = DBI->connect("DBI:mysql:$db_name",$db_username,$db_pass) or die ("Could not connect to database.  Exiting...");
print "-->Connected to database\n" if ( ($dbh) && ($opt_v) );

@files = glob("$filepath/*.mp3") or die;

foreach $file (@files)
{
  $file = basename($file);
  my $query = "SELECT * FROM mrvoice WHERE filename='$file'";
  $rv = $dbh->do($query);
  if ($rv == 0)
  {
    print "$file is an orphan.";
    if ($opt_d)
    {
      print "..Deleting the file.";
      if (unlink ("$filepath/$file"))
      {
        print "..Deleted\n";
      }
      else
      {
        print "..FAILED\n";
      }
    }
    else
    {
      print "\n";
    }
  }
}

print "-->Finishing successfully!\n" if ($opt_v);
