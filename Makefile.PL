use ExtUtils::MakeMaker;

# $Id: Makefile.PL,v 1.1 2001/12/19 02:34:54 piers Exp $

WriteMakefile(
	AUTHOR		=> 'P Kent (pause@selsyn.co.uk)',
	ABSTRACT	=> 'An object-oriented robot talker client',
	NAME		=> 'Chatbot::TalkerBot',
	DISTNAME	=> 'Chatbot-TalkerBot',
	dist		=> {
		COMPRESS	=> 'gzip',
		SUFFIX		=> '.gz',
	},
	VERSION_FROM	=> 'lib/Chatbot/TalkerBot.pm',
	PREREQ_PM	=> { },
	LIBS		=> [''],
	DEFINE		=> '',
	INC		=> '',
);

