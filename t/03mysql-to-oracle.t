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
|;

BEGIN {
    maybe_plan(1, 
        'SQL::Translator::Parser::MySQL',
        'SQL::Translator::Producer::Oracle');
}

my $tr       = SQL::Translator->new(
    parser   => "MySQL",
    producer => "Oracle"
);

ok( $tr->translate(\$create), 'Translate MySQL to Oracle' );

