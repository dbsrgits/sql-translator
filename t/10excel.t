#!/usr/bin/perl
# vim: set ft=perl:
#

use Test::More;
use SQL::Translator;

plan tests => 1;

# Basic test
use_ok("SQL::Translator::Parser::Excel");

#my $tr = SQL::Translator->new(parser => "Excel");
