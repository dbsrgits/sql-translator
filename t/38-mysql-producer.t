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
    maybe_plan(6,
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
        mysql_charset: latin1 
        mysql_collate: latin1_danish_ci 
      order: 1
      fields:
        id:
          name: id
          data_type: unsigned int
          is_primary_key: 1
          is_auto_increment: 1
          order: 0
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
    thing2:
      name: thing2
      extra:
      order: 2
      fields:
        id:
          name: id
          data_type: int
          is_primary_key: 0
          order: 0
          is_foreign_key: 1
        foo:
          name: foo
          data_type: int
          order: 1
          is_not_null: 1
      constraints:
        - type: PRIMARY_KEY
          fields:
            - id
            - foo
        - reference_table: thing
          type: FOREIGN_KEY
          fields: foo
          name: fk_thing

EOSCHEMA

my $mysql_out = <<EOSQL;
SET foreign_key_checks=0;

CREATE TABLE thing (
  id unsigned int auto_increment,
  name varchar(32),
  swedish_name varchar(32) CHARACTER SET swe7,
  description text CHARACTER SET utf8 COLLATE utf8_general_ci,
  INDEX (id),
  PRIMARY KEY (id)
) Type=InnoDB DEFAULT CHARACTER SET latin1 COLLATE latin1_danish_ci;

CREATE TABLE thing2 (
  id integer,
  foo integer,
  INDEX (id),
  INDEX (foo),
  PRIMARY KEY (id, foo),
  CONSTRAINT thing2_fk_thing FOREIGN KEY (foo) REFERENCES thing (id)
) Type=InnoDB;

SET foreign_key_checks=1;

EOSQL

    my $sqlt;
    $sqlt = SQL::Translator->new(
        show_warnings  => 1,
        no_comments    => 1,
#        debug          => 1,
        from           => "YAML",
        to             => "MySQL",
    );

    my $out = $sqlt->translate(\$yaml_in)
    or die "Translate error:".$sqlt->error;
    ok $out ne ""                 ,"Produced something!";
    eq_or_diff $out, $mysql_out   ,"Output looks right";
}

###############################################################################
# New alter/add subs

my $table = SQL::Translator::Schema::Table->new( name => 'mytable');

my $field1 = SQL::Translator::Schema::Field->new( name => 'myfield',
                                                  table => $table,
                                                  data_type => 'VARCHAR',
                                                  size => 10,
                                                  default_value => undef,
                                                  is_auto_increment => 0,
                                                  is_nullable => 1,
                                                  is_foreign_key => 0,
                                                  is_unique => 0 );

my $field1_sql = SQL::Translator::Producer::MySQL::create_field($field1);

is($field1_sql, 'myfield VARCHAR(10)', 'Create field works');

my $field2 = SQL::Translator::Schema::Field->new( name      => 'myfield',
                                                  table => $table,
                                                  data_type => 'VARCHAR',
                                                  size      => 25,
                                                  default_value => undef,
                                                  is_auto_increment => 0,
                                                  is_nullable => 0,
                                                  is_foreign_key => 0,
                                                  is_unique => 0 );

my $alter_field = SQL::Translator::Producer::MySQL::alter_field($field1,
                                                                $field2);
is($alter_field, 'ALTER TABLE mytable CHANGE COLUMN myfield myfield VARCHAR(25) NOT NULL', 'Alter field works');

my $add_field = SQL::Translator::Producer::MySQL::add_field($field1);

is($add_field, 'ALTER TABLE mytable ADD COLUMN myfield VARCHAR(10)', 'Add field works');

my $drop_field = SQL::Translator::Producer::MySQL::drop_field($field2);
is($drop_field, 'ALTER TABLE mytable DROP COLUMN myfield', 'Drop field works');
