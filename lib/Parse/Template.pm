use strict
require 5.004;

package Parse::Template;
$Parse::Template::VERSION = '0.31';

use constant DEBUG => 0;	

my $id = 0;
sub get_id { $id++ }

my $PACKAGE = __PACKAGE__;
sub new {
  my $receiver = shift;
  my $class = $PACKAGE . '::Sym' . get_id();
  my $self; 
  if (@_) {
    $self = bless {@_}, $class;
  } else {
    $self = bless {}, $class;
  }
  no strict;
  @{"${class}::ISA"} = ref $receiver || $receiver;
  %{"${class}::template"} = %{"${class}::template"} = @_ ;
  $self;
}

use vars qw/$AUTOLOAD/;
sub AUTOLOAD {
  my($class, $key) = ($AUTOLOAD =~ /(.*)::(.*)$/);
  print STDERR "AUTOLOAD=>$AUTOLOAD\nclass=>$class\nargs=>@_\n" if DEBUG;
  eval "package $class; no strict; *{$AUTOLOAD} = sub { \$class->eval('$key', \@_) }";
  goto &$AUTOLOAD;
}
sub DESTROY {
  print STDERR "destroy @_" if DEBUG;
}
use constant TRACE_ENV => 0;
sub env {
  my $self = shift;
  my $class = ref $self || $self;
  my $symbol = shift;
  if ($symbol =~ /\W/) {
    require Carp;
    Carp::croak "invalid symbol name: $symbol"
  }

  no strict;
  if (@_) {
    while (@_) {
      my $value = shift;
      print STDERR "${class}::$symbol\t$value\n" if TRACE_ENV;
      if (ref $value) {
	*{"${class}::$symbol"} = $value;
      } else {			# scalar value
      	*{"${class}::$symbol"} = \$value;
      }
      $symbol = shift if @_;
      if ($symbol =~ /\W/) {
	require Carp;
	Carp::croak "invalid symbol name: $symbol"
      }
    }
  } elsif (defined *{"${class}::$symbol"}) { # borrowed from Exporter.pm
    return \&{"${class}::$symbol"} unless $symbol =~ s/^(\W)//;
    my $type = $1;
    return 
      $type eq '&' ? \&{"${class}::$symbol"} :
	$type eq "\$" ? \${"${class}::$symbol"} :
	    $type eq '@' ? \@{"${class}::$symbol"} :
	    $type eq '%' ? \%{"${class}::$symbol"} :
	    $type eq '*' ?  *{"${class}::$symbol"} :
	    do { require Carp; Carp::croak("Can\'t find symbol: $type$symbol") };
  } else {
    undef;
  }
}
# Purpose:  validate the regexp and replace "!" by "\!", and "/" by "\/"
# Arguments: a regexp
# Returns: the preprocessed regexp
sub ppregexp {
  #  my $self = $_[0]; # useless
  my $regexp = $_[1];
  eval { '' =~ /$regexp/ };
  if ($@) {			
    die "$@";			
  }
  $regexp =~ s{
    ((?:\G|[^\\])(?:\\{2,2})*)	# Context before
    ([/!\"])			# Used delimiters
  }{$1\\$2}xg;
  $regexp;
}
sub getPart {		
  my $self = shift;
  my $part = shift;
  my $class = ref $self || $self;
  no strict 'refs';
  ${"${class}::template"}{$part};
}
sub setPart {		
  my $self = shift;
  my $part = shift;
  my $class = ref $self || $self;
  no strict 'refs';
  ${"${class}::template"}{$part} = shift; 
}

#$^S Current state of the interpreter.  Undefined if parsing of the current
# eval is not finished.  True if inside an eval, otherwise false.
$Parse::Template::CONFESS = 1; 
use constant DIE_TRACE => 0;
my $Already_shown = 0;
my $__DIE__ = sub { # can certainly be improved...
  if (DIE_TRACE) {	
    print STDERR "__DIE__:\t@_";
    print STDERR "\$^S:\t$^S\n";
    print STDERR "\$1:\t$1\n";
  }
  if (defined $^S and $Already_shown) {
    $Already_shown = 0;
    return;
  } elsif (not $Parse::Template::CONFESS and $Already_shown) {
    return
  }
  # evaluated expressions are not always available in (caller(1))[6];	
  if (defined($1) and $1 ne '') {
    $expr = $1;			# what is the evaluated expression?
    { package DB;		# what is the part name?
      @DB::caller = caller(2);	# why is this needed? /ee?
      @DB::caller = caller(1);
    };	
    $expr =~ s/\bpackage\s+${PACKAGE}::\w+\s*;//o;
    my $line = 0;
    $expr =~ s/^/sprintf "%2s ", ++$line/egm;
    $expr =~ s/\n;$//;
    my $part = defined $DB::args[1] ? $DB::args[1] : '';
    if ($Already_shown) {
      print STDERR "From part '$part':\n$expr\n";
    } else {
      print STDERR "Error in part '$part':\n$expr\n";
    }
  }
  $Already_shown = 1;
};
use constant EVAL_TRACE => 0;
use constant SHOW_PART => 0;
use constant SIGN_PART => 0;
$Parse::Template::SIGN_START = "# Template %s {\n"; # not documented
$Parse::Template::SIGN_END = "# } Template %s\n"; # not documented
my $indent = 0;
sub eval {
  my $self = shift;
  print STDERR "eval(): $self\n" if DEBUG;
  my $class = ref $self || $self;
  my $part = shift;
  if (EVAL_TRACE) {
    print STDERR '..' x $indent, "$part\n";
    $indent++;
  }
  my $text = $self->getPart($part);
  unless (defined $text) {
    die "the '$part' template part is not defined";
  }
  print STDERR "$text\n" if SHOW_PART;
  if (SIGN_PART) {		# not documented
    $text =~ s/^/sprintf $Parse::Template::SIGN_START, $part/e;
    $text =~ s/$/sprintf $Parse::Template::SIGN_END, $part/e;
  }
  local $^W = 0 if $^W;
  local $SIG{__DIE__} = $__DIE__;
  $text =~ s{%%(.*?)%%}{	# the magic substitution
    print STDERR "eval 'package $class; $1'\n" if EVAL_TRACE;
    "package $class; $1";
  }eegsx;
  die "$@" if $@;
  if (EVAL_TRACE) {
    $indent--;
  }
  $text;
}
1;
__END__

=head1 NAME

Parse::Template - Processor for templates containing Perl expressions (0.40)

=head1 SYNOPSIS

  use Parse::Template;

  my %template =
    (
     'TOP' =>  q!Text before %%$self->eval('DATA')%% text after!,
     'DATA' => q!Insert data: ! .
               q!1. List: %%"@list$N"%%! .
               q!2. Hash: %%"$hash{'key_value'}$N"%%! .
               q!3. File content: %%print <FH>%%! .
               q!4. Sub: %%&SUB()$N%%!
    );

  my $tmplt = new Parse::Template (%template);
  open FH, "< foo";

  $tmplt->env('var' => '(value!)');
  $tmplt->env('list' => [1, 2, 10],
              'N' => "\n",
              'FH' => \*FH,
              'SUB' => sub { "->content generated by a sub<-" 
},
              'hash' => { 'key_value' => q!It\'s an hash value! });
  print $tmplt->eval('TOP'), "\n";

=head1 DESCRIPTION

The C<Parse::Template> class permits evaluating Perl expressions
placed within a text.  This class can be used as a code generator,
or a generator of documents in various document formats (HTML, XML,
RTF, etc.).

The principle of template-based text generation is simple.  A template
consists of a text which includes tagged areas with expressions to be
evaluated.  Interpretation of these expressions generates text
fragments which are substituted in place of the expressions.

Evaluation takes place within an environment in which, for example,
you can place data structures which will serve to generate the
parts to be completed.

Data used in generating missing parts can come from the environment
or can be the result of queries performed by the expressions.

             Template
          Text + Perl Expression 
		|
		+-----> Evaluation ----> Text(document, program)
		|	
	   Subs + Data structures
            Environment

With the class C<Parse::Template> a template can be decomposed into parts.
These parts are defined by a hash passed as an argument to the C<new()> method:
C<Parse::Template->E<gt>C<new('someKey', '... text with expressions to
evaluate ...')>.  Within a part, a sub-part can be included by
means of an expression of the form:

  $self->eval('SUB_PART_NAME')

C<$self> designates the instance of the C<Parse::Template> class.
You can choose to specify only the name of the part, and in this
case a subroutine with the name of the part will be dynamically
generated.  In the example given in the synopsis, the insertion of
the C<TOP> part can be rewritten as follows:

  'TOP' => q!Text before %%DATA()%% text after!

C<DATA()> is placed within C<%%> and is in effect treated as an
expression to be evaluated.

The subroutines take arguments.

An argument can be used to control the depth of recursive calls
of a template:

  print Parse::Template->new(
    'TOP' => q!%%$_[0] < 10 ? '[' . TOP($_[0] + 1) . ']' : ''%%!
   )->eval('TOP', 0);

C<$part> and C<$self> variables are defined by default and can be used 
in expressions. C<$self> is the template instance, C<$part> the
template part name.

The C<env()> method permits constructing the environment required for
evaluation of a template.  Each entry to be defined within the
environment must be specified using a key consisting of the name of
the symbol to be created, associated with a reference whose type is
that of the created entry (for example, a reference to an array to
create an array).  A scalar variable is defined by declaring a name
for the variable, associated with its value.  A scalar variable
containing a reference is defined by writing C<'var' =>E<gt>C<\$variable>,
where C<$variable> is a lexical variable that contains the 
reference.

Each instance of C<Parse::Template> is defined within a specific class,
a subclass of C<Parse::Template>.  The subclass contains the environment
specific to the template and inherits from the C<Parse::Template> class.

In case of a syntax error in the evalutaion of an expression,
C<Parse::Template> tries to indicate the template part and the
expression that is "incriminated".  If the variable
C<$Parse::Template::CONFESS> contains the value TRUE, the stack
of evaluations is printed.

=head1 METHODS

=over 4

=item new HASH

Constructor for the class. C<HASH> is a hash which defines the
template text.

Example:

 use Parse::Template;
 $t = new Parse::Template('key' => 'associated text');

=item env HASH

=item env SYMBOL

Permits defining the environment that is specific to a 
template.

C<env(SYMBOL)> returns the reference associated with the symbol, or
C<undef> if the symbol is not defined.  The reference that is returned
is of the type indicated by the character (C<&, $, %, @, *>) that
prefixes the symbol.

Examples:

  $tmplt->env('LIST' => [1, 2, 3])}   Defines a list

  @{$tmplt->env('*LIST')}             Returns the list

  @{$tmplt->env('@LIST')}             Ditto


=item eval PART_NAME

Evaluates the template part designated by C<PART_NAME>.  Returns the
string resulting from this evaluation.

=item getPart PART_NAME

Returns the designated part of the template.

=item ppregexp REGEXP

Preprocesses a regular expression so that it can be inserted into a
template where the regular expression delimiter is either a "/" or a
"!".

=item setPart PART_NAME => TEXT

C<setPart()> permits defining a new entry in the hash that defines the
contents of the template.

=back

=head1 EXAMPLES


The C<Parse::Template> class can be used in all sorts of amusing
ways. Here are some illustrations.

The first example shows how to generate an HTML document by using a
data structure placed within the evaluation environment:

 my %template = ('DOC' => <<'END_OF_DOC;', 'SECTION' => <<'END_OF_SECTION;');
 <html>
 <head></HEAD>
 <body>
 %%
 my $content;
 for (my $i = 0; $i <= $#section_content; $i++) {
   $content .= SECTION($i);
 }
 $content;
 %%
 </body>
 </html>
 END_OF_DOC;
 %%
 $section_content[$_[0]]->{Content} =~ s/^/<p>/mg;
 join '', '<H1>', $section_content[$_[0]]->{Title}, '</H1>', $section_content[$_[0]]->{Content};
 %%
 END_OF_SECTION;

 my $tmplt = new Parse::Template (%template);

 $tmplt->env('section_content' => [
     {
      Title => 'First Section',
      Content => 'Nothing to write'
     },
     {
      Title => 'Second section',
      Content => 'Nothing else to write'
     }
    ]
     );

 print $tmplt->eval('DOC'), "\n";

The second example shows how to generate an HTML document using a
functional notation, in other words, obtaining the text:

 <P><B>text in bold</B><I>text in italic</I></P>

by using

 P(B("text in bold"), I("text in italic"))


The Perl expression that permits producing this kind of structure is
very simple, and reduces to:

 join '', @_

The content to be evaluated is the same regardless of the tag and can
therefore be placed within a variable.  We therefore obtain the
following template:

 my $ELT_CONTENT = q!%%join '', @_%%!;
 my $HTML_T1 = new Parse::Template(
       'DOC' => '%%P(B("text in bold"), I("text in italic"))%%',
       'P' => qq!<P>$ELT_CONTENT</P>!,
       'B' => qq!<B>$ELT_CONTENT</B>!,
       'I' => qq!<I>$ELT_CONTENT</I>!,
      );
 print $HTML_T1->eval('DOC'), "\n";

We can go further if we know that the lexical variable
C<$part> is defined by default in the environment of evaluation
of the template:

 $ELT_CONTENT = q!%%"<$part>" . join('', @_) . "</$part>"%%!;
 $HTML_T2 = new Parse::Template(
       'DOC' => '%%P(B("text in bold"), I("text in italic"))%%',
       'P' => qq!$ELT_CONTENT!,
       'B' => qq!$ELT_CONTENT!,
       'I' => qq!$ELT_CONTENT!,
      );
 print $HTML_T2->eval('DOC'), "\n";


Let's look at another step which automates the production of 
expressions:

 $DOC = q!P(B("text in bold"), I("text in italic"))!;

 $ELT_CONTENT = q!%%"<$part>" . join('', @_) . "</$part>"%%!;
 $HTML_T3 = new Parse::Template(
      'DOC' => qq!%%$DOC%%!,
      map { $_ => $ELT_CONTENT } qw(P B I)
     );
 print $HTML_T3->eval('DOC'), "\n";


With a final transformation it is possible to use a 
method-call notation
to proceed with the generation:

 $ELT_CONTENT = q!%%shift(@_); "<$part>" . join('', @_) . "</$part>"%%!;

 $HTML_T4 = new Parse::Template(
      map { $_ => $ELT_CONTENT } qw(P B I)
     );
 print $HTML_T4->P(
                   $HTML_T4->B("text in bold"),
	           $HTML_T4->I("text in italic")
                  ), "\n";

C<Parse::Template> was initially created to serve as a code generator
for the C<Parse::Lex> class.  You will find other examples of its use
in the classes C<Parse::Lex>, C<Parse::CLex> and C<Parse::Token>.

=head1 NOTES CONCERNING THE CURRENT VERSION

This is an experimental module.  I would be very interested
to receive your comments and suggestions.

=head1 BUG

Instances are not destroyed.  Therefore, do not use this class 
to
create a large number of instances.

=head1 AUTHOR

Philippe Verdret (with translation of documentation by Ocrat)

=head1 COPYRIGHT

Copyright (c) 1995-1999 Philippe Verdret. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
