# Examples: 
# make test TEST_FILES=t/test3.t TEST_VERBOSE=2
# todo:
# - implement different kind of comparators 
#   (kind of fuzzy matching)
#   ignore trailing spaces, ignore differences of line terminators

require 5.004;
use strict;
package W;			# Test::Wrapper
$W::VERSION = '1.0';

my $VERBOSE = $ENV{TEST_VERBOSE} || 0;
my $LOG = $ENV{TEST_LOG} ? 'testlog' : 0;

if ($LOG) {
  if (open(LOG, ">>$LOG")) {
    print STDERR "see informations in the '$LOG' file\n";
  } else {
    warn "unable to open '$LOG' ($!)";
    $LOG = '';
  }
} 
				# 
sub new {
  my $self = shift;
  my $class = (ref $self or $self);
  my $range = defined $_[0] ? shift : '1..1';
  print "$range\n";
  bless { 'range' => $range }, $class;
}
				# 
sub result {		
  my $self = shift; 
  my $cmd = shift;
  my @result;
  my @err;
  my $result;
  if ($cmd) {
    print "Execution of $^X $cmd\n" if $VERBOSE;
    die qq^unable to find "$cmd"^ unless (-f $cmd);

    # the following line doesn't work on Win95 (ActiveState's Perl, build 516):
    # open( CMD, "$^X $cmd 2>err |" ) or warn "$0: Can't run. $!\n";
    # corrected by Stefan Becker:
    local *SAVED_STDERR;
    open(SAVED_STDERR, ">&STDERR");
    open STDERR, "> err";
    open( CMD, "$^X $cmd |" ) or warn "$0: Can't run ($!)\n";
    @result = <CMD>;
    close CMD;
    close STDERR;
    open(STDERR, ">&SAVED_STDERR");

    open( CMD, "< err" ) or warn "$0: Can't open ($!)\n";
    @err = <CMD>;
    close CMD;

    push @result, @err if @err;

    $self->{result} = join('', @result);
    if ($LOG) {
      print LOG "=" x 80, "\n";
      print LOG "Execution of $^X $cmd 2>err\n";
      print LOG "=" x 80, "\n";
      print LOG "* Result:\n";
      print LOG "-" x 80, "\n";
      print LOG $self->{result};
    }
  } else {
    $self->{result};
  }
}
				# 
sub expected {			
  my $self = shift;
  my $FH = shift;
  if ($FH) {
    $self->{'expected'} = join('', <$FH>);
    if ($LOG) {
      print LOG "-" x 80, "\n";
      print LOG "* Expected:\n";
      print LOG "-" x 80, "\n";
      print LOG $self->{expected};
    }
  } else {
    $self->{'expected'};
  }
}
sub assert {
  my $self = shift;
  my $regexp = shift;
  if ($self->{'expected'} !~ /$regexp/) {
    die "'$regexp' doesn't match expected string";
  }
}
				# 
sub report {			# borrowed to the DProf.pm package
  my $self = shift;
  my $num = shift;
  my $sub = shift;
  my $x;

  $x = &$sub;
  $x ? "ok $num\n" : "not ok $num\n";
}
my $DELIM_START = ">>>>\n";
my $DELIM_END = "\n<<<<";
sub all_in_one {		
  my $self = shift;
  my $prog_to_test = shift;
  my $reference = shift;	# filehandle
  $self->result("$prog_to_test");
  $self->expected($reference);
  $self->report(1, sub { 
		  my $expectation = $self->expected;
		  my $result =  $self->result;
		  if ($VERBOSE >= 2) {
		      print STDERR "\n";
		      print STDERR ">>>Expected:\n$expectation\n";
		      print STDERR ">>>Result:\n$result\n";
		  }
		  $expectation =~ s/\s+$//;
		  $result =~ s/\s+$//;
		  unless ($expectation eq $result) {
		      if ($VERBOSE >= 2) {
			  # ...
			  if ($expectation eq $result) {
			  }
		      } elsif ($VERBOSE) {
		      }
		    0;
		  } else {
		    1;
		  }
		});

}
sub generate {			# generate a test from a program
}
sub debug {}
1;
