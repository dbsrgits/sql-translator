#!/usr/local/bin/perl
# vim: set ft=perl:

BEGIN { print "1..1\n" }

my $create = q|
CREATE TABLE random (
    id int auto_increment PRIMARY KEY,
    foo varchar(255) not null default '',
    updated timestamp
);
|;

use SQL::Translator;
use Data::Dumper;

$SQL::Translator::DEBUG = 0;

my $tr = SQL::Translator->new(parser   => "MySQL",
                              producer => "Oracle"
                              #producer => "SQL::Translator::Producer::Oracle::translate"
                              #producer => sub { Dumper($_[1]) }
                             );

print "not " unless ($tr->translate(\$create));
print "ok 1 # pointless test -- plz fix me!\n";

