#!/usr/bin/perl
use warnings;
use strict;
use CPAN;

# Subversion Id: $Id$
# Used to see if the modules that Mr. Voice requires are up-to-date on a
# given host.
# Cribbed from http://netfactory.dk/technology/perl/misc/

my @mods =
  qw(DBI DBD::SQLite MPEG::MP3Info MP4::Info Audio::Wav Date::Manip Time::Local Time::HiRes Ogg::Vorbis::Header::PurePerl Tk Tk::ProgressBar::Mac Getopt::Long Cwd File::Temp XMLRPC::Lite Digest::MD5 MIME::Base64);

push(
    @mods,
    qw/LWP::UserAgent HTTP::Request Win32::Process Win32::FileOp Audio::WMA/
  )
  if ( $^O eq "MSWin32" );
push( @mods, "Mac::AppleScript" ) if ( $^O eq "darwin" );

my $count = 0;

# list all modules on my disk that have newer versions on CPAN
for my $module (@mods)
{
    my $mod = CPAN::Shell->expand( "Module", $module );
    next unless $mod->inst_file;
    next if $mod->uptodate;
    printf "Module %s is installed as %s, could be updated to %s from CPAN\n",
      $mod->id, $mod->inst_version, $mod->cpan_version;
    $count++;
}

print "No Mr. Voice modules need upgrades!\n" if ( $count == 0 );
