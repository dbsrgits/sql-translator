#!/usr/bin/perl
# vim: set ft=perl:
#

use Test::More;
use SQL::Translator;
use SQL::Translator::Validator;

plan tests => 6;

# Basic test
use_ok("SQL::Translator::Parser::Excel");

my $tr = SQL::Translator->new(parser => "Excel");
my $t = $tr->translate(filename => "t/data/Excel/t.xls");

ok(scalar $tr->translate(producer => "MySQL"));

ok($t->{Sheet1});
ok(not defined $t->{Sheet2});
ok(not defined $t->{Sheet3});

ok($t->{Sheet1}->{fields}->{ID}->{is_primary_key});
