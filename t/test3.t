#!/usr/local/bin/perl

BEGIN {  push(@INC, './t') }	# where is W.pm
use W;

print W->new()->all_in_one("examples/derived.pl", *DATA);

__DATA__
ANCESTOR template: 'TOP' part ->
CHILD template:  'CHILD' part ->
PARENT template:  'PARENT' part ->
ANCESTOR template: 'ANCESTOR' part



