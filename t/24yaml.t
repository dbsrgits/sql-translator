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
schema:
  random:
    foo:
      extra: {}
      name: foo
      order: 2
      size:
        - 255
      type: varchar
    id:
      extra: {}
      name: id
      order: 1
      size:
        - 11
      type: int
    updated:
      extra: {}
      name: updated
      order: 3
      size:
        - 0
      type: timestamp
|;

my $out;
my $tr = SQL::Translator->new(
    parser   => "MySQL",
    producer => "YAML"
);


ok($out = $tr->translate(\$create), 'Translate MySQL to YAML');
eq_or_diff($out, $yaml, 'YAML matches expected');

