#!/usr/bin/perl
# vim: set ft=perl:

use strict;
use Test::More;
use Test::SQL::Translator qw(maybe_plan);

use SQL::Translator::Schema::View;
use SQL::Translator::Schema::Table;
use SQL::Translator::Producer::SQLite;
$SQL::Translator::Producer::SQLite::NO_QUOTES = 0;

{
  my $view1 = SQL::Translator::Schema::View->new( name => 'view_foo',
                                                  fields => [qw/id name/],
                                                  sql => 'SELECT id, name FROM thing',
                                                  extra => {
                                                    temporary => 1,
                                                    if_not_exists => 1,
                                                  });
  my $create_opts = { no_comments => 1 };
  my $view1_sql1 = [ SQL::Translator::Producer::SQLite::create_view($view1, $create_opts) ];

  my $view_sql_replace = [ 'CREATE TEMPORARY VIEW IF NOT EXISTS "view_foo" AS
    SELECT id, name FROM thing' ];
  is_deeply($view1_sql1, $view_sql_replace, 'correct "CREATE TEMPORARY VIEW" SQL');


  my $view2 = SQL::Translator::Schema::View->new( name => 'view_foo',
                                                  fields => [qw/id name/],
                                                  sql => 'SELECT id, name FROM thing',);

  my $view1_sql2 = [ SQL::Translator::Producer::SQLite::create_view($view2, $create_opts) ];
  my $view_sql_noreplace = [ 'CREATE VIEW "view_foo" AS
    SELECT id, name FROM thing' ];
  is_deeply($view1_sql2, $view_sql_noreplace, 'correct "CREATE VIEW" SQL');
}
{
    my $create_opts;

    my $table = SQL::Translator::Schema::Table->new(
        name => 'foo_table',
    );
    $table->add_field(
        name => 'foreign_key',
        data_type => 'integer',
        default_value => 1,
    );
    my $constraint = SQL::Translator::Schema::Constraint->new(
        table => $table,
        name => 'fk',
        type => 'FOREIGN_KEY',
        fields => ['foreign_key'],
        reference_fields => ['id'],
        reference_table => 'foo',
        on_delete => 'RESTRICT',
        on_update => 'CASCADE',
    );
    my $expected = [ 'FOREIGN KEY ("foreign_key") REFERENCES "foo"("id") ON DELETE RESTRICT ON UPDATE CASCADE'];
    my $result =  [SQL::Translator::Producer::SQLite::create_foreignkey($constraint,$create_opts)];
    is_deeply($result, $expected, 'correct "FOREIGN KEY"');
}
{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name => 'id',
       data_type => 'integer',
       default_value => 1,
   );
   my $expected = [ qq<CREATE TABLE "foo_table" (\n  "id" integer DEFAULT 1\n)>];
   my $result =  [SQL::Translator::Producer::SQLite::create_table($table, { no_comments => 1 })];
   is_deeply($result, $expected, 'correctly unquoted DEFAULT');
}

{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo',
   );
   $table->add_field(
       name => 'data',
       data_type => 'bytea',
   );
   $table->add_field(
       name => 'data2',
       data_type => 'set',
   );
   $table->add_field(
       name => 'data2',
       data_type => 'set',
   );
   $table->add_field(
       name => 'data3',
       data_type => 'text',
       size      => 30,
   );
   $table->add_field(
       name => 'data4',
       data_type => 'blob',
       size      => 30,
   );
   my $expected = [ qq<CREATE TABLE "foo" (
  "data" blob,
  "data2" varchar,
  "data3" text,
  "data4" blob
)>];
   my $result =  [SQL::Translator::Producer::SQLite::create_table($table, { no_comments => 1 })];
   is_deeply($result, $expected, 'correctly translated bytea to blob');
}

{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name => 'id',
       data_type => 'integer',
       default_value => \'gunshow',
   );
   my $expected = [ qq<CREATE TABLE "foo_table" (\n  "id" integer DEFAULT gunshow\n)>];
   my $result =  [SQL::Translator::Producer::SQLite::create_table($table, { no_comments => 1 })];
   is_deeply($result, $expected, 'correctly unquoted DEFAULT');
}

{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_table',
   );
   $table->add_field(
       name => 'id',
       data_type => 'integer',
       default_value => 'frew',
   );
   my $expected = [ qq<CREATE TABLE "foo_table" (\n  "id" integer DEFAULT 'frew'\n)>];
   my $result =  [SQL::Translator::Producer::SQLite::create_table($table, { no_comments => 1 })];
   is_deeply($result, $expected, 'correctly quoted DEFAULT');
}

{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo',
   );
   $table->add_field(
       name => 'id',
       data_type => 'integer',
       default_value => 'NULL',
   );
   $table->add_field(
       name => 'when',
       default_value => 'now()',
   );
   $table->add_field(
       name => 'at',
       default_value => 'CURRENT_TIMESTAMP',
   );
   my $expected = [ qq<CREATE TABLE "foo" (
  "id" integer DEFAULT NULL,
  "when"  DEFAULT now(),
  "at"  DEFAULT CURRENT_TIMESTAMP
)>];
   my $result =  [SQL::Translator::Producer::SQLite::create_table($table, { no_comments => 1 })];
   is_deeply($result, $expected, 'correctly unquoted excempted DEFAULTs');
}

{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_auto_increment',
   );
   $table->add_field(
       name => 'id',
       data_type => 'integer',
       is_nullable => 0,
       is_auto_increment => 1,
   );
   $table->primary_key('id');
   my $expected = [ qq<CREATE TABLE "foo_auto_increment" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
)>];
   my $result =  [SQL::Translator::Producer::SQLite::create_table($table, { no_comments => 1 })];
   is_deeply($result, $expected, 'correctly built table with autoincrement on primary key');
}

{
   my $table = SQL::Translator::Schema::Table->new(
       name => 'foo_no_auto_increment',
   );
   $table->add_field(
       name => 'id',
       data_type => 'integer',
       is_nullable => 0,
       is_auto_increment => 0,
   );
   $table->primary_key('id');
   my $expected = [ qq<CREATE TABLE "foo_no_auto_increment" (
  "id" INTEGER PRIMARY KEY NOT NULL
)>];
   my $result =  [SQL::Translator::Producer::SQLite::create_table($table, { no_comments => 1 })];
   is_deeply($result, $expected, 'correctly built table without autoincrement on primary key');
}

done_testing;
