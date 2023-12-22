#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::SQL::Translator qw(maybe_plan);

use Data::Dumper;
use FindBin qw/$Bin/;

# Testing 1,2,3,4...
#=============================================================================

BEGIN {
  maybe_plan(6, 'SQL::Translator::Producer::DB2', 'Test::Differences',);
}
use Test::Differences;
use SQL::Translator;

my $table = SQL::Translator::Schema::Table->new(name => 'mytable');

my $field1 = SQL::Translator::Schema::Field->new(
  name              => 'myfield',
  table             => $table,
  data_type         => 'VARCHAR',
  size              => 10,
  default_value     => undef,
  is_auto_increment => 0,
  is_nullable       => 1,
  is_foreign_key    => 0,
  is_unique         => 0
);

my $field1_sql = SQL::Translator::Producer::DB2::create_field($field1);

is($field1_sql, 'myfield VARCHAR(10)', 'Create field works');

my $field2 = SQL::Translator::Schema::Field->new(
  name              => 'myfield',
  table             => $table,
  data_type         => 'VARCHAR',
  size              => 25,
  default_value     => undef,
  is_auto_increment => 0,
  is_nullable       => 0,
  is_foreign_key    => 0,
  is_unique         => 0
);

my $alter_field = SQL::Translator::Producer::DB2::alter_field($field1, $field2);
is($alter_field, 'ALTER TABLE mytable ALTER myfield SET DATATYPE VARCHAR(25)', 'Alter field works');

my $add_field = SQL::Translator::Producer::DB2::add_field($field1);

is($add_field, 'ALTER TABLE mytable ADD COLUMN myfield VARCHAR(10)', 'Add field works');

my $index = $table->add_index(name => 'myindex', fields => ['foo']);
my ($def) = SQL::Translator::Producer::DB2::create_index($index);
is($def, 'CREATE INDEX myindex ON mytable ( foo );', 'index created');

my $index2 = $table->add_index(
  name   => 'myindex',
  fields => [ { name => 'foo', prefix_length => 15 } ]
);
my ($def2) = SQL::Translator::Producer::DB2::create_index($index);
is($def2, 'CREATE INDEX myindex ON mytable ( foo );', 'index created');

my $drop_field = SQL::Translator::Producer::DB2::drop_field($field2);
is($drop_field, '', 'Drop field works');
