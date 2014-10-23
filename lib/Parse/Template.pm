use strict;
use warnings;
require 5.6.0;
package Parse::Template;
$Parse::Template::VERSION = '0.36';

use constant DEBUG => 0;
use constant AUTOLOAD_TRACE => 0;
use vars qw/$AUTOLOAD/;
sub AUTOLOAD {
  my($class, $part) = ($AUTOLOAD =~ /(.*)::(.*)$/);
  no strict 'refs';
  *$AUTOLOAD = sub { (ref $_[0] || $class)->eval("$part", @_) };
  goto &$AUTOLOAD;
}

use Symbol qw(delete_package);
{ my $id = 0; sub getid { $id++ } }

my $PACKAGE = __PACKAGE__;
sub new {
  my $receiver = shift;
  my $class = $PACKAGE . '::Sym' . getid();
  my $self = bless {}, $class;	# absolutely nothing in $self
  no strict;
  @{"${class}::ISA"} = ref $receiver || $receiver;
  ${"${class}::ancestor"} = $receiver;	# reverse the destruction order
  *{"${class}::AUTOLOAD"} = \&AUTOLOAD; # so no warning for procedural calls
  %{"${class}::template"} = @_ ;
  $self;
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
    do {
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
	Carp::croak "invalid symbol name: $symbol";
      }
    } while (@_);
  } elsif (defined *{"${class}::$symbol"}) { # borrowed from Exporter.pm
    return \&{"${class}::$symbol"} unless $symbol =~ s/^(\W)//;
    my $type = $1;
    return 
      $type eq '*' ?  *{"${class}::$symbol"} :
	$type eq "\$" ? \${"${class}::$symbol"} :
	  $type eq '%' ? \%{"${class}::$symbol"} :
	    $type eq '@' ? \@{"${class}::$symbol"} :
	      $type eq '&' ? \&{"${class}::$symbol"} :
		do { require Carp; Carp::croak("Can\'t find symbol: $type$symbol") };
  } else {
    undef;
  }
}
sub DESTROY {
  print STDERR "destroy(@_): ", ref $_[0], "\n" if DEBUG;
  delete_package(ref $_[0]);
}
# Purpose:  validate the regexp and replace "!" by "\!", and "/" by "\/"
# Arguments: a regexp
# Returns: the preprocessed regexp
sub ppregexp {
  #  my $self = $_[0]; # useless
  my $regexp = $_[1];
  eval { '' =~ /$regexp/ };
  if ($@) {	
    $@ =~ s/\s+at\s+[^\s]+\s+line\s+\d+[.]\n$//; # annoying info
    require Carp;
    Carp::croak $@;	
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
  my $text = '';
  no strict 'refs';
  unless (defined($text = ${"${class}::template"}{$part})) {
     my $parent = ${"${class}::ISA"}[0]; # delegation
     unless (defined $parent) {
      require Carp;
      Carp::croak("'$part' template part is not defined");
    }
    $text = $parent->getPart($part);
  } 
  $text;
}
sub setPart {		
  my $self = shift;
  my $part = shift;
  my $class = ref $self || $self;
  no strict 'refs';
  ${"${class}::template"}{$part} = shift; 
}
$Parse::Template::CONFESS = 1;
my $Already_shown = 0;
my $__DIE__ = sub { 
  if  (not($Parse::Template::CONFESS) and $Already_shown) {
    # Reset when the eval() processing is finished
    $Already_shown = 0 if defined($^S); 
    return;
  }
  # evaluated expressions are not always available in (caller(1))[6];
  if (defined($1) and $1 ne '') {
    my $expr = $1;		# what is the template expression?
    { package DB;		# what is the part name?
      @DB::caller = caller(1);
      @DB::caller = caller(2) unless @DB::args;
    };	
    #local $1;
    $expr =~ s/package\s+${PACKAGE}::\w+\s*;//o;
    my $line = 0;
    $expr =~ s/^/sprintf "%2s ", ++$line/egm;
    $expr =~ s/\n;$//;
    my $part = defined $DB::args[1] ? $DB::args[1] : '';
    if ($Already_shown) {
      print STDERR "call from part '$part':\n$expr\n";
    } else {
      print STDERR "Error in part '$part':\n$expr\n";
    }
  } else {
    print STDERR "\$1 not defined";    
  }
  print STDERR "\$1: $1\n";    
  # ignore Already_shown if you won't confess your exception
  $Already_shown = 1 unless $Parse::Template::CONFESS;
};
$Parse::Template::SIG{__WARN__} = sub { # don't know how to suppress this:
  print STDERR "$_[0]" 
    unless ($_[0] =~ /^Use of uninitialized value in substitution iterator/)
};

use constant EVAL_TRACE => 0;
use constant SHOW_PART => 0;
use constant SIGN_PART => 0;
$Parse::Template::SIGN_START = "# Template %s {\n"; # not documented
$Parse::Template::SIGN_END = "# } Template %s\n"; # not documented
my $indent = 0;
my @part = ();
sub eval {
  print STDERR do { 
    local $" = q!', '! ; '..' x ++$indent, "=>eval('@_')\n" 
  } if EVAL_TRACE;
  my $self = shift;
  my $part = shift;		# can't declare $part in eval()
  push @part, $part;
  my $class = ref $self || $self;
  my $text = $self->getPart($part);
  print STDERR qq!$part content: $text\n! if SHOW_PART;
  if (SIGN_PART) {		# not documented
    $text =~ s!^!sprintf $Parse::Template::SIGN_START, $part!e;
    $text =~ s!$!sprintf $Parse::Template::SIGN_END, $part!e;
  }
  local $SIG{__DIE__} = $__DIE__;
  # eval expression in class
  $text =~ s( %% (.*?) %% ){	# the magical substitution
    print STDERR '..' x $indent, "Eval part name: $part\n" if EVAL_TRACE;
    print STDERR '..' x $indent, "  expr: package $class;\n$1\n" if EVAL_TRACE;
    "package $class; $1";
  }eegsx;
  print STDERR "after: $class - $1\n" if EVAL_TRACE;
  die "$@" if $@;		# caught by __DIE__
  pop @part; $part = $part[-1];
  --$indent if EVAL_TRACE;
  $text;
}
1;
__END__

=head1 NAME

Parse::Template - Processeur de templates contenant des expressions Perl 

=head1 SYNOPSIS

  use Parse::Template;

  my %template = 
    (
     'TOP' =>  q!Text before %%$self->eval('DATA')%% text after!,
     'DATA' => q!Insert data: ! .
               q!1. List: %%"@list$N"%%! .
               q!2. Hash: %%"$hash{'key'}$N"%%! .
               q!3. File content: %%print <FH>%%! .
               q!4. Sub: %%&SUB()$N%%!
    );
 
  my $tmplt = new Parse::Template (%template);
  open FH, "< foo";

  $tmplt->env('var' => '(value!)');
  $tmplt->env('list' => [1, 2, 10], 
              'N' => "\n",
              'FH' => \*FH,
              'SUB' => sub { "->content generated by a sub<-" },
              'hash' => { 'key' => q!It\'s an hash value! });
  print $tmplt->eval('TOP'), "\n";

=head1 DESCRIPTION

La classe C<Parse::Template> �value des expressions Perl
plac�es dans un texte.  Cette classe peut �tre utilis�e comme
g�n�rateur de code, ou de documents appartenant � un format
documentaire quelconque (HTML, XML, RTF, etc.). 

Le principe de la g�n�ration de texte � partir d'un template est
simple.  Un template est un texte qui comporte des expressions �
�valuer. L'interpr�tation des expressions g�n�re des fragments de
textes qui viennent se substituer aux expressions. Dans le cas de
C<Parse::Template> les expressions � �valuer appartiennent au langage
Perl et sont plac�es entre deux C<%%>.  L'�valuation des expressions
doit avoir lieu dans un environnement dans lequel sont d�finies des
structures de donn�es qui serviront � g�n�rer les parties � compl�ter.


             TEMPLATE
          Texte + Expressions Perl
		|
		+-----> Evaluation ----> Texte (document, programme, ...)
		|	
	   Subs + Structures de donn�es
            ENVIRONNEMENT


Dans la classe C<Parse::Template> le document � g�n�rer est 
d�compos� en parties d�finies dans un tableau associatif. Le cl� dans
ce tableau est le nom de la partie, la valeur le contenu associ�.

Le tableau associatif est pass� en argument au constructeur de la
classe : 

  Parse::Template->new(SomePart => '... text with expressions to evaluate ...')

L'inclusion d'une sous-partie se fait par mention de la partie dans
une expression Perl. Cette inclusion peut se faire en utilisant un
style de programmation object ou proc�dural.

Dans un style object, au sein d'une partie, l'inclusion d'une
sous-partie peut se faire au moyen d'une expression de la forme :

  $self->eval('SUB_PART_NAME')

Cette expression doit retourner le texte � ins�rer en lieu et place.
C<$self> d�signe l'instance de la classe C<Parse::Template>.  Cette
variable est automatiquement d�finie (de m�me que la variable C<$part>
qui contient le nom de la partie du template dans laquelle se trouve
l'expression).

L'insertion d'une partie peut �galement se r�duire � l'invocation
d'une m�thode dont le nom est celui de la partie � ins�rer :

  $self->SUB_PART_NAME()

Dans un style proc�dural l'insertion d'une partie se fait par la simple
mention du nom de la partie. Dans l'exemple du synopsis, l'insertion
de la partie C<TOP> peut ainsi se r��crire comme suit :

  'TOP' => q!Text before %%DATA()%% text after!

C<DATA()> est plac�e entre C<%%> et est de fait traiter comme une
expression a �valuer. C<Parse::Template> se charge de g�n�rer
dynamiquement la routine C<DATA()>.

Les routines peuvent �tre appel�es avec des arguments. Dans l'exemple
qui suit on utilise un argument pour contr�ler la profondeur des
appels r�cursifs d'un template :

  print Parse::Template->new(
	   'TOP' => q!%%$_[0] < 10 ? '[' . TOP($_[0] + 1) . ']' : ''%%!
	  )->eval('TOP', 0);

C<$_[0]> qui contient initialement 0 est incr�ment� � chaque nouvelle
inclusion de la partie C<TOP> et cette partie est incluse tant que
l'argument est inf�rieur � 10.

La m�thode C<env()> permet de construire l'environnement requis pour
l'�valuation d'un template. Chaque entr�e � d�finir dans
l'environnement est sp�cifi�e au moyen d'une cl� du nom du symbole �
cr�er, associ�e � une r�f�rence dont le type est celui de l'entr�e �
cr�er dans cet environnement (par exemple, une r�f�rence � un
tableau pour cr�er un tableau).  Un variable scalaire est d�finie en
associant le nom de la variable � sa valeur.  Une variable scalaire
contenant une r�f�rence est d�finie en �crivant
C<'var'=>E<gt>C<\$variable>, avec C<$variable> une variable � port�e
lexicale qui contient la r�f�rence.

Chaque instance de C<Parse::Template> est d�finie dans une classe
sp�cifique, sous-classe de C<Parse::Template>. La sous-classe contient
l'environnement sp�cifique au template et h�rite des m�thodes de la
classe C<Parse::Template>.  Si un template est cr�� � partir d'un
template existant, le template d�riv� h�rite des parties d�finies par
son anc�tre.

En cas d'erreur dans l'�valuation d'une expression, C<Parse::Template>
essaie d'indiquer la partie du template et l'expression �
incriminer. Si la variable C<$Parse::Template::CONFESS> est � VRAIE,
la pile des �valuations est imprim�e.

=head1 METHODES

=over 4

=item new HASH

Constructeur de la classe. C<HASH> est un tableau associatif qui
d�finit les parties du template.

Exemple.

	use Parse::Template;
	$t = new Parse::Template('key' => 'associated text');

=item env HASH

=item env SYMBOL

Permet de d�finir l'environnement d'�valuation sp�cifique � un
template.

C<env(SYMBOL)> retourne la r�f�rence assoc�e au symbole ou C<undef> si
le symbole n'est pas d�fini. La r�f�rence retourn�e est du type
indiqu� par le caract�re (C<&, $, %, @, *>) qui pr�fixe le symbole.

Exemples.

  $tmplt->env('MY_LIST' => [1, 2, 3])}   D�finition d'une liste

  @{$tmplt->env('*MY_LIST')}             Retourne la liste

  @{$tmplt->env('@MY_LIST')}             Idem


=item eval PART_NAME

Evalue le partie du template d�sign�e par C<PART_NAME>. Retourne la
cha�ne de caract�res r�sultant de cette �valuation.

=item getPart PART_NAME

Retourne la partie d�sign�e du template.

=item ppregexp REGEXP

Pr�-processe une expression r�guli�re de mani�re � ce que l'on puisse
l'ins�rer sans probl�me dans un template o� le d�limiteur d'expression
r�guli�re est un "/", ou un "!".

=item setPart PART_NAME => TEXT

C<setPart()> permet de d�finir une nouvelle entr�e dans le hash qui
d�finit le contenu du template.

=back

=head1 EXEMPLES

La classe C<Parse::Template> permet de se livrer � toutes sortes de
fac�ties. En voici quelques illustrations.

=head2 G�n�ration de HTML

Le premier exemple montre comment g�n�rer un document HTML en
exploitant une structure de donn�es plac�e dans l'environnement
d'�valuation. Le template comporte deux parties C<DOC> et C<SECTION>.
La partie C<SECTION> est appel�e au sein de la partie C<DOC> pour
g�n�rer autant de sections qu'il y a d'�l�ment dans le tableau
C<@section_content>.

	my %template = ('DOC' => <<'END_OF_DOC;', 'SECTION' => <<'END_OF_SECTION;');
	<html>
	<head></head>
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
	join '', '<H1>', $section_content[$_[0]]->{Title}, '</H1>', 
                  $section_content[$_[0]]->{Content};
	%%
	END_OF_SECTION;
	
	my $tmplt = new Parse::Template (%template);
	
	$tmplt->env('section_content' => [
				 {
				  Title => 'First Section', 
				  Content => 'Nothing to declare'
				 }, 
				 {
				  Title => 'Second section', 
				  Content => 'Nothing else to declare'
				 }
				]
		   );
	
	print $tmplt->eval('DOC'), "\n";

=head2 G�n�ration de HTML par appel de fonctions

Le second exemple montre comment g�n�rer un document HTML � partir
d'appels imbriqu�s de fonctions. On souhaite par exemple obtenir le texte :

	<P><B>text in bold</B><I>text in italic</I></P>

� partir de la forme :

	P(B("text in bold"), I("text in italic"))

Les fonctions vont �tre d�finies comme des parties d'un template.
Au coeur de chaque partie, se trouve l'expression Perl suivante : 

	join '', @_

Le contenu � �valuer est le m�me quel que soit la balise et peut donc
�tre plac� dans une variable : 

	$DOC = q!P(B("text in bold"), I("text in italic"))!;

	my $ELT_CONTENT = q!%%join '', @_%%!;
	my $HTML_T1 = new Parse::Template(
	                    'DOC' => qq!%%$DOC%%!,
			    'P' => qq!<P>$ELT_CONTENT</P>!,
			    'B' => qq!<B>$ELT_CONTENT</B>!,
			    'I' => qq!<I>$ELT_CONTENT</I>!,
			   );
	print $HTML_T1->eval('DOC'), "\n";

La variable C<$DOC> contient la racine de notre template.

Nous pouvons aller un peu plus loin dans la factorisation de la
d�finition des parties du template en exploitant la variable C<$part>
qui est d�finie par d�faut dans l'environnement d'�valuation d'un
template :

	$ELT_CONTENT = q!%%"<$part>" . join('', @_) . "</$part>"%%!;
	$HTML_T2 = new Parse::Template(
	                    'DOC' => qq!%%$DOC%%!,
			    'P' => qq!$ELT_CONTENT!,
			    'B' => qq!$ELT_CONTENT!,
			    'I' => qq!$ELT_CONTENT!,
			   );
	print $HTML_T2->eval('DOC'), "\n";


Enfin, nous pouvons automatiser la production des expressions �
partir de la liste des balises HTML qui nous int�ressent : 

	$ELT_CONTENT = q!%%"<$part>" . join('', @_) . "</$part>"%%!;
	$HTML_T3 = new Parse::Template(
				  'DOC' => qq!%%$DOC%%!,
				  map { $_ => $ELT_CONTENT } qw(P B I)
				 );
	print $HTML_T3->eval('DOC'), "\n";

=head2 G�n�ration de HTML par invocation de m�thodes

Moyennant une l�g�re transformation il est possible d'utiliser une
notation de type invocation de m�thode dans l'expression associ�e
aux parties � d�finir :

	$ELT_CONTENT = q!%%shift(@_); "<$part>" . join('', @_) . "</$part>"%%!;
	$HTML_T4 = new Parse::Template(
				  map { $_ => $ELT_CONTENT } qw(P B I)
				 );
	print $HTML_T4->P(
	                  $HTML_T4->B("text in bold"), 
		          $HTML_T4->I("text in italic")
                         ), "\n";

Le C<shift(@_)> permet de se d�barasser de l'objet template dont nous
n'avons pas besoin dans l'expression associ�e � chaque balise.

=head2 H�ritage de parties

Dans l'exemple qui suit le template fils C<$C> h�rite des parties
d�finies dans son template anc�tre C<$A> :

	my %ancestor = 
	  (
	   'TOP' => q!%%"Use the $part model and -> " . CHILD()%%!,
	   'ANCESTOR' => q!ANCESTOR %%"'$part' part\n"%%!,
	  );

	my %child = 
	  (
	   'CHILD' => q!CHILD %%"'$part' part"%% -> %%ANCESTOR() . "\n"%%!,
	  );
	my $A = new Parse::Template (%ancestor);
	my $C = $A->new(%child);
	print $C->TOP();


Le partie C<TOP> d�finie dans C<$A> est directement invocable sur
C<$C> qui est d�riv� de C<$A>.

=head2 D'autres exemples

C<Parse::Template> a �t� initialement cr��e pour servir de g�n�rateur
de code � la classe C<Parse::Lex>. Vous trouverez d'autres exemples
d'utilisation dans les classes C<Parse::Lex>, C<Parse::CLex> et
C<Parse::Token> disponibles sur le CPAN.

=head1 APROPOS DE LA VERSION EN COURS

N'H�sitez pas � me contacter.  Une traduction en anglais d'une version
ant�rieure de cette documentation est disponible dans le r�pertoire
C<doc>.

=head1 BUGS

Les instances ne sont pas d�truites. Donc n'utilisez pas cette classe
pour cr�er un grand nombre d'instances.

=head1 AUTEUR

Philippe Verdret

=head1 COPYRIGHT

Copyright (c) 1995-2001 Philippe Verdret. All rights reserved.
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
