#!/usr/local/bin/perl -w

require 5.004; 
use strict;
use Parse::Template;

my $T = new Parse::Template('HTML' => '<HTML>%%$N . HEAD() . $N . BODY() . $N%%</HTML>',
			    'HEAD' => '<HEAD>%%$N . $N%%</HEAD>',
			    'BODY' => '<BODY>%%$N . CONTENT() . $N%%</BODY>',
			    'CONTENT' => '<p>A very simple document: %%ORDERED_LIST()%%',
			    'ORDERED_LIST' =>
			    q!%%$_[0] < 4 ? "$N<OL><li>$_[0]" . ORDERED_LIST($_[0] + 1) . "<li>$_[0]$N</OL>$N" : ''%%!,
			   );
$T->env('N' => "\n");

print $T->eval('HTML');
