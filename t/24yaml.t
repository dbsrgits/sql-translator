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
  procedures: {}
  tables:
    random:
      comments: ''
      fields:
        foo:
          data_type: varchar
          default_value: ''
          extra: {}
          is_nullable: 0
          is_primary_key: 0
          is_unique: 0
          name: foo
          order: 2
          size:
            - 255
        id:
          data_type: int
          default_value: ~
          extra: {}
          is_nullable: 0
          is_primary_key: 1
          is_unique: 0
          name: id
          order: 1
          size:
            - 11
        updated:
          data_type: timestamp
          default_value: ~
          extra: {}
          is_nullable: 1
          is_primary_key: 0
          is_unique: 0
          name: updated
          order: 3
          size:
            - 0
      indices: {}
      name: random
      options: []
      order: 1
  triggers: {}
  views: {}
|;

my $out;
my $tr = SQL::Translator->new(
    parser   => "MySQL",
    producer => "YAML"
);


ok($out = $tr->translate(\$create), 'Translate MySQL to YAML');
eq_or_diff($out, $yaml, 'YAML matches expected');

