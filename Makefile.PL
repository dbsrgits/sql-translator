# $Id$

use strict;
use Module::Build::Compat;

Module::Build::Compat->run_build_pl(args => \@ARGV);
Module::Build::Compat->write_makefile();
