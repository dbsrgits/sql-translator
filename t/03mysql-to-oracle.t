#!/usr/local/bin/perl
# vim: set ft=perl:

use Test::More;

plan tests => 1;

my $create = q|
CREATE TABLE random (
    id int auto_increment PRIMARY KEY,
    foo varchar(255) not null default '',
    updated timestamp
);
|;

use SQL::Translator;
use Data::Dumper;

my $tr = SQL::Translator->new(parser   => "MySQL",
                              producer => "Oracle"
                             );

ok($tr->translate(\$create));

