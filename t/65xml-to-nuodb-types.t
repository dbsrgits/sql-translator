#!/usr/bin/perl
# vim: set ft=perl:
# Started with 56-sqlite-producer.t
use strict;
use Test::More;
use Test::SQL::Translator qw(maybe_plan);

use SQL::Translator::Schema;
use SQL::Translator::Schema::View;
use SQL::Translator::Schema::Table;
use SQL::Translator::Producer::NuoDB;

{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name => 'id',
       data_type => 'int',
       default_value => 1,
   );
   my $expected = "CREATE TABLE foo_table (\n  id INTEGER DEFAULT 1\n);";
   my @result =  SQL::Translator::Producer::NuoDB::create_table($table);
   is_deeply(@result[0], $expected, 'simple table');
}

{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name => 'f',
       data_type => 'varchar',
   );
   my $expected = "CREATE TABLE foo_table (\n  f STRING\n);";
   my @result =  SQL::Translator::Producer::NuoDB::create_table($table);
   is_deeply(@result[0], $expected, 'simple table');
}

{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name => 'f',
       data_type => 'text',
   );
   my $expected = "CREATE TABLE foo_table (\n  f STRING\n);";
   my @result =  SQL::Translator::Producer::NuoDB::create_table($table);
   is_deeply(@result[0], $expected, 'simple table');
}
done_testing;
