#!/usr/local/bin/perl -w
require 5.004; 
use strict;
use Parse::Template;

@main::ISA = qw/Parse::Template/;

my $ELT_CONTENT = q!%%"<$part>" . join('', @_) . "</$part>"%%!;
my $G = new Parse::Template(
			    map { $_ => $ELT_CONTENT } qw(H1 B I)
			   );
print H1(B("text in bold"), I("text in italic"));

__DATA__
