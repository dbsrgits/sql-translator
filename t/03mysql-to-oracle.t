#!/usr/local/bin/perl
# vim: set ft=perl:

use strict;
use Test::More;
use SQL::Translator;
use Test::SQL::Translator qw(maybe_plan);

my $create = q|
CREATE TABLE random (
    id int auto_increment PRIMARY KEY,
    foo varchar(255) not null default '',
    updated timestamp
);
CREATE UNIQUE INDEX random_foo_update ON random(foo,updated);
CREATE INDEX random_foo ON random(foo);

|;

BEGIN {
    maybe_plan(3,
        'SQL::Translator::Parser::MySQL',
        'SQL::Translator::Producer::Oracle');
}

my $tr       = SQL::Translator->new(
    parser   => "MySQL",
    producer => "Oracle",
    quote_table_names => 0,
    quote_field_names => 0,
);

my $output = $tr->translate(\$create);

ok( $output, 'Translate MySQL to Oracle' );
ok( $output =~ /CREATE INDEX random_foo /, 'Normal index definition translated.');
ok( $output =~ /CREATE UNIQUE INDEX random_foo_update /, 'Unique index definition translated.');
