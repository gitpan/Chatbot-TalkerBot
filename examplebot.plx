#!/usr/bin/perl

use strict;
use lib './lib';
use Getopt::Std;
use Chatbot::TalkerBot;
import Chatbot::TalkerBot qw/TB_LOG TB_TRACE/;
use Data::Dumper;

BEGIN {
	require './examplebot.cfg';
}

use vars qw/$opt_u $opt_p $opt_h $opt_t
$user $pass $host $port
$firehost $fireport $fireprompt $firecommand
$USEFIREWALL $socket $talkmatch $cfg %vars
$TALK_HOST $TALK_PORT
$FIRE_PORT $FIRE_HOST $FIRE_PROMPT $FIRE_COMMAND
$TALK_USER_PROMPT $TALK_USER_RESPONSE $TALK_PASS_PROMPT $TALK_PASS_RESPONSE $TALK_OK $TALK_FAIL
$TRACING %COMMAND_LUT
/;

### INITIALIZATION #########################################
%COMMAND_LUT = (
	'dump' => \&_dump,
);
$TRACING = 1;

banner();

# before we do anything, populate the assorted variables from the config file
readconfig();

# for safety, only give ourselves a short time to log in
alarm(10);
$SIG{'ALRM'} = sub { die("examplebot - Alarm Caught - Login took too long"); };
$SIG{'INT'} = sub { die("examplebot - Interrupt Caught"); };

# command line and package globals
getopts('u:p:h:t');
TB_LOG("Command line options: <$opt_u> <$opt_p> <$opt_h> <$opt_t>");
$Chatbot::TalkerBot::TRACING = 1 if ($opt_t || $TRACING);

# we must know this much - command line overrides globals
$user = $opt_u || $user || die("examplebot - We need a username");
$pass = $opt_p || $pass || die("examplebot - We need a password");

# figure out where we're connecting
($host, $port) = determine_remote_host( $opt_h );
TB_LOG("Connecting to <$host>:<$port> as <$user>:<$pass>...");

### CONNECTION #########################################

# firewall options
if ($USEFIREWALL) {
	TB_LOG("...through firewall/proxy <$FIRE_HOST>:<$FIRE_PORT>");
	$socket = connect_through_firewall( $FIRE_HOST, $FIRE_PORT, $FIRE_PROMPT, $FIRE_COMMAND, $host, $port );
} else {
	TB_LOG("...directly");
	$socket = connect_directly( $host, $port );
}

# now we've connected to the talker host, we need to log in
my $talker = new Chatbot::TalkerBot( $socket, 
	{
		Username => $user,
		UsernameResponse => $TALK_USER_RESPONSE, 
		UsernamePrompt => $TALK_USER_PROMPT,
		Password => $pass,
		PasswordPrompt => $TALK_PASS_PROMPT,
		PasswordResponse => $TALK_PASS_RESPONSE,
		LoginSuccess => $TALK_OK,
		LoginFail => $TALK_FAIL
	}
);
configure_commands();
$talker->setTalkerCommands( $vars{'bot'}{'Commands'} );
$talker->setAuthentication( $vars{'bot'}{'Admin'}{'Password'}, { map {$_ => 1} @{$vars{'bot'}{'Admin'}{'Group'}} } );
$talker->setTalkerCommands( $vars{'bot'}{'Commands'} );

# we've logged in, so kill the alarm
alarm(0);
$0 = 'ExampleBot CONNECTED';
TB_LOG("LOG OUTPUT");
TB_TRACE("TRACE OUTPUT");

### EVENT LOOP #########################################

if ( $vars{'bot'}->{'onLogin'} ) {
	$talker->say( @{$vars{'bot'}->{'onLogin'}} );
}

$talker->listenLoop( $talkmatch, \&callback, 10);
if ( $vars{'bot'}->{'onLogout'} ) {
	$talker->say( @{$vars{'bot'}->{'onLogout'}} );
}
TB_LOG("examplebot - closing down");

$talker->quit;
sleep(1);
exit;

### SUBROUTINES #########################################

sub banner {
	print q{
#####################################################################

examplebot

If this is the first run you'll probably want to kill this program and
edit the config file - examplebot.cfg - which is in a very easy format.
You'll also need a talker running at the location given in the config 
file - default is localhost:5000.

Please read the POD inside this file. Please read the README, which
contains the POD converted to text for the modules that power this
bot.

Sleeping for a few seconds...
};

sleep(3);

print q{
Let's try connecting then!
#####################################################################
};
}

sub readconfig {
	%vars = %$VAR1;	
	TB_LOG( 'Config file read in successfully' );
	
	# populate global variables from config
	$user = $vars{'talker'}->{'username'};
	$pass = $vars{'talker'}->{'password'};
	$talkmatch = qr/$vars{'talker'}->{'trigger'}/;
	
	$TALK_USER_PROMPT = $vars{'talker'}->{'usernameprompt'};
	$TALK_USER_RESPONSE = $vars{'talker'}->{'usernameresponse'};
	$TALK_PASS_PROMPT = $vars{'talker'}->{'passwordprompt'};
	$TALK_PASS_RESPONSE = $vars{'talker'}->{'passwordresponse'};
	$TALK_OK = $vars{'talker'}->{'loginsuccess'};
	$TALK_FAIL = $vars{'talker'}->{'loginfail'};
	
	$TALK_HOST = $vars{'network'}->{'host'}->{'name'};
	$TALK_PORT = $vars{'network'}->{'host'}->{'port'};
	
	$FIRE_PORT = $vars{'network'}->{'firewall'}->{'port'};
	$FIRE_HOST = $vars{'network'}->{'firewall'}->{'name'};
	$FIRE_PROMPT = $vars{'network'}->{'firewall'}->{'prompt'};
	$FIRE_COMMAND = $vars{'network'}->{'firewall'}->{'command'};
	$USEFIREWALL = $vars{'network'}->{'firewall'}->{'use'};
	
	$TRACING = $vars{'bot'}->{'tracing'};	
}

sub configure_commands {
	TB_LOG( "Configuring external commands" );
	foreach my $command (keys %{$vars{'commands'}}) {
		TB_LOG( "Installing command $command" );
		$talker->installCommandHelp( $command, $vars{'commands'}->{$command}->{'help'} );
		
		if ( $vars{'commands'}->{$command}->{'external'} ) {
			TB_LOG( "...is an external command" );
			$COMMAND_LUT{ $command } = \&__shell;
		}
	}
}

sub determine_remote_host {
	my $switch = shift;
	my ($host, $port);
	
	if ($switch =~ m/^(.+):(\d+)$/) {
		$host = $1;
		$port = $2;
	} elsif ($switch =~ m/^(.+)$/) {
		$host = $1;
		$port = $TALK_PORT;
	} else {
		$host = $TALK_HOST;
		$port = $TALK_PORT;
	}
	
	return ($host, $port);
}

sub callback {
	my ($talker, $person, $command, @args) = @_;
	
	my $rv = 0;
	if ($person eq 'ALRM') {
		TB_TRACE( "Callback called as ALARM interrupt handler" );
		#add other interrupt-time stuff here
	} else {
		TB_TRACE( "Callback called with <$person> <$command>" );
		# interpret synchronous input as a command
		if ( _is_command( $command ) ) {
			$rv = _do_command( $talker, $person, $command, @args );
		} else {
			$talker->whisper( $person, "Sorry, unrecognized command. Try 'help'" );
			$rv = 0;
		}
	}
	return $rv;
}

sub _is_command {
	my $rv = 0;
	my $command = shift;
	TB_TRACE( "is $command external?" );
	if ( ref( $COMMAND_LUT{ $command } ) eq 'CODE' ) {
		$rv = 1;
	}
	return $rv;
}

sub _do_command {
	my $rv = 0;
	if ( ref( $COMMAND_LUT{ $_[2] } ) eq 'CODE' ) {
		TB_TRACE( "internal command $_[2] called" );
		$rv = $COMMAND_LUT{ $_[2] }->(@_);
	} else {
		TB_LOG( "WARNING: Somehow we tried to exec a nonexistent internal command $_[2]" );
	}
	return $rv;
}

sub _dump {
	my ( $talker, $person, $command, @args ) = @_;
	
	if ( $talker->authenticate( $args[0], $person ) ) {
		my @lines = map { ".$_" } split( /\n/, Dumper( $talker ) );
		$talker->whisper( $person, @lines );
	} else {
		$talker->whisper( $person, "Sorry, you are not allowed to execute this command");
	}
	return 0;
}

=head1 NAME

examplebot - an example implementation of a talker robot

=head1 SYNOPSIS

examplebot.plx [-t] [-u USER] [-p PASS] [-h HOST[:PORT]]

Additionally it expects to read the examplebot.cfg config file to determine other runtime options.
The command line options override those in the config file, or you can put all options in the
config file. The -t switch turns on tracing for extra fun debugging info.

=head1 DESCRIPTION

This robot draws upon the Chatbot::TalkerBot core - it uses TalkerBot to connect to the remote host
and then uses the listenLoop method to wait for input matching a regular expression.
Some commands are handled by the TalkerBot object itself, but anything that can't be handled is
passed to the callback function for further robot-application-specific processing.

In addition a regular interrupt is enabled which calls the callback at regular intervals to allow
for asynchronous I/O and housekeeping tasks.

=head1 CONFIGURATION

There's four sections - one for network details, one for the talker application, one for
the bot's configuration, and one for commands.

=head1 VERSION

$Id: examplebot.plx,v 1.7 2001/12/19 05:39:28 piers Exp $

=cut
