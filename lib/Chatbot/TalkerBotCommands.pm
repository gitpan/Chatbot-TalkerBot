package Chatbot::TalkerBotCommands;

use vars qw($VERSION %COMMAND_LUT %HELP);

($VERSION) = ('$Revision: 1.4 $' =~ /([\d\.]+)/);

# internal commands lookup table
%COMMAND_LUT = (
	'help' => \&_help,
	'version' => \&_version,
	'process' => \&_process,
	'die' => \&_die,
	'echo' => \&_echo,
);

# this hash contains help strings for internal commands
%HELP = (
	'' => [
		'This is the TalkerBot internal help system!',
		'Try telling me "help commands" for a list of all commands.',
		'For help on a specific command tell me "help <command>"' ],
	'_default' => [
		'Sorry, no help for that command... try "help commands"'],
	'help' => [
		'Syntax: help <command>',
		'Access Help Information'],
	'version' => [
		'Syntax: version',
		'Displays the version info and some stats'],
	'process' => [
		'Syntax: process',
		'Tells you about the TalkerBot process, e.g. memory usage'],
	'die' => [
		'Syntax: die <password>',
		'Forces the robot to exit'],
	'echo' => [
		'Syntax: echo <password> <text>',
		'Forces the robot to utter something'],
);

### OBJECT INTERFACE

sub new {
	my $class = shift;
	
	my $self = {
		version => $VERSION,
		ExternalHelp => {},
	};
	
	bless( $self, $class);
	return $self;
}

sub isCommand {
	my $self = shift;

	my $rv = 0;
	my $command = shift;
	TB_TRACE( "is $command internal?" );
	if ( ref( $COMMAND_LUT{ $command } ) eq 'CODE' ) {
		$rv = 1;
	}
	return $rv;
}

sub doCommand {
	my $self = shift;

	my $rv = 0;
	if ( ref( $COMMAND_LUT{ $_[2] } ) eq 'CODE' ) {
		TB_TRACE( "internal command $_[2] called" );
		$rv = $COMMAND_LUT{ $_[2] }->($self, @_);
	} else {
		TB_LOG( "WARNING: Somehow we tried to exec a nonexistent internal command $_[2]" );
	}
	return $rv;
}

sub installCommandHelp {
	my $self = shift;
	my ($command, $help) = @_;

	TB_TRACE("Installing help for $command");
	$self->{'ExternalHelp'}{$command} = $help;
}

### INTERNAL SUBROUTINES
# they're not actually called as object methods but we give them the relevant object in case they need state informaiton

sub _help {
	my $self = shift;
	my ( $talker, $person, $command, @args ) = @_;
	
	my $help;
	if ( $args[0] eq 'commands' ) {
		my @allcommands = map { "... $_" } grep { m/^[a-zA-Z]/ } (keys(%HELP), keys(%{$self->{'ExternalHelp'}}));
		$talker->whisper( $person, 'This is a list of all available commands:', @allcommands, 'End of list', 'help <command> gives you more on each command' );
	} else {
		$help = $HELP{$args[0]} || $self->{'ExternalHelp'}{$args[0]} || $HELP{'_default'};
	}
	$talker->whisper( $person, @$help );
	return 0;
}

sub _version {
	my $self = shift;
	my ( $talker, $person, $command, @args ) = @_;
	
	$talker->whisper( $person,
		'TalkerBot!',
		"Version  : $talker->{'version'}",
		"Created  : $talker->{'created'}",
		"Lines In : $talker->{'lines_in'}",
		"Lines Out: $talker->{'lines_out'}",
	);
	return 0;
}

sub _process {
	my $self = shift;
	my ( $talker, $person, $command, @args ) = @_;

	my $pid = $talker->{'pid'};
	my $cmd = "/bin/ps v p $pid";
	#  PID TTY      STAT   TIME  MAJFL   TRS   DRS  RSS %MEM COMMAND
	#16968 pts/3    S      0:01    378   696  3975 2868  6.1 StatusBot CONNECTED
	my ($header, $info) = qx($cmd);
	if ($info =~ m/^\d+\s+\S+\s+S\s+\S+\s+\d+\s+\d+\s+\S+\s+\d+\s+([\d\.]+)/) {
		my $mem = $1;
		$talker->whisper( $person, "PID is $pid, Memory used is $mem%, born " . $talker->{'created'});
	} else {
		$talker->whisper( $person, "Can't find memory usage");
	}
	
	return 0;
}

sub _die {
	my $self = shift;
	my ( $talker, $person, $command, @args ) = @_;
	
	if ( $talker->authenticate( $args[0] ) ) {
		$talker->whisper( $person, "I'm going away now");
		TB_LOG( "KILLED by $person" );
		return 1;
	} elsif ( $talker->{'Prefs'}->{'die'}->{ $person }++ > 2 ) {
		$talker->shout( "$person is trying to kill me" );
	} else {
		$talker->whisper( $person, "Sorry, you are not allowed to execute this command");
	}
	return 0;
}

sub _echo {
	my $self = shift;
	my ( $talker, $person, $command, @args ) = @_;
	
	my $password = shift( @args );
	
	if ( $talker->authenticate( $password, $person ) ) {
		$talker->say( "$person made me say " . join(' ', @args));
		TB_LOG( "ECHO forced by $person" );
	} else {
		$talker->whisper( $person, "Sorry, you are not allowed to execute this command");
	}
	return 0;
}

sub TB_TRACE {}
sub TB_LOG {}
1;

=head1 NAME

Chatbot::TalkerBotCommands - Some builtin command handling for the TalkerBot to use

=head1 SYNOPSIS

	my $handler = new Chatbot::TalkerBotCommands;
	$boolean = $handler->isCommand( 'help' );
	$rv = $handler->doCommand( $talker, $person, $command, @args );
	$handler->installCommandHelp( 'foo',  ['Syntax: foo <number>', 'Returns the foo function'] );

	
$rv is 0 unless the command wants to stop the bot, in which case a
return value of 1 will kill the bot. Hence, almost all commands should return 0.

$talker in the above should be a Chatbot::TalkerBot object.

=head1 DESCRIPTION

This module is intended to be used from inside Chatbot::TalkerBot, and not directly by anyone.
It has only three object methods - one that discovers whether a command is handled by this module,
one actually runs the command, and one is used to install help information for use by the 'help'
builtin command handler.

See Chatbot::TalkerBot docs section COMMANDS - INTERNAL AND EXTERNAL, to see when this object 
is called upon to handle a command.

=head1 BUILTIN COMMANDS

=over 4

=item help

The most basic command. If called with no args (e.g. a user typed '> talkerbot help') it returns
a minimal help syntax message; if called with the argument 'commands' if whispers back the full
list of available commands (well, all commands that have been registered with installCommandHelp);
else it tries to return help for the command whose name is the given argument. E.g. '> talkerbot
help foo' returns help for the foo command.

=item version

Returns version number and some basic stats - age, I/O amounts - for the talkerbot object.

=item process

Return information about the talkerbot's controlling process - memory usage and pid.

=item echo <password> <some text>

Requires that the first argument is a password, although if your talkerbot has an admin group defined
members of that group can enter the wrong password. This command forces the bot to say something.

=item die <password>

Requires a correct password. Makes the bot gracefully leave the event loop.

=back

=head1 VERSION

$Id: TalkerBotCommands.pm,v 1.4 2001/12/16 06:10:44 piers Exp $

=cut