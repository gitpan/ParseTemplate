use ExtUtils::MakeMaker;	# See the Camel, page 409-
require 5.000;

WriteMakefile(
	      'NAME'		=> 'Parse::Template',
	      'DISTNAME'        => "ParseTemplate",
	      'VERSION_FROM'	=> 'lib/Parse/Template.pm',
	      'clean'		=> {'FILES' => 'err'},
	      'dist'            => { COMPRESS => 'gzip', SUFFIX => 'gz' },
);

