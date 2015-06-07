#!/usr/bin/perl
# vim: set ft=perl:

use strict;
use Test::More;
use Test::SQL::Translator qw(maybe_plan);

use SQL::Translator::Schema;
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
       name => 'some_table',
   );
   $table->add_field(
       name => 'id',
       data_type => 'integer',
       is_auto_increment => 1,
       is_nullable => 0,
       extra => {
           auto_increment_type => 'monotonic',
       },
   );
   $table->primary_key('id');
   my $expected = [ qq<CREATE TABLE "some_table" (\n  "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL\n)>];
   my $result =  [SQL::Translator::Producer::SQLite::create_table($table, { no_comments => 1 })];
   is_deeply($result, $expected, 'correctly built monotonicly autoincremened PK');
}

{
    my $table = SQL::Translator::Schema::Table->new( name => 'foobar', fields => ['foo'] );

    {
        my $index = $table->add_index(name => 'myindex', fields => ['foo']);
        my ($def) = SQL::Translator::Producer::SQLite::create_index($index);
        is($def, 'CREATE INDEX "myindex" ON "foobar" ("foo")', 'index created');
    }

    {
        my $index = $table->add_index(fields => ['foo']);
        my ($def) = SQL::Translator::Producer::SQLite::create_index($index);
        is($def, 'CREATE INDEX "foobar_idx" ON "foobar" ("foo")', 'index created');
    }

    {
        my $constr = $table->add_constraint(name => 'constr', fields => ['foo']);
        my ($def) = SQL::Translator::Producer::SQLite::create_constraint($constr);
        is($def, 'CREATE UNIQUE INDEX "constr" ON "foobar" ("foo")', 'constraint created');
    }

    {
        my $constr = $table->add_constraint(fields => ['foo']);
        my ($def) = SQL::Translator::Producer::SQLite::create_constraint($constr);
        is($def, 'CREATE UNIQUE INDEX "foobar_idx02" ON "foobar" ("foo")', 'constraint created');
    }
}

{
    my $schema = SQL::Translator::Schema->new();
    my $table = $schema->add_table( name => 'foo', fields => ['bar'] );

    {
        my $trigger = $schema->add_trigger(
            name                => 'mytrigger',
            perform_action_when => 'before',
            database_events     => 'update',
            on_table            => 'foo',
            fields              => ['bar'],
            action              => 'BEGIN baz() END'
        );
        my ($def) = SQL::Translator::Producer::SQLite::create_trigger($trigger);
        is($def, 'CREATE TRIGGER "mytrigger" before update on "foo" BEGIN baz() END', 'trigger created');
    }

    {
        my $trigger = $schema->add_trigger(
            name                => 'mytrigger2',
            perform_action_when => 'after',
            database_events     => ['insert'],
            on_table            => 'foo',
            fields              => ['bar'],
            action              => 'baz()'
        );
        my ($def) = SQL::Translator::Producer::SQLite::create_trigger($trigger);
        is($def, 'CREATE TRIGGER "mytrigger2" after insert on "foo" BEGIN baz() END', 'trigger created');
    }
}

{
    my $table = SQL::Translator::Schema::Table->new( name => 'foobar', fields => ['foo'] );
    my $constr = $table->add_constraint(name => 'constr', expression => "foo != 'baz'");
    my ($def) = SQL::Translator::Producer::SQLite::create_check_constraint($constr);

    is($def, q{CONSTRAINT "constr" CHECK(foo != 'baz')}, 'check constraint created');
}

done_testing;
