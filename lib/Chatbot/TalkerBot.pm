package Chatbot::TalkerBot;

use IO::Socket;
use Exporter;
use Chatbot::TalkerBotCommands;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $TRACING $LOGGING $DEFAULT_COMMANDS);

($VERSION) = ('$Revision: 1.8 $' =~ /([\d\.]+)/);
@ISA = qw(Exporter);
@EXPORT = qw(connect_through_firewall connect_directly);
@EXPORT_OK = qw(TB_TRACE TB_LOG);
$TRACING = 0;
$LOGGING = 1;

$DEFAULT_COMMANDS = {
	Tell => '> ',
	Say => '',
	Emote => ': ',
	PEmote => ':: ',
	REmote => '< ',
	PREmote => '<: ',
	SayList => '>>',
	EmoteList => '<>',
	PEmoteList => '<:>',
	Shout => '! ',
	Quit => '.quit',
};

# override tracing functions
*Chatbot::TalkerBotCommands::TB_TRACE = \&TB_TRACE;
*Chatbot::TalkerBotCommands::TB_LOG = \&TB_LOG;

### OBJECT-ORIENTED FUNCTIONS AND METHODS

sub new {
	my $class = shift;
	my $socket = shift;
	my $options = shift;

	unless ( exists( $options->{'AlreadyLoggedIn'} ) && $options->{'AlreadyLoggedIn'} == 1 ) {
		_talker_login( $socket, 
			$options->{'Username'}, $options->{'Password'}, 
			$options->{'UsernamePrompt'}, $options->{'PasswordPrompt'}, 
			$options->{'UsernameResponse'}, $options->{'PasswordResponse'}, 
			$options->{'LoginSuccess'}, $options->{'LoginFail'},
		);
	}

	my $self = {
		connection => $socket,
		created => scalar(localtime),
		start_time => time,
		version => $VERSION,
		lines_in => 0,
		lines_out => 0,
		pid => $$,
		Prefs => {},
	};
	if ( exists( $options->{'NoCommands'} ) && $options->{'NoCommands'} == 1 ) {
		$self->{'AnyCommands'} = 0;
	} else {
		$self->{'AnyCommands'} = 1;
		$self->{'CommandHandler'} = new Chatbot::TalkerBotCommands;
	}

	bless( $self, $class );

	$self->setTalkerCommands( $DEFAULT_COMMANDS );

	return $self;
}

sub say {
	my $self = shift;
	foreach my $line (@_) {
		TB_TRACE("saying: $line");
		$self->{'lines_out'} += 1;
		$self->{'connection'}->print( $self->{'TalkerCommands'}->{'Say'} . $line . "\n");
	}
}

sub whisper {
	my $self = shift;
	my $other = shift;
	foreach my $line (@_) {
		TB_TRACE("whispering: $line");
		$self->{'lines_out'} += 1;
		$self->{'connection'}->print( $self->{'TalkerCommands'}->{'Tell'} . $other . ' ' . $line . "\n");
	}
}

sub emote {
	my $self = shift;
	foreach my $line (@_) {
		TB_TRACE("emoteing: $line");
		$self->{'lines_out'} += 1;
		$self->{'connection'}->print( $self->{'TalkerCommands'}->{'Emote'} . $line . "\n");
	}
}

sub pemote {
	my $self = shift;
	foreach my $line (@_) {
		TB_TRACE("pemoteing: $line");
		$self->{'lines_out'} += 1;
		$self->{'connection'}->print( $self->{'TalkerCommands'}->{'PEmote'} . $line . "\n");
	}
}

sub remote {
	my $self = shift;
	my $other = shift;
	foreach my $line (@_) {
		TB_TRACE("remoteing: $line");
		$self->{'lines_out'} += 1;
		$self->{'connection'}->print( $self->{'TalkerCommands'}->{'REmote'} . $other . ' ' . $line . "\n");
	}
}

sub premote {
	my $self = shift;
	my $other = shift;
	foreach my $line (@_) {
		TB_TRACE("premoteing: $line");
		$self->{'lines_out'} += 1;
		$self->{'connection'}->print( $self->{'TalkerCommands'}->{'PREmote'} . $other . ' ' . $line . "\n");
	}
}

sub saylist {
	my $self = shift;
	my $list = shift;
	foreach my $line (@_) {
		TB_TRACE("saylist: $line");
		$self->{'lines_out'} += 1;
		$self->{'connection'}->print( $self->{'TalkerCommands'}->{'SayList'} . $list . ' ' . $line . "\n");
	}
}

sub emotelist {
	my $self = shift;
	my $list = shift;
	foreach my $line (@_) {
		TB_TRACE("emotelist: $line");
		$self->{'lines_out'} += 1;
		$self->{'connection'}->print( $self->{'TalkerCommands'}->{'EmoteList'} . $list . ' ' . $line . "\n");
	}
}

sub pemotelist {
	my $self = shift;
	my $list = shift;
	foreach my $line (@_) {
		TB_TRACE("pemotelist: $line");
		$self->{'lines_out'} += 1;
		$self->{'connection'}->print( $self->{'TalkerCommands'}->{'PEmoteList'} . $list . ' ' . $line . "\n");
	}
}

sub shout {
	my $self = shift;
	my $line = shift;
	TB_TRACE("shouting: $line");
	$self->{'lines_out'} += 1;
	$self->{'connection'}->print( $self->{'TalkerCommands'}->{'Shout'} . $line . "\n");
}

sub chant {
	my $self = shift;
	my $line = shift;
	TB_TRACE("chanting: $line");
	$self->{'lines_out'} += 1;
	$self->{'connection'}->print($line . "\n");
}

sub quit {
	my $self = shift;
	TB_LOG("quit method called!");
	$self->chant( $self->{'TalkerCommands'}->{'Quit'} );
}

sub listenOnce {
	my $self = shift;
	my $socket = $self->{'connection'};
	my $text = <$socket>;
	$text =~ s/[\n\r]//g;
	TB_LOG("listenOnce heard: $text");
	return $text;
}

sub listenLoop {
	my $self = shift;
	my $matchre = shift || die("You must supply a match string/regexp");
	my $callback = shift;
	my $interrupt = shift;
	
	# check that any supplied callback is a coderef 
	if ($callback && (ref( $callback ) ne 'CODE')) { die("The callback must be a code reference"); }
	if ($interrupt) { TB_LOG("Installing interrupt handler every $interrupt secs"); }
	
	my $STOPLOOP = 0;
	local $SIG{'ALRM'} = ($interrupt? sub { $callback->($self, 'ALRM'); alarm($interrupt); } : 'IGNORE');
	alarm($interrupt) if $interrupt;
	
	# enter event loop
	TB_LOG("Entering listening loop");
	my $socket = $self->{'connection'};
	while( <$socket> ) {
		# we don't know how long it will take to process this line, so stop interrupts
		alarm(0) if $interrupt;
		
		s/[\n\r]//g;
		TB_TRAFFIC( $_ );
		
		# only pay any attention to that regular expression
		if (($self->{'AnyCommands'} == 1) && (m/$matchre/)) {
			my $person = $1;
			my $text = $2;
			TB_LOG("attending: <$person> says <$text>");
			$self->{'lines_in'} += 1;
			my ($command, @args) = split(/ /, $text);

			# try to process the command internally, and then via the callback
			if ( $self->{'CommandHandler'}->isCommand( $command ) ) {
				$STOPLOOP = $self->{'CommandHandler'}->doCommand( $self, $person, $command, @args );
			} elsif ( $callback ) {
				$STOPLOOP = $callback->( $self, $person, $command, @args );
			}
		}
		
		# command processing done, turn interrupts back on
		last if $STOPLOOP;
		alarm($interrupt) if $interrupt;
	}
	TB_LOG("Fallen out of listening loop");
}

# authenticate using a password, or optionally seeing if the person commanding us is in the admin group
sub authenticate {
	my $self = shift;
	my ($offer, $caller) = @_;
	
	if ( crypt($offer, $self->{'Admin'}->{'Password'}) eq $self->{'Admin'}->{'Password'} ) {
		TB_TRACE("Authentication passed using password");
		return 1;
	} elsif ( exists($self->{'Admin'}->{'Group'}->{$caller}) && $self->{'Admin'}->{'Group'}->{$caller} == 1 ) {
		TB_TRACE("Authentication passed using username $caller");
		return 1;
	} else {
		TB_LOG("Authentication FAILED for password $offer");
		return 0;
	}
}

# install authentication password, and optional group of users who are considered privileged
sub setAuthentication {
	my $self = shift;
	my $password = shift;
	my $group = shift || {};
	
	$self->{'Admin'}->{'Password'} = $password;
	$self->{'Admin'}->{'Group'} = $group;
}

# Installs commands needed to use the talker, e.g. how to Emote things, or how to shout.
sub setTalkerCommands {
	my $self = shift;
	my $commands = shift;
	
	foreach my $key ( keys %$commands ) {
		$self->{'TalkerCommands'}->{$key} = $commands->{$key};	
	}
}

sub installCommandHelp {
	my $self = shift;
	$self->{'CommandHandler'}->installCommandHelp( @_ );
}

### STATIC FUNCTIONS
sub connect_through_firewall {
	my ( $firehost, $fireport, $prompt, $command, $host, $port ) = @_;
	
	TB_LOG("Trying to connect through firewall <$firehost>:<$fireport>");
	my $socket = connect_directly( $firehost, $fireport );

	# wait for the connection 'prompt'
	while( <$socket> ) {
		s/[\n\r]//g;
		TB_LOG( $_ );
		last if m/$prompt/;
	}
	
	$command =~ s/<HOST>/$host/m;
	$command =~ s/<PORT>/$port/m;
	$socket->print($command . "\n");
	
	return $socket;
}

sub connect_directly {
	my ( $host, $port ) = @_;
	
	TB_LOG("Trying to connect directly to <$host>:<$port>");
	my $socket = IO::Socket::INET->new(
		PeerAddr => $host,
		PeerPort => $port,
		Proto => 'tcp',
		Timeout => 3,
	) or die("Can't make socket: $@");
	
	return $socket;
}

sub _talker_login {
	my ( $socket, $user, $pass, $userprompt, $passprompt, $say_user, $say_pass, $ok, $bad ) = @_;
	
	TB_TRACE( "_talker_login:  $user, $pass, $userprompt, $passprompt, $say_user, $say_pass, $ok, $bad" );

	$say_user =~ s/<USER>/$user/m;
	$say_user =~ s/<PASS>/$pass/m;

	$say_pass =~ s/<USER>/$user/m;
	$say_pass =~ s/<PASS>/$pass/m;

	my $logged_in = 0;
	# answer login prompts
	while (<$socket>) {
		s/[\n\r]//g;
		TB_TRACE($_);
		if (m/$userprompt/) {
			TB_TRACE("Trying to log in with: <$say_user>");
			$socket->print($say_user . "\n");
		}
		if (defined( $passprompt ) && m/$passprompt/) {
			TB_TRACE("Trying to log in with: <$say_pass>");
			$socket->print($say_pass . "\n");
		}
		if (m/$ok/) {
			TB_LOG("Logged in successfully!");
			$logged_in = 1;
			last;
		} elsif (m/$bad/) {
			TB_LOG("FAILED TO LOG IN");
			die("FAILED TO LOG IN");
		}
	}
	
	unless ($logged_in) {
		# i think we can only get here if the while never executes.
		# this is possible if the readine immediately returns undef
		die("still not logged in... connection closed? undefined socket?");
	}
	# must be logged in then
}

sub TB_TRACE {
	return unless $TRACING;
	TB_LOG( @_ );
}

sub TB_LOG {
	return unless $LOGGING;
	my $msg = shift;
	return if ($msg eq '');
	print '[' . scalar(localtime) . '] [' . $msg . "]\n";
}

sub TB_TRAFFIC {
	TB_LOG( @_ );
}

1;

=head1 NAME

Chatbot::TalkerBot - A robot client for a talker, with command handling

=head1 SYNOPSIS

	use Chatbot::TalkerBot;
	my $talker = new Chatbot::TalkerBot( $alreadyConnectedSocket, {
		Username => 'bot', Password => 'bot',
		UsernamePrompt => 'Enter username', PasswordPrompt => 'Enter password',
		UsernameResponse => '<USER>', PasswordResponse => '<PASS>',
		LoginSuccess => 'End of MOTD', LoginFail => 'Incorrect password'
	} );
	
	$talker->setTalkerCommands( { Say => '', Shout => '! '} );
	$talker->say( "Hello world" );
	$talker->listenLoop( qr/TELL (\w+)\s*>(.*)/, \&callback, 10 );
	$talker->whisper( 'david', 'bye bye' );
	$talker->quit;

=head1 DESCRIPTION

Creates a TalkerBot object which can be used to say (or shout, or emote, etc.) things to a talker,
it can listen to the talker, or it can sit in an event loop waiting to hear lines of a certain format
which it will then act upon. Additionally it makes all talker traffic that it hears available for 
whatever purpose you want. It also incorporates detailed tracing and action logging should you require it.

=head1 BACKGROUND

The usual talker system is where you telnet in, authenticate with username and password, and
simply type things to 'say' them. You prefix your speech with special characters in order to shout it,
tell it to a single person, etc. Robot talker clients can be used to provide an interface to 
databases, other talkers, what's on TV now, or anything you can think of. This projects grew out
of a live status-monitoring bot.

=head1 STEP 1 - NETWORK CONNECTION

You need to connect to the remote host somehow, and end up with an IO::Socket object connected 
to the talker host waiting to log in - i.e. the connection has _just_ opened. There are two
static, exported functions that can help you with this:

	$socket = connect_directly( $talkerhost, $talkerport );
	$socket = connect_through_firewall( $firehost, $fireport, $fireprompt, $firecommand, $talkerhost, $talkerport );
	
In the latter, $firecommand is a string such as 'connect <HOST> <PORT>' - where the actual values
are substituted in. These both die if connection is unsuccessful. Hence, if you get back an IO::Socket
object from these then you must have connected to your destination.

Or make a connected IO::Socket object yourself. Now that you've connected to the talker you need to go all object oriented...

=head1 STEP 2 - TALKER OBJECT CREATION

You need to make a new talkerbot object with that socket. UsernameResponse and PasswordResponse will
be strings like '<USER>' and '<PASS>' for talkers that want such things after individual prompts.
If your talker just prompts for 'username and password on the same line' just set UsernamePrompt to
whatever that last line is, set UsernameResponse to '<USER> <PASS>' (with the pointy brackets) and ignore 
the Password(Prompt|Response) entries, as there is no Password prompt or response.

Note that the login is done in line-oriented mode. If your talker login prompts do not end in a newline then
the login stage will hang, trying to read a full line. See the additional options below for a solution.

	my $talker = new TalkerBot( $socket,  
		{	Username => $user,
			Password => $pass,
			UsernamePrompt => $TALK_USER_PROMPT,
			PasswordPrompt => $TALK_PASS_PROMPT,
			UsernameResponse => $TALK_USER_RESPONSE, 
			PasswordResponse => $TALK_PASS_RESPONSE,
			LoginSuccess => $TALK_OK,
			LoginFail => $TALK_FAIL
		}
	);
	
ADDITIONAL OPTIONS: Aswell as those options you can add these if you want:

=over 4

=item *

AlreadyLoggedIn => 1 - this indicates that the $socket is a socket that has ALREADY logged in to the
talker - i.e. it is READY TO TALK. Use this if your talker has a login procedure that we can't handle
using our *Prompt and *Response syntax - log in yourself and then pass us the socket.

=item *

NoCommands => 1 - in listenLoop() the robot should not respond to any commands. See the COMMANDS bit below.

=back

If your bot will be executing commands you may want to use the authentication features:

	$talker->setAuthentication( $cryptedpassword, { pkent => 1, johna => 1 });

Some commands require passwords or are only available to certain users. This method sets
the password (you give it the crypted form) and a group of people who are also considered
trusted. Some commands require passwords, whereas some will let people in the admin group 
get away with entering a wrong password and will still allow them access, and others may 
not take passwords at all, but will only work for admin users.

You may want to tell the talkerbot about the commands it needs to use on this talker, although the
defaults should be ok for many talkers. You use it like this:

	$talker->setTalkerCommands( { Say => '', Shout => '! '} );

The full command set is: Tell Say Emote PEmote REmote PREmote SayList EmoteList PEmoteList Shout Quit

=head1 INTERACTION

In all of these cases, the bot will supply the newline after each item of text.

=over 4

=item $talker->say( $text [, $text2 ... ] );

Says some text out loud, in whatever group you happen to be in.

=item $talker->whisper( $person, $text [, $text2 ... ] );

Whisper/tell some text to somebody.

=item $talker->emote( $text [, $text2 ... ] ); $talker->pemote( $text [, $text2 ... ] ); $talker->remote( $person, $text [, $text2 ... ] ); $talker->premote( $person, $text [, $text2 ... ] ); 

From the above, you can guess how these work.

=item $talker->saylist( $list, $text [, $text2 ... ] ); $talker->emotelist( $list, $text [, $text2 ... ] ); $talker->pemotelist( $list, $text [, $text2 ... ] );

And similarly for these, for talking to lists on some talkers.

=item $talker->shout( $text );

And note this only shouts one line of text. It just seemed wrong to allow arbitrarily long shouts.

=item $talker->chant( $text );

The bot will send to the talker exactly what you tell it... useful for getting it to change groups, 
lock its group, change .info and that sort of thing that may require exact commands.

=item $lineOfText = $talker->listenOnce;

Tells the talker object to listen, and returns when we have a single line of text. Returns the line 
that was heard, with no newlines/carriage returns.

=item $talker->listenLoop( $matchre, \&callback [, $interrupt ] );

Go into an event loop and listen out for lines matching the regexp $matchre. That regexp must have
parentheses such that $1 is the speaker's name, and $2 is the full text of what they said.

You will probably want to set the regexp so that the bot only listens to things whispered to it.

You must provide a code reference for a subroutine that is called whenever a matching line is heard.
The sub will be called with ($talker, $person, $command, @args) where @args is whatever they said to
the bot split on whitespace. If you need a single string just join() the array back up.

If you provide an $interrupt variable then the bot will _also_ call the callback with arguments of
( $talker, 'ALRM' ) after every $interrupt seconds of inactivity. NOTE that this usually means that
the talker must be totally quiet for $interrupt seconds.

=item $talker->authenticate( $password [, $person ] );

Returns 1 if the password is the right password, or if the person is on the admin group, 0 otherwise. 
Note that the methods in this package do not do any authentication - that's up to the controlling program.

=back

=head1 MISC

=over 4

=item $talker->installCommandHelp( $commandname, \@linesOfHelpText );

Installs a load of help text for the named command. Usual idiom is:

	$talker->installCommandHelp( 'foo',  ['Syntax: foo <number>', 'Returns the foo function'] );

This method actually passes through to the talkerbot's Chatbot::TalkerBotCommands object, 
which registers the help internally for use by its builtin 'help' command handler. Only use this if you're using external 
commands (see below).

=item TB_LOG( 'some text' ); - not autoexported, say: import Chatbot::TalkerBot qw/TB_LOG/;

Logs whatever string you give it. Default action is to send to STDOUT with a timestamp, but you can override this sub.
Important goings-on inside the bot are logged using this sub.

=item TB_TRACE( 'debugging text' ); - not autoexported, say: import Chatbot::TalkerBot qw/TB_TRACE/;

Logs whatever you give it only if $Chatbot::TalkerBot::TRACING is 1.  Default action is to send to STDOUT with a 
timestamp, but you can override this sub. Pretty much everything that happens inside the bot is traced using this 
function - very useful in debugging and testing. NOTE that $TRACING is set to 0 by default.

=item TB_TRAFFIC( 'blah blah' ); - not exported.

This subroutine is called with every line of text (with no newline) that the talker hears, no matter what it is.
By default this sub just calls TB_LOG, but you can override this sub. Not exported as it should just be used for talker traffic.

=back

OVERRIDING SUBROUTINES: In your controlling program you can add a line like this:

	*Chatbot::TalkerBot::TB_TRAFFIC = \&my_traffic_logger;

which will make the bot send all traffic that it hears to your subroutine where you can do what you want with it.

=head1 COMMANDS - INTERNAL AND EXTERNAL

When the bot is in listenLoop() and it hears a line matching the regexp it splits whatever
the person said into a list of words, and takes the first word to be the command name.
Some commands are handled internally, but if the command given is not an internal command then the
callback function is called.

For example, the command 'help' is handled internally - you ask for help by, for example,
whispering 'help' to the bot (which would mean typing '> statusbot help' on many talkers).
A good default regexp should only listen to whispers, so any commands must be given to the bot via a 
whisper.

A well-behaved callback will whisper any response to the person who originally whispered to the bot,
and not say things out loud, and additionally it will say if a requested command doesn't exist.

Internal commands are actually handled by a Chatbot::TalkerBotCommands object. See the docs for that 
module to find out what it can handle.

If you want a bot that does not respond to ANY commands being whispered at it you can pass in 
NoCommands => 1 as part of that hash of options.

If you only want your bot to respond to the internal commands, and not try to run a callback (you're
probably using it to quietly log all talker traffic) then just pass in 'undef' instead of a callback ref to listenLoop.

=head1 PERSISTENT DATA

$talker->{'Prefs'} is a hashref that allows all commands to store their own persistent
data, for whatever reason they like. To avoid namespace clashes commands MUST put their
data under a key that is exactly the same as their command name, e.g. the die command
puts some state data in $talker->{'Prefs'}->{'die'}

=head1 BUGS

Everything's done in line-oriented mode. This could be a problem if the login prompts for your talker do not end 
with a newline because the login part will hang.

=head1 VERSION

P Kent pause@selsyn.co.uk

$Id: TalkerBot.pm,v 1.8 2001/12/19 04:53:01 piers Exp $

=cut