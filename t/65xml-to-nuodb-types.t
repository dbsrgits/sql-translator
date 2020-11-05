#!/usr/bin/perl
# vim: set ft=perl:
# Started with 56-sqlite-producer.t
use strict;
use Test::More;
use Test::SQL::Translator qw(maybe_plan);
use SQL::Translator::Schema;
use SQL::Translator::Schema::View;
use SQL::Translator::Schema::Table;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Producer::NuoDB;

{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name      => 'id',
       data_type => 'int',
       default_value => 1,
   );
   my $expected = "CREATE TABLE foo_table (\n  id INTEGER DEFAULT 1\n);";
   my @result =  SQL::Translator::Producer::NuoDB::create_table($table);
   is_deeply(@result[0], $expected, 'simple table');
}

# varchar
{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name      => 'f',
       data_type => 'varchar',
   );
   my $expected = "CREATE TABLE foo_table (\n  f STRING\n);";
   my @result =  SQL::Translator::Producer::NuoDB::create_table($table);
   is_deeply(@result[0], $expected, 'varchar to string');
}

# text
{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name      => 'f',
       data_type => 'text',
   );
   my $expected = "CREATE TABLE foo_table (\n  f STRING\n);";
   my @result =  SQL::Translator::Producer::NuoDB::create_table($table);
   is_deeply(@result[0], $expected, 'text to string');
}

# interval
{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name      => 'i',
       data_type => 'interval',
   );
   my $expected = "CREATE TABLE foo_table (\n  i INTEGER\n);";
   my @result =  SQL::Translator::Producer::NuoDB::create_table($table);
   is_deeply(@result[0], $expected, 'interval to integer');
}

# bytea
{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name      => 'b',
       data_type => 'bytea',
   );
   my $expected = "CREATE TABLE foo_table (\n  b BINARY\n);";
   my @result =  SQL::Translator::Producer::NuoDB::create_table($table);
   is_deeply(@result[0], $expected, 'bytea to binary');
}

# inet
{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name      => 'ip',
       data_type => 'inet',
   );
   my $expected = "CREATE TABLE foo_table (\n  ip STRING\n);";
   my @result =  SQL::Translator::Producer::NuoDB::create_table($table);
   is_deeply(@result[0], $expected, 'inet to string');
}


# default NOW()
{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name          => 'c',
       data_type     => 'timestamp',
       is_nullable   => 0,
       default_value => 'NOW()',
   );
   my $expected = "CREATE TABLE foo_table (\n  c TIMESTAMP NOT NULL DEFAULT NOW()\n);";
   my @result =  SQL::Translator::Producer::NuoDB::create_table($table);
   is_deeply(@result[0], $expected, 'NOW() stays NOW()');
}

# without time zone
{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name          => 'c',
       data_type     => 'timestamp WITHOUT TIME ZONE',
       is_nullable   => 1,
   );
   my $expected = "CREATE TABLE foo_table (\n  c TIMESTAMP\n);";
   my @result =  SQL::Translator::Producer::NuoDB::create_table($table);
   is_deeply(@result[0], $expected, 'Ignore WITHOUT TIME ZONE');
}


# reserved word field
{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name      => 'set',
       data_type => 'integer',
   );
   $table->add_field(
       name      => 'string',
       data_type => 'integer',
   );
   $table->add_field(
       name      => 'schema',
       data_type => 'integer',
   );
   $table->add_field(
       name      => 'part',
       data_type => 'integer',
   );
   $table->add_field(
       name      => 'lock',
       data_type => 'integer',
   );
   $table->add_field(
       name      => 'path',
       data_type => 'integer',
   );
   $table->add_field(
       name      => 'get',
       data_type => 'integer',
   );
   my $expected = "CREATE TABLE foo_table (\n  \"set\" INTEGER,\n  \"string\" INTEGER,\n  \"schema\" INTEGER,\n  \"part\" INTEGER,\n  \"lock\" INTEGER,\n  \"path\" INTEGER,\n  \"get\" INTEGER\n);";
   my @result =  SQL::Translator::Producer::NuoDB::create_table($table);
   is_deeply(@result[0], $expected, 'reserved word field');
}

# reserved word field used in constraint
{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );

   my $fk_constraint = SQL::Translator::Schema::Constraint->new(
       table  => $table,
       name   => 'foo_table_string',
       type   => FOREIGN_KEY,
       fields  => 'string',
       reference_table => 'area',
       reference_fields => 'id',
   );

   my $expected = "ALTER TABLE foo_table ADD CONSTRAINT foo_table_string FOREIGN KEY (\"string\") REFERENCES area(id);";
   my ($result, $result_fk) =  SQL::Translator::Producer::NuoDB::create_constraint($fk_constraint);
   is($result_fk->[0], $expected, 'reserved word field in constraint');
}

# reserved word field used in index
{
  my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
       fields => [qw(string,set)],
  );

  my $index = $table->add_index(name => 'myindex', fields => ['string,set']);
  my ($def) = SQL::Translator::Producer::NuoDB::create_index($index);
  is($def, 'CREATE INDEX myindex ON foo_table ("string", "set");', 'reserved word field index');
}

# primary key
{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name           => 'code',
       data_type      => 'integer',
       is_nullable    => 0,
       is_primary_key => 1
   );
   $table->add_constraint(
       fields => 'code',
       type   => PRIMARY_KEY,
   );
   my $expected = "CREATE TABLE foo_table (\n  code INTEGER NOT NULL,\n  PRIMARY KEY (code)\n);";
   my @result =  SQL::Translator::Producer::NuoDB::create_table($table);
   is_deeply(@result[0], $expected, 'simple table');
}

# constraint name
{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );

   my $fk_constraint = SQL::Translator::Schema::Constraint->new(
       table  => $table,
       name   => 'foo_table_code',
       type   => FOREIGN_KEY,
       fields  => 'code',
       reference_table => 'area',
       reference_fields => 'id',
   );

   my $expected = "ALTER TABLE foo_table ADD CONSTRAINT foo_table_code FOREIGN KEY (code) REFERENCES area(id);";
   my ($result, $result_fk) =  SQL::Translator::Producer::NuoDB::create_constraint($fk_constraint);
   is($result_fk->[0], $expected, 'named foreign constraint');
}

# int identity
{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name           => 'id',
       data_type      => 'integer',
       is_auto_increment => 1,
       is_nullable    => 0,
       is_primary_key => 1
   );
   $table->add_constraint(
       fields => 'id',
       type   => PRIMARY_KEY,
   );
   my $expected = "CREATE TABLE foo_table (\n  id INTEGER GENERATED BY DEFAULT AS IDENTITY NOT NULL,\n  PRIMARY KEY (id)\n);";
   my @result =  SQL::Translator::Producer::NuoDB::create_table($table);
   is_deeply(@result[0], $expected, 'int identity');
}

# bigint identity
{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name           => 'id',
       data_type      => 'bigint',
       is_auto_increment => 1,
       is_nullable    => 0,
       is_primary_key => 1
   );
   $table->add_constraint(
       fields => 'id',
       type   => PRIMARY_KEY,
   );
   my $expected = "CREATE TABLE foo_table (\n  id BIGINT GENERATED BY DEFAULT AS IDENTITY NOT NULL,\n  PRIMARY KEY (id)\n);";
   my @result =  SQL::Translator::Producer::NuoDB::create_table($table);
   is_deeply(@result[0], $expected, 'bitint identity');
}

done_testing;
