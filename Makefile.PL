# $Id: Makefile.PL,v 1.35 2004-07-30 15:28:49 kycl4rk Exp $

use strict;
use Module::Build::Compat;

Module::Build::Compat->run_build_pl(args => \@ARGV);
Module::Build::Compat->write_makefile();
