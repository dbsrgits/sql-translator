#!/usr/bin/perl
# vim: set ft=perl:
#
# Test that the filename can be set with an ArrayRef as well as a Str.
#

use strict;

use SQL::Translator;
use Test::More tests => 2;

my $datafile = "t/data/mysql/Apache-Session-MySQL.sql";
my $tr0 = SQL::Translator->new(filename => $datafile);
my $tr1 = SQL::Translator->new(filename => [$datafile]);
ok($tr0, "filename takes a Str");
ok($tr1, "filename takes an ArrayRef");
