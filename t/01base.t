#!/usr/bin/perl

use strict;
BEGIN {
	push( @INC, qw(./lib ../lib) );
}
use vars qw/$rv/;
use Test::Simple tests => 20;
use Chatbot::TalkerBot;

# did it load
ok( defined $Chatbot::TalkerBot::VERSION );
$Chatbot::TalkerBot::TRACING = 0;
$Chatbot::TalkerBot::LOGGING = 0;

# use some mucking about to make something that behaves enough like an IO::Socket object
# we only use <> and ->print internally
my $handle = bless( \*DATA, 'fauxhandle' );

my $talker = new Chatbot::TalkerBot( $handle , {
	Username => 'bot', Password => 'bot',
	UsernamePrompt => 'enter your USERNAME', PasswordPrompt => 'enter your PASSWORD',
	UsernameResponse => '<USER>', PasswordResponse => '<PASS>',
	LoginSuccess => 'Login successful!', LoginFail => 'Login fail!'
} );

ok( defined $talker );

# define the authentication stuff - password is 'pass'
$talker->setAuthentication( 'pauONM/HSu9pM', { pkent => 1, john => 1 });

# try saying some stuff - all these commands are very similar so we only need test a few
$talker->say('fzzk');
ok( $rv eq "fzzk\n");

$talker->shout('fzzk');
ok( $rv eq "! fzzk\n");

# try listening
$rv = $talker->listenOnce;
ok( $rv eq 'john    :well I never said that' );

$rv = $talker->listenOnce;
ok( $rv eq 'vickyc  >hello bot' );

# pretend to change the terminal
$talker->chant('.set term client');
ok( $rv eq ".set term client\n");

$rv = $talker->listenOnce;
ok( $rv eq 'DONE terminal type set to client' );

# go into our pretend listening loop
my @calls = ();
$talker->listenLoop( qr/^TELL (\w+)\s*>(.+)$/, \&callback );

ok( @calls == 7 );
ok( $calls[0]{'person'} eq 'vickyc' );
ok( $calls[1]{'person'} eq 'john' );
ok( $calls[0]{'command'} eq 'hello' );
ok( $calls[1]{'command'} eq 'flipper' );
ok( $calls[6]{'command'} eq 'quitself' );

# we've been told to quit now
$talker->quit;
ok( $rv eq ".quit\n");

$rv = $talker->listenOnce;
ok( $rv eq 'Bye!' );

# end of normal ops test

sub callback {
	my ($talker, $person, $command, @args) = @_;
	push( @calls, {person => $person, command => $command});
	
	# try out variations on authenticating
	if ($command eq 'authtest') {
		my $pass = $args[0];
		ok( $talker->authenticate( $pass ) );
	} elsif ($command eq 'authtest2') {
		my $pass = $args[0];
		ok( $talker->authenticate( $pass, $person ) );
	} elsif ($command eq 'authtest3') {
		my $pass = $args[0];
		ok( ! $talker->authenticate( $pass, $person ) );
	} elsif ($command eq 'quitself') {
		return 1;
	}
	
	return 0;
}

package fauxhandle;

sub print {
	my $self = shift;
	my $msg = shift;
	$main::rv = $msg;
	return $msg;
}

package main;

__DATA__
Welcome to the Data Chunk Talker
Normal restrictions apply!
Please enter your USERNAME
Please enter your PASSWORD
Login successful!
john    :well I never said that
vickyc  >hello bot
DONE terminal type set to client
TELL vickyc  >hello bot
TELL john    >flipper bot
TELL john    >authtest pass
TELL john    >authtest2 bad
TELL DrEvil  >authtest3 bad
TELL DrEvil  >authtest pass
TELL piers   >quitself
Bye!