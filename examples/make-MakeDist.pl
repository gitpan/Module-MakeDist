#!/usr/bin/perl
#
# Name:
#	make-MakeDist.pl.
#
# Author:
#	Ron Savage <ron@savage.net.au>
#	http://savage.net.au/index.html

use strict;
use warnings;

use Module::MakeDist;

# -----------------------------------------------

Module::MakeDist -> new
(
	name		=> 'Module::MakeDist',
	verbose		=> 1,
	version		=> '1.00',
	work_dir	=> '/perl-modules',
);
