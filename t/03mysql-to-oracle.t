#!/usr/local/bin/perl
# vim: set ft=perl:

use strict;
use Test::More tests => 1;
use SQL::Translator;

my $create = q|
CREATE TABLE random (
    id int auto_increment PRIMARY KEY,
    foo varchar(255) not null default '',
    updated timestamp
);
|;

my $tr       = SQL::Translator->new(
    parser   => "MySQL",
    producer => "Oracle"
);

ok( $tr->translate(\$create), 'Translate MySQL to Oracle' );

