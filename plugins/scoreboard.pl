#!/usr/bin/perl

# SVN ID: $Id$

use warnings;
use strict;

my $title = "Mr. Voice Scorekeeper Plugin";

our $pluginmenu;
our $menubar;
our $mw;
our $icon;

if ( !$pluginmenu )
{
    $pluginmenu = $menubar->cascade(
        -label   => 'Plugins',
        -tearoff => 0
    );
}

my $menu = $pluginmenu->cget( -menu );
$menu->add(
    'command',
    -label   => 'Scoreboard',
    -command => \&scoreboard_plugin
);

sub scoreboard_plugin
{
    our $vis_score  = defined($vis_score)  ? $vis_score  : 0;
    our $home_score = defined($home_score) ? $home_score : 0;
    my $scoreboard = $mw->Toplevel( -title => $title );
    bind_hotkeys($scoreboard);
    $scoreboard->Button(
        -text    => 'Close',
        -command => sub { $scoreboard->destroy }
    )->pack( -side => 'bottom' );
    $scoreboard->withdraw();
    $scoreboard->minsize( 45, 2 );
    $scoreboard->Icon( -image => $icon );
    my $vis_side  = $scoreboard->Frame()->pack( -side => 'left',  -padx => 5 );
    my $home_side = $scoreboard->Frame()->pack( -side => 'right', -padx => 5 );
    $vis_side->Label( -text         => 'Visitor' )->pack( -side   => 'top' );
    $vis_side->Label( -textvariable => \$vis_score )->pack( -side => 'top' );
    my $vis_plus = $vis_side->Frame()->pack( -side => 'top' );
    $vis_plus->Button( -text => '+1', -command => sub { $vis_score += 1 } )
      ->pack( -side => 'left' );
    $vis_plus->Button( -text => '+5', -command => sub { $vis_score += 5 } )
      ->pack( -side => 'left' );
    $vis_plus->Button( -text => '+10', -command => sub { $vis_score += 10 } )
      ->pack( -side => 'left' );
    my $vis_minus = $vis_side->Frame()->pack( -side => 'top' );
    $vis_minus->Button( -text => '-1', -command => sub { $vis_score -= 1 } )
      ->pack( -side => 'left' );
    $vis_minus->Button( -text => '-5', -command => sub { $vis_score -= 5 } )
      ->pack( -side => 'left' );
    $vis_minus->Button( -text => '-10', -command => sub { $vis_score -= 10 } )
      ->pack( -side => 'left' );

    $home_side->Label( -text         => 'Home' )->pack( -side       => 'top' );
    $home_side->Label( -textvariable => \$home_score )->pack( -side => 'top' );
    my $home_plus = $home_side->Frame()->pack( -side => 'top' );
    $home_plus->Button( -text => '+1', -command => sub { $home_score += 1 } )
      ->pack( -side => 'left' );
    $home_plus->Button( -text => '+5', -command => sub { $home_score += 5 } )
      ->pack( -side => 'left' );
    $home_plus->Button( -text => '+10', -command => sub { $home_score += 10 } )
      ->pack( -side => 'left' );
    my $home_minus = $home_side->Frame()->pack( -side => 'top' );
    $home_minus->Button( -text => '-1', -command => sub { $home_score -= 1 } )
      ->pack( -side => 'left' );
    $home_minus->Button( -text => '-5', -command => sub { $home_score -= 5 } )
      ->pack( -side => 'left' );
    $home_minus->Button(
        -text    => '-10',
        -command => sub { $home_score -= 10 }
    )->pack( -side => 'left' );

    $scoreboard->update();
    $scoreboard->deiconify();
    $scoreboard->raise();
}

1;
