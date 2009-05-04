#!/usr/bin/perl -w
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use Test::More;
use Test::Exception;
use Test::SQL::Translator qw(maybe_plan);

use Data::Dumper;

BEGIN {
    maybe_plan(4, 'YAML', 'Test::Differences')
}
use Test::Differences;
use SQL::Translator;

my $sqlt_version = $SQL::Translator::VERSION;

# The _GLOBAL_ table should be removed and its fields copied onto all other
# tables.
my $in_yaml = qq{---
schema:
  tables:
    _GLOBAL_:
      name: _GLOBAL_
      fields:
        modified:
          name: modified
          data_type: timestamp
      indices:
        - fields:
            - modified
      constraints:
        - fields:
            - modified
          type: UNIQUE
    Person:
      name: Person
      fields:
        first_name:
          data_type: foovar
          name: first_name
};

# Should include the the items added from the Global table defined above in the
# schema as well as those defined in the filter args below.
my $ans_yaml = qq{---
schema:
  procedures: {}
  tables:
    Person:
      constraints:
        - deferrable: 1
          expression: ''
          fields:
            - modified
          match_type: ''
          name: ''
          on_delete: ''
          on_update: ''
          options: []
          reference_fields: []
          reference_table: ''
          type: UNIQUE
      fields:
        created:
          data_type: timestamp
          default_value: ~
          extra: {}
          is_nullable: 0
          is_primary_key: 0
          is_unique: 0
          name: created
          order: 2
          size:
            - 0
        first_name:
          data_type: foovar
          default_value: ~
          extra: {}
          is_nullable: 1
          is_primary_key: 0
          is_unique: 0
          name: first_name
          order: 1
          size:
            - 0
        modified:
          data_type: timestamp
          default_value: ~
          extra: {}
          is_nullable: 1
          is_primary_key: 0
          is_unique: 1
          name: modified
          order: 3
          size:
            - 0
      indices:
        - fields:
            - created
          name: ''
          options: []
          type: NORMAL
        - fields:
            - modified
          name: ''
          options: []
          type: NORMAL
      name: Person
      options: []
      order: 2
  triggers: {}
  views: {}
translator:
  add_drop_table: 0
  filename: ~
  no_comments: 0
  parser_args: {}
  parser_type: SQL::Translator::Parser::YAML
  producer_args: {}
  producer_type: SQL::Translator::Producer::YAML
  show_warnings: 1
  trace: 0
  version: $sqlt_version
};


# Parse the test XML schema
my $obj;
$obj = SQL::Translator->new(
    debug         => 0,
    show_warnings => 1,
    from          => "YAML",
    to            => "YAML",
    data          => $in_yaml,
    filters => [
        # Filter from SQL::Translator::Filter::*
        [ 'Globals',
            # A global field to add given in the args
            fields => [
                {
                    name => 'created',
                    data_type => 'timestamp',
                    is_nullable => 0,
                }
            ],
            indices => [
                {
                    fields => 'created',
                }
            ],
        ],
    ],

) or die "Failed to create translator object: ".SQL::Translator->error;

my $out;
lives_ok { $out = $obj->translate; }  "Translate ran";
is $obj->error, ''                   ,"No errors";
ok $out ne ""                        ,"Produced something!";
eq_or_diff $out, $ans_yaml           ,"Output looks right";
#print "$out\n";
