#!/usr/bin/perl
# vim: set ft=perl ts=4 et:
#

use strict;

use FindBin qw/$Bin/;
use Test::More 'no_plan'; #tests => 1;
use SQL::Translator;
use SQL::Translator::Parser::Sybase qw(parse);

my $file = "$Bin/data/sybase/create.sql";

ok( -e $file, "File exists" );

my $t = SQL::Translator->new;

my $val = parse($t, $file);

my $schema = $t->schema;
is( $schema->is_valid, 1, 'Schema is valid' );
my @tables = $schema->get_tables;
