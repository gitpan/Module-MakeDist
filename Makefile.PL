use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile
(
	($] ge '5.005') ?
	(
		'AUTHOR' => 'Ron Savage (ron@savage.net.au)',
		'ABSTRACT' => 'Convert module into shippable files (*.tgz, *.zip [ie ppd])',
    ) : (),
	clean				=>
	{
		FILES			=> 'blib/* Makefile MANIFEST Module-MakeDist-*'
	},
	dist				=>
	{
		COMPRESS		=> 'gzip',
		SUFFIX			=> 'gz'
	},
	DISTNAME			=> 'Module-MakeDist',
	NAME				=> 'Module::MakeDist',
	VERSION_FROM		=> 'MakeDist.pm',
);
