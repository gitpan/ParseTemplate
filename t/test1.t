#!/usr/local/bin/perl

BEGIN {  push(@INC, './t') }	# where is W.pm
use W;

require 5.005; 

$test = W->new('1..1');
$test->result("examples/synopsis.pl");
$test->expected(\*DATA);
print $test->report(1, sub { 
		      my $expectation =  $test->expected;
		      my $result =  $test->result;
		      $expectation =~ s/\s+$//;
		      #print STDERR "Result:\n$result\n";
		      #print STDERR "Expectation:\n$expectation\n";
		      $result =~ s/\s+$//;
		      $expectation eq $result;
		    });

__END__
Text before 
Inserted part from SUB_PART(1)
   1. List: 1 2 10
   2. Hash: It\'s an hash value
   3. Sub: arguments: 1 2 3 soleil
Text after
