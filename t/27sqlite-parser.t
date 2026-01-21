#!/usr/bin/perl
# vim: set ft=perl:

use strict;
use Test::More;
use Test::SQL::Translator qw(maybe_plan);
use FindBin               qw/$Bin/;

use SQL::Translator;
use SQL::Translator::Schema::Constants;

BEGIN {
  maybe_plan(64, 'SQL::Translator::Parser::SQLite');
}
SQL::Translator::Parser::SQLite->import('parse');

my $file = "$Bin/data/sqlite/create.sql";

{
  local $/;
  open my $fh, "<$file" or die "Can't read file '$file': $!\n";
  my $data = <$fh>;
  my $t    = SQL::Translator->new;
  parse($t, $data);

  my $schema = $t->schema;

  my @tables = $schema->get_tables;
  is(scalar @tables, 2, 'Parsed two tables');

  my $t1 = shift @tables;
  is($t1->name, 'person', "'Person' table");
  is_deeply([ $t1->comments ], [ q(table comment 1), q(table comment 2), q(table comment 3) ], 'person table comments');

  my @fields = $t1->get_fields;
  is(scalar @fields, 6, 'Six fields in "person" table');
  my $fld1 = shift @fields;
  is($fld1->name,              'person_id', 'First field is "person_id"');
  is($fld1->is_auto_increment, 1,           'Is an autoincrement field');

  my $t2 = shift @tables;
  is($t2->name, 'pet', "'Pet' table");

  my @constraints = $t2->get_constraints;
  is(scalar @constraints, 3, '3 constraints on pet');

  my $c1 = pop @constraints;
  is($c1->type,                        'FOREIGN KEY', 'FK constraint');
  is($c1->reference_table,             'person',      'References person table');
  is(join(',', $c1->reference_fields), 'person_id',   'References person_id field');

  my $c0 = shift @constraints;
  is($c0->type,       'CHECK',     'CHECK constraint');
  is($c0->expression, 'age < 100', 'contraint expression');
  is_deeply([ $c0->field_names ], ['age'], 'fields that check refers to');
  is($c0->table, 'pet', 'table name is pet');

  my @views = $schema->get_views;
  is(scalar @views, 1, 'Parsed one views');

  my @triggers = $schema->get_triggers;
  is(scalar @triggers, 1, 'Parsed one triggers');
}

$file = "$Bin/data/sqlite/named.sql";
{
  local $/;
  open my $fh, "<$file" or die "Can't read file '$file': $!\n";
  my $data = <$fh>;
  my $t    = SQL::Translator->new;
  parse($t, $data);

  my $schema = $t->schema;

  my @tables = $schema->get_tables;
  is(scalar @tables, 1, 'Parsed one table');

  my $t1 = shift @tables;
  is($t1->name, 'pet', "'Pet' table");

  my @constraints = $t1->get_constraints;
  is(scalar @constraints, 5, '5 constraints on pet');

  my $c0 = $constraints[0];
  is($c0->type, 'CHECK',         'constraint has correct type');
  is($c0->name, 'age_under_100', 'constraint check has correct name');
  is_deeply([ $c0->field_names ], ['age'], 'fields that check refers to');
  is($c0->table,      'pet',                                 'table name is pet');
  is($c0->expression, 'age < 100 and age not in (101, 102)', 'constraint expression');

  my $c1 = $constraints[2];
  is($c1->type,                        'FOREIGN KEY',  'FK constraint');
  is($c1->reference_table,             'person',       'References person table');
  is($c1->name,                        'fk_person_id', 'Constraint name fk_person_id');
  is($c1->on_delete,                   'RESTRICT',     'On delete restrict');
  is($c1->on_update,                   'CASCADE',      'On update cascade');
  is(join(',', $c1->reference_fields), 'person_id',    'References person_id field');

  my $c2 = $constraints[3];
  is($c2->on_delete, 'SET DEFAULT', 'On delete set default');
  is($c2->on_update, 'SET NULL',    'On update set null');

  my $c3 = $constraints[4];
  is($c3->on_update, 'NO ACTION', 'On update no action');
  is($c3->on_delete, '',          'On delete not defined');

}

$file = "$Bin/data/sqlite/checks.sql";
{
  local $/;
  open my $fh, "<$file" or die "Can't read file '$file': $!\n";
  my $data = <$fh>;
  my $t    = SQL::Translator->new(trace => 0, debug => 0);
  parse($t, $data);

  my $schema = $t->schema;

  my @tables = $schema->get_tables;
  is(scalar @tables, 2, 'Parsed one table');

  is($tables[0]->name, 'pet',        "'Pet' table");
  is($tables[1]->name, 'zoo_animal', "'Zoo Amimal' table");

  for my $t1 (@tables) {
    my @fields = $t1->get_fields;
    is(scalar @fields, 4, 'Four fields in "pet" table');

    my $visits = $fields[3];
    is($visits->name,          'vet_visits', 'field name correct');
    is($visits->default_value, '[]',         'default value is empty array');
    is($visits->is_nullable,   0,            'not null');

    my @constraints = $t1->get_constraints;
    is(scalar @constraints, 2, '2 constraints on pet');

    my $c0 = $constraints[0];
    is($c0->type, 'CHECK', 'constraint has correct type');
    is_deeply([ $c0->field_names ], ['vet_visits'], 'fields that check refers to');
    is($c0->table,      $t1->name,                                                     'table name is pet');
    is($c0->expression, q{json_valid(vet_visits) and json_type(vet_visits) = 'array'}, 'constraint expression');

    my $c1 = $constraints[1];
    is($c1->type,              'PRIMARY KEY',      'PK constraint');
    is($c1->table,             $t1->name,          'pet table');
    is($c1->name,              'pk_pet',           'Constraint name pk_pet');
    is(join(',', $c1->fields), 'pet_id,person_id', 'References person_id field');
  }
}
