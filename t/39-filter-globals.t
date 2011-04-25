#!/usr/bin/perl -w
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use Test::More;
use Test::Exception;
use Test::SQL::Translator qw(maybe_plan);

BEGIN {
    maybe_plan(3, 'YAML', 'Test::Differences')
}
use Test::Differences;
use SQL::Translator;

# The _GLOBAL_ table should be removed and its fields copied onto all other
# tables.
#
# FIXME - the loader should not require order for globals, needs to be able
# to recognize/sort approproately
my $in_yaml = qq{---
schema:
  tables:
    _GLOBAL_:
      order: 99
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
      order: 1
      name: Person
      fields:
        first_name:
          data_type: foovar
          name: first_name
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

my $struct;
lives_ok { $struct = YAML::Load($obj->translate) }  "Translate/yaml reload ran";
is $obj->error, '', "No errors";

# Should include the the items added from the Global table defined above in the
# schema as well as those defined in the filter args below.
is_deeply ($struct, {
  schema => {
    procedures => {},
    tables => {
      Person => {
        constraints => [
          {
            deferrable => 1,
            expression => "",
            fields => [
              "modified"
            ],
            match_type => "",
            name => "",
            on_delete => "",
            on_update => "",
            options => [],
            reference_fields => [],
            reference_table => "",
            type => "UNIQUE"
          }
        ],
        fields => {
          first_name => {
            data_type => "foovar",
            default_value => undef,
            is_nullable => 1,
            is_primary_key => 0,
            is_unique => 0,
            name => "first_name",
            order => 1,
            size => [
              0
            ]
          },
          created => {
            data_type => "timestamp",
            default_value => undef,
            is_nullable => 0,
            is_primary_key => 0,
            is_unique => 0,
            name => "created",
            order => 2,
            size => [
              0
            ]
          },
          modified => {
            data_type => "timestamp",
            default_value => undef,
            is_nullable => 1,
            is_primary_key => 0,
            is_unique => 1,
            name => "modified",
            order => 3,
            size => [
              0
            ]
          }
        },
        indices => [
          {
            fields => [
              "created"
            ],
            name => "",
            options => [],
            type => "NORMAL"
          },
          {
            fields => [
              "modified"
            ],
            name => "",
            options => [],
            type => "NORMAL"
          }
        ],
        name => "Person",
        options => [],
        order => 1
      }
    },
    triggers => {},
    views => {}
  },
  translator => {
    add_drop_table => 0,
    filename => undef,
    no_comments => 0,
    parser_args => {},
    parser_type => "SQL::Translator::Parser::YAML",
    producer_args => {},
    producer_type => "SQL::Translator::Producer::YAML",
    show_warnings => 1,
    trace => 0,
    version => $SQL::Translator::VERSION,
  }
}, 'Expected final yaml-schema');
