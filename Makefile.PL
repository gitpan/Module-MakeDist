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
	PL_FILES			=> {},
	PREREQ_PM			=>
	{
		Archive::Tar	=> 0,
		Archive::Zip	=> 0,
		Carp			=> 0,
		Compress::Zlib	=> 0,
		Config			=> 0,
		File::Copy		=> 0,
		File::Find		=> 0,
		File::Path		=> 0,
		File::Spec		=> 0,
		Test::More		=> 0,
		Test::Pod		=> 0,
	},
	VERSION_FROM		=> 'lib/Module/MakeDist.pm',
);
