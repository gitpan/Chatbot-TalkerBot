#!/usr/bin/perl

use strict;
BEGIN {
	push( @INC, qw(./lib ../lib) );
}
use vars qw/$rv/;
use Test::Simple tests => 7;
use Chatbot::TalkerBotCommands;

# did it load
ok( defined $Chatbot::TalkerBotCommands::VERSION );

# make an object
my $handler = new Chatbot::TalkerBotCommands;
ok( defined $handler );

# check this method
ok( $handler->isCommand('help') );
ok( $handler->isCommand('die') );
ok( ! $handler->isCommand('foo') );

$handler->installCommandHelp( 'baz', ['line1', 'line2'] );

ok( $handler->{'ExternalHelp'}->{'baz'}->[0] eq 'line1' );
ok( $handler->{'ExternalHelp'}->{'baz'}->[1] eq 'line2' );
