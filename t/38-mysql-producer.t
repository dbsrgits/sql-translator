#!/usr/bin/perl -w
# vim:filetype=perl

#
# Note that the bulk of the testing for the mysql producer is in
# 08postgres-to-mysql.t. This test is for additional stuff that can't be tested
# using an Oracle schema as source e.g. extra attributes.
#

use strict;
use Test::More;
use Test::Exception;
use Test::SQL::Translator qw(maybe_plan);

use Data::Dumper;
use FindBin qw/$Bin/;

# Testing 1,2,3,4...
#=============================================================================

BEGIN {
    maybe_plan(2,
        'YAML',
        'SQL::Translator::Producer::MySQL',
        'Test::Differences',
    )
}
use Test::Differences;
use SQL::Translator;

# Main test.
{
my $yaml_in = <<EOSCHEMA;
---
schema:
  tables:
    thing:
      name: thing
      extra:
        mysql_table_type: InnoDB
        mysql_charset: latin1 
        mysql_collate: latin1_danish_ci 
      order: 1
      fields:
        name:
          name: name
          data_type: varchar
          size:
            - 32
          order: 1
        swedish_name:
          name: swedish_name
          data_type: varchar
          size: 32
          extra:
            mysql_charset: swe7
          order: 2
        description:
          name: description
          data_type: text
          extra:
            mysql_charset: utf8
            mysql_collate: utf8_general_ci
          order: 3
EOSCHEMA

my $mysql_out = <<EOSQL;
SET foreign_key_checks=0;

CREATE TABLE thing (
  name varchar(32),
  swedish_name varchar(32) CHARACTER SET swe7,
  description text CHARACTER SET utf8 COLLATE utf8_general_ci
) Type=InnoDB DEFAULT CHARACTER SET latin1 COLLATE latin1_danish_ci;

EOSQL

    my $sqlt;
    $sqlt = SQL::Translator->new(
        show_warnings  => 1,
        no_comments    => 1,
        from           => "YAML",
        to             => "MySQL",
    );

    my $out = $sqlt->translate(\$yaml_in)
    or die "Translate error:".$sqlt->error;
    ok $out ne ""                 ,"Produced something!";
    eq_or_diff $out, $mysql_out   ,"Output looks right";
}
