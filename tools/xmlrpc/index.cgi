#!/usr/bin/perl -T

# SVN ID: $Id$

#use warnings;
use strict;

#use diagnostics;

use lib '/home/minter/perllib';

use XMLRPC::Transport::HTTP;
use MrVoice::XMLRPC::Server;

BEGIN
{
    no strict 'refs';
    for my $method
      qw(check_upload upload_song search_songs download_song get_people get_categories check_version)
    {
        *$method = "MrVoice::XMLRPC::Server::$method";
    }
}

my $server = XMLRPC::Transport::HTTP::CGI->dispatch_to(
    qw(check_upload upload_song search_songs download_song get_people get_categories check_version)
)->handle;

