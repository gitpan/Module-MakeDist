package Module::MakeDist;

# Name:
#	Module::MakeDist.
#
# Purpose:
#	Convert module directory into shippable files (*.tgz, *.zip).
#	We do not use any external programs such as tar, gzip or zip.
#
# Documentation:
#	POD-style documentation is at the end. Extract it with pod2html.*.
#
# Note:
#	o tab = 4 spaces || die
#
# Author:
#	Ron Savage <ron@savage.net.au>
#	Home page: http://savage.net.au/index.html

use strict;
use warnings;

require 5.005_62;

require Exporter;

use Archive::Tar;
use Archive::Zip qw/:ERROR_CODES/;
use Carp;
use Compress::Zlib;
use Config;
use File::Copy;
use File::Find;
use File::Path;
use File::Spec;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use <ModuleName> ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);
our $VERSION = '1.01';

# -----------------------------------------------

my($myself);

# Preloaded methods go here.

# -----------------------------------------------

# Encapsulated class data.

{
	my(%_attr_data) =
	(	# Alphabetical order.
		_name			=> '',
		_verbose		=> 0,
		_version		=> '',
		_work_dir		=> '.',
	);

	sub _default_for
	{
		my($self, $attr_name) = @_;

		$_attr_data{$attr_name};
	}

	sub _make_gzip
	{
		my($self)		= @_;
		my($tar)		= Archive::Tar -> new();

		mkpath([File::Spec -> catdir(@{$$self{'_html_dir'} })], 0, 0);

		# Fabricate some empty files so File::Find finds them.
		# Turn off read-only bit using OS-specific code :-(.
		# Also, this ensures we can write to these files.

		for ("$$self{'_base_name'}.html", $$self{'_html_file'}, 'MANIFEST', 'README')
		{
			if ($Config{'osname'} eq 'MSWin32')
			{
				`attrib -R $_`;
			}
			elsif ($Config{'osname'} eq 'linux')
			{
				`chmod 644 $_`;
			}

			open(OUT, "> $_") || croak("Can't open(> $_): $!");
			close OUT;
		}

		`pod2html --infile=$$self{'_base_name'}.pm --outfile=$$self{'_html_file'}`;
		`pod2text $$self{'_base_name'}.pm > README`;

		copy($$self{'_html_file'}, "$$self{'_base_name'}.html");

		if ($$self{'_debug'})
		{
			print "Finished creating $$self{'_html_file'}\n";
			print "Finished creating README\n";
		}

		# Create KillerApp-1.00.tgz.

		chdir('..') || croak("Can't chdir(..'): $!");

		# Determine what to ship.

		find(\&_what_to_gzip, $$self{'_module'});
		find(\&_what_to_zip, $$self{'_module'});

		@{$$self{'_ship_in_gzip'} } = map{s|\\|/|; $_;} @{$$self{'_ship_in_gzip'} };

		if ($$self{'_verbose'})
		{
			print "Tarring: $_\n" for @{$$self{'_ship_in_gzip'} };
		}

		open(OUT, '>' . File::Spec -> catfile($$self{'_module'}, 'MANIFEST') ) || croak("Can't open(> MANIFEST): $!");

		my($file_name);

		for (@{$$self{'_ship_in_gzip'} })
		{
			# Since we called find from upstairs, we need to chop
			# off the module name prefix and the dir separator.

			($file_name = $_)			=~ s/^$$self{'_module'}//;
			substr($file_name, 0, 1)	= '' if ($file_name =~ /^[^A-Za-z]/);

			print OUT "$file_name\n";
			print "Manifesting: $file_name\n" if ($$self{'_verbose'});
		}

		close OUT;

		print "Finished creating MANIFEST\n" if ($$self{'_verbose'});

		$tar -> add_files(@{$$self{'_ship_in_gzip'} });
		$tar -> write("$$self{'_module'}.tar");

		chdir($$self{'_module'}) || croak("Can't chdir($$self{'_module'}): $!");

		my($compressed)	= compress($tar -> write() );

		croak(__PACKAGE__ . ". Can't compress output from tar") if (! $compressed);

		my($gzip)	= gzopen($$self{'_tgz_file'}, 'wb9');
		my($bytes)	= $gzip -> gzwrite($tar -> write() );

		$gzip -> gzclose();

		croak(__PACKAGE__ . ". Can't write gzipped data to $$self{'_tgz_file'}") if (! $bytes);

		print "Finished creating $$self{'_tgz_file'}\n" if ($$self{'_verbose'});

	}	# End of _make_gzip.

	sub _make_make
	{
		my($self) = @_;

		`perl Makefile.PL`;

		croak(__PACKAGE__ . ". 'perl Makefile.PL' did not create 'Makefile'") if (! -e 'Makefile');

		# Clean up any previous run.

		$self -> _run_make('clean');

		unlink $$self{'_ppd_file'};

		rmtree(['x86'], 0, 0);

		`perl Makefile.PL`;

		croak(__PACKAGE__ . ". 'perl Makefile.PL' did not create 'Makefile'") if (! -e 'Makefile');

		print "Finished creating 'Makefile'\n" if ($$self{'_verbose'});

	}	# End of _make_make.

	sub _make_ppd
	{
		my($self) = @_;

		mkpath(['x86'], 0, 0);

		# Poor old ppm can't handle *.tgz.

		copy($$self{'_tgz_file'}, File::Spec -> catfile('x86', $$self{'_tar_gz_file'}) );

		$self -> _run_make('ppd');

		# Patch *.ppd to fix CODEBASE line.
		# We do not use File::Spec in the map because to run ppm under MS Windows
		# and install from a ppd file on a Linux box, we _must_ use x86/.
		# ppm itself accepts both x86\ and x86/ at this point.

		my($line)	= $self -> _read_file($$self{'_ppd_file'});
		@$line		= map{$_ = "${1}x86/$$self{'_tar_gz_file'}$2" if (/^(.+CODEBASE HREF=")(".+)$/); $_;} @$line;

		open(OUT, "> $$self{'_ppd_file'}") || croak(__PACKAGE__ . ". Can't open(> $$self{'_ppd_file'}): $!");
		binmode OUT;
		print OUT join("\n", @$line), "\n";
		close OUT;

		print "Finished making and patching $$self{'_ppd_file'}\n" if ($$self{'_verbose'});

	}	# End of _make_ppd.

	sub _make_zip
	{
		my($self)	= @_;
		my($zip)	= Archive::Zip -> new();

		push(@{$$self{'_ship_in_zip'} }, $$self{'_ppd_file'}, File::Spec -> catfile('x86', $$self{'_tar_gz_file'}) );

		my($member);

		for (@{$$self{'_ship_in_zip'} })
		{
			# Since we called find from upstairs, we need to chop
			# off the module name prefix and the dir separator.

			s/^$$self{'_module'}//;

			substr($_, 0, 1)	= '' if (/^[^A-Za-z]/);
			$member				= $zip -> addFile($_) || croak("Can't add $_ to zip file");

			print "Zipping: $_\n" if ($$self{'_verbose'});
		}

		($zip -> writeToFileNamed($$self{'_zip_file'}) == AZ_OK) || croak("Can't write zip file: '$$self{'_zip_file'}'");

		print "Finished creating $$self{'_zip_file'}\n" if ($$self{'_verbose'});

	}	# End of _make_zip.

	sub _read_file
	{
		my($self, $file_name) = @_;

		open(INX, $file_name) || croak(__PACKAGE__ . ". Can't open($file_name): $!");
		binmode INX;
		my(@line) = <INX>;
		close INX;
		chomp(@line);

		my($line);

		for $line (@line)
		{
			$line =~ s/((\r*\n+)|(\n*\r+))$//;
		}

		\@line;

	}	# End of _read_file.

	sub _run_make
	{
		my($self, $option)	= @_;
		$option				||= '';

		# Run either '[dn]make' or '[dn]make ppd'.

		`$Config{'make'} $option 2>&1`;

		print "Finished running $Config{'make'} $option\n" if ($$self{'_verbose'});

	}	# End of _run_make.

	sub _standard_keys
	{
		sort keys %_attr_data;
	}

	sub _validate_options
	{
		my($self) = @_;

		croak(__PACKAGE__ . ". You must supply values for the parameters name, version and work_dir") if (! ($$self{'_name'} && $$self{'_version'} && $$self{'_work_dir'}) );

#		# Reset empty parameters to their defaults.
#		# This could be optional, depending on another option.
#
#		for my $attr_name ($self -> _standard_keys() )
#		{
#			$$self{$attr_name} = $self -> _default_for($attr_name) if (! $$self{$attr_name});
#		}

	}	# End of _validate_options.

	sub _unixify_line_endings
	{
		my($self) = @_;

		find(\&_what_to_unixify, '.');

		print "Finished unixifying line endings\n" if ($$self{'_verbose'});

	}	# End of _unixify_line_endings.

	sub _what_to_gzip
	{
		return if (-d $_);

		# Don't reject files of size 0. Some people may want
		# to ship such files for use in their test code.

		# Handle blib sub directory separately, since we ship all of it.

		if ($File::Find::name =~ /blib/)
		{
			push(@{$$myself{'_ship_in_gzip'} }, $File::Find::name);

			return;
		}

		# Process only files likely to be of interest.

		return if ( (/\.(bak|x~~)$/i) || (/^(Makefile(.old)?|pm_to_blib)$/i) );

		push(@{$$myself{'_ship_in_gzip'} }, $File::Find::name);

	}	# End of _what_to_gzip.

	sub _what_to_unixify
	{
		return if (-d $_);

		# Process only files likely to be text.

		return if (! (/\.(?:cgi|css|pm|pl|xs|t|html?|txt)$/i) && (! /^(?:MANIFEST|Changes|Readme)$/i) );

		print "Converting $File::Find::name to Unix line ending format\n" if ($$myself{'_verbose'});

		my($line) = $myself -> _read_file($_);

		# Turn off read-only bit using OS-specific code :-(.

		if ($Config{'osname'} eq 'MSWin32')
		{
			`attrib -R $_`;
		}
		elsif ($Config{'osname'} eq 'linux')
		{
			`chmod 644 $_`;
		}

		# Write out with a Unix-style line ending.
		# If only Perl were OS-agnostic :-(.

		open(OUT, "> $_") || croak(__PACKAGE__ . ". Can't open(> $_): $!");
		binmode OUT;
		print OUT join("\x0A", @$line), "\x0A";
		close OUT;

	}	# End of _what_to_unixify.

	sub _what_to_zip
	{
		return if (-d $_);

		# Don't reject files of size 0. Some people may want
		# to ship such files for use their test code.

		# Handle blib sub directory separately, since we ship none of it.

		return if ($File::Find::name =~ /blib/);

		# Process only files likely to be of interest.

		return if (! (/\.(?:html|txt)$/i) && (! /^(?:Changes|Readme?)$/i) );

		push(@{$$myself{'_ship_in_zip'} }, $File::Find::name);

	}	# End of _what_to_zip.

}	# End of Encapsulated class data.

# -----------------------------------------------

sub new
{
	my($caller, %arg)	= @_;
	my($caller_is_obj)	= ref($caller);
	my($class)			= $caller_is_obj || $caller;
	my($self)			= bless({}, $class);

	for my $attr_name ($self -> _standard_keys() )
	{
		my($arg_name) = $attr_name =~ /^_(.*)/;

		if (exists($arg{$arg_name}) )
		{
			$$self{$attr_name} = $arg{$arg_name};
		}
		else
		{
			$$self{$attr_name} = $self -> _default_for($attr_name);
		}
	}

	$self -> _validate_options();

	# Set up global variable for use by sub found().

	$myself					= $self;
	$$self{'_name'}			=~ s/::/-/g;
	$$self{'_html_dir'}		= ['blib', 'html', 'site', 'lib', split(/-/, $$self{'_name'})];
	$$self{'_base_name'}	= pop @{$$self{'_html_dir'} };
	$$self{'_base_name'}	=~ s/-\d.+$//;
	$$self{'_html_file'}	= File::Spec -> catfile(@{$$self{'_html_dir'} }, "$$self{'_base_name'}.html");
	$$self{'_module'}		= "$$self{'_name'}-$$self{'_version'}";
	$$self{'_ppd_file'}		= "$$self{'_name'}.ppd";
	$$self{'_ship_in_gzip'}	= [];
	$$self{'_ship_in_zip'}	= [];
	$$self{'_tar_gz_file'}	= "$$self{'_module'}.tar.gz";	# For PPM distro.
	$$self{'_tgz_file'}		= "$$self{'_module'}.tgz";		# For Unix distro.
	$$self{'_zip_file'}		= "$$self{'_module'}.zip";

	# Print before displaying error messages.
	# This gives user an insight when things fail.

	if ($$self{'_verbose'})
	{
		print "Work dir:    $$self{'_work_dir'}\n";
		print "Module:      $$self{'_name'}\n";
		print "Version:     $$self{'_version'}\n";
		print "make's name: $Config{'make'}\n";
	}

	chdir(File::Spec -> catdir($$self{'_work_dir'}, $$self{'_module'}) ) || croak(__PACKAGE__ . ". Can't chdir(" . File::Spec -> catdir($$self{'_work_dir'}, $$self{'_module'}) . "): $!");

	$self -> _make_make();
	$self -> _unixify_line_endings();
	$self -> _run_make();
	$self -> _make_gzip();
	$self -> _make_ppd();
	$self -> _make_zip();

	print "Created $$self{'_tgz_file'} and $$self{'_zip_file'}\n" if ($$self{'_verbose'});

	return $self;

}	# End of new.

# -----------------------------------------------

1;

__END__

=head1 NAME

C<Module::MakeDist> - Create Unix and ActiveState distros for a new module.

=head1 Synopsis

	use Module::MakeDist;

	# Work in /perl-modules/Module-MakeDist-1.00/.

	Module::MakeDist -> new
	(
		name		=> 'Module::MakeDist',
		verbose		=> 0,
		version		=> '1.00',
		work_dir	=> '/perl-modules',
	);

=head1 Description

Say we have a new module, KillerApp V 1.00, and in it's directory KillerApp-1.00/ are
these files:

=over 4

=item *

KillerApp.pm

=item *

Makefile.PL

=item *

Other files, such as test.pl, t/*.t, examples/*

=back

Then this module processes the directory KillerApp-1.00/, and generates all files required to
create shippable distributions (distros) in both Unix-style and ActiveState-style (ppm) formats.

Files created are:

=over 4

=item *

MANIFEST

=item *

README

We run pod2text on KillerApp.pm to create README.

=item *

KillerApp.html

We run pod2html on KillerApp.pm to create KillerApp.html.

The fancy *.html docs on my web site are output by fancy-pom2.pl, which is available
elsewhere on my web site.

=item *

KillerApp-1.00.tgz

The Unix-style distro.

This can be uploaded to CPAN.

=item *

KillerApp.ppd

This can be input to ppm.

=item *

x86/KillerApp-1.00.tar.gz

This is a copy of KillerApp-1.00.tgz. The last time I tested it, ppm choked on a file
called *.tgz.

=item *

KillerApp-1.00.zip

The ActiveState ppm-style distro. This file contains KillerApp.ppd, README, KillerApp.html and
x86/KillerApp-1.00.tar.gz.

=back

We do not use any external programs such as tar, gzip or zip.

=head1 Distributions

This module is available both as a Unix-style distro (*.tgz) and an
ActiveState-style distro (*.ppd). The latter is shipped in a *.zip file.

See http://savage.net.au/Perl-modules/html/installing-a-module.html for
help on unpacking and installing each type of distro.

=head1 Usage

As you can see from the program in the synopsis, which is the code I used
to generate the distros for this very module, the class does all its work
in the constructor. You do not call any other methods.

=head1 Options

Here, in alphabetical order, are the options accepted by the constructor,
together with their default values.

=over 4

=item *

name => ''

Name must be set to the name of the module. Eg:

	name => 'Module::MakeDist'

The '::' token is converted to '-', and combined with the version string,
to construct the name of the directory in which the module's files are
processed. This directory name is appended to the value of the work_dir
option.

=item *

verbose => 0

If verbose is set to some value > 0, print statements are activated which
show the steps in the flow of control.

=item *

version => ''

This is the version string, normally something like '1.00'.

=item *

work_dir => '.'

This is the parent directory of the module directory.

=back

C<Module::MakeDist> does a chdir into "work_dir/name-version" in order to
start work.

So, the example in the synopsis would mean this module attempts
to work in '/perl-modules/Module-MakeDist-1.00/'.

We use File::Spec to join the directory names.

=head1 OS-specific Code

There are 2 places where the read-only bit on a file is reset.

The code uses $Config{'osname'} to look for a small selection of known OSes,
and uses OS-specific commands for 'MSWin32' and 'linux' to do the reset.

Patches are welcome.

=head1 Files Shipped

See the source for subs called _what_to_gzip and _what_to_zip.

Such lists of files which 'ought to be shipped' can be extended indefinitely.
Hopefully, no real argument will ensue.

However, if you do believe specific extra files should be included in the
Unix-style distro, please let me know.

=head1 Slashes 'v' Backslashes

Perl is, and various Perl programs are, a bit of a mess when it comes to
processing directory separators:

=over 4

=item *

MANIFEST uses /

A line from this module's MANIFEST file looks like:

	examples/make-MakeDist.pl

Using a \ in this context means the file is omitted from the distro.

=item *

*.ppd uses \

A line from this module's Module-MakeDist.ppd file looks like:

	<CODEBASE HREF="x86\Module-MakeDist-1.00.tar.gz" />

Using a / in this context actually works.

Not only that, but to run ppm under MS Windows and install a module from a Linux box,
the CODEBASE must use /.

=back

=head1 Credits

I gained important information from these sources:

=over

=item idnopheq

http://www.perlmonks.org/index.pl?node_id=113448

=item Jenda Krynicky

http://jenda.krynicky.cz/perl/PPM.html

=back

=head1 Author

C<Module::MakeDist> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2002.

Home page: http://savage.net.au/index.html

=head1 Copyright

Australian copyright (c) 2002, Ron Savage. All rights reserved.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
