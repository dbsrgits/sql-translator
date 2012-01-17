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

my $in_yaml = qq{---
schema:
  tables:
    Person:
      name: Person
      fields:
        first_name:
          data_type: foovar
          name: first_name
};

my $ans_yaml = qq{---
schema:
  procedures: {}
  tables:
    person:
      constraints: []
      fields:
        First_name:
          data_type: foovar
          default_value: ~
          is_nullable: 1
          is_primary_key: 0
          is_unique: 0
          name: First_name
          order: 1
          size:
            - 0
      indices: []
      name: person
      options: []
      order: 1
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
  version: SUPPRESSED
};

# Parse the test schema
my $obj;
$obj = SQL::Translator->new(
    debug         => 0,
    show_warnings => 1,
    from          => "YAML",
    to            => "YAML",
    data          => $in_yaml,
    filters => [
        # Filter from SQL::Translator::Filter::*
        [ 'Names', {
            tables => 'lc',
            fields => 'ucfirst',
        } ],
    ],

) or die "Failed to create translator object: ".SQL::Translator->error;

my $out;
lives_ok { $out = $obj->translate; }  "Translate ran";
is $obj->error, ''                   ,"No errors";
ok $out ne ""                        ,"Produced something!";
# Somewhat hackishly modify the yaml with a regex to avoid
# failing randomly on every change of version.
$out =~ s/version: .*/version: SUPPRESSED/;
eq_or_diff $out, $ans_yaml           ,"Output looks right";
