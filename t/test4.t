#!/usr/local/bin/perl

BEGIN {  push(@INC, './t') }	# where is W.pm
use W;

print W->new()->all_in_one("examples/recursive.pl", \*DATA);

__DATA__
[[[[[[[[[[]]]]]]]]]]



