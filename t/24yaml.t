#!/usr/local/bin/perl
# vim: set ft=perl:

use strict;
use Test::More tests => 2;
use Test::Differences;
use SQL::Translator;

my $create = q|
CREATE TABLE random (
    id int auto_increment PRIMARY KEY,
    foo varchar(255) not null default '',
    updated timestamp
);
|;

my $yaml = q|--- #YAML:1.0
random:
    id: 
        order: 1
        name: id
        type: int
        size: 11
        extra: 
    foo: 
        order: 2
        name: foo
        type: varchar
        size: 255
        extra: 
    updated: 
        order: 3
        name: updated
        type: timestamp
        size: 0
        extra: 
|;

my $out;
my $tr = SQL::Translator->new(
    parser   => "MySQL",
    producer => "YAML"
);


ok($out = $tr->translate(\$create), 'Translate MySQL to YAML');
eq_or_diff($out, $yaml, 'YAML matches expected');

