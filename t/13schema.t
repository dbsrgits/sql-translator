#!/usr/bin/perl

$| = 1;

use strict;
use Test::More 'no_plan'; # plans => 1;

require_ok( 'SQL::Translator::Schema' );

#
# Schema
#
my $schema = SQL::Translator::Schema->new;

isa_ok( $schema, 'SQL::Translator::Schema' );
is( $schema->is_valid, undef, 'Schema not valid...' );
like( $schema->error, qr/no tables/i, '...because there are no tables' );

#
# Table default new
#
my $foo_table = $schema->add_table(name => 'foo') or warn $schema->error;
isa_ok( $foo_table, 'SQL::Translator::Schema::Table', 'Schema' );
is( $foo_table->name, 'foo', 'Table name is "foo"' );
is( $foo_table->is_valid, undef, 'Table is not yet valid' );

my $fields = $foo_table->get_fields;
is( scalar @{ $fields || [] }, 0, 'No fields' );
like( $foo_table->error, qr/no fields/i, 'Error for no fields' );

#
# New table with args
#
my $person_table = $schema->add_table( name => 'person' );
is( $person_table->name, 'person', 'Table name is "person"' );
is( $person_table->is_valid, undef, 'Table is still not valid' );

#
# Field default new
#
my $name = $person_table->add_field(name => 'foo') or warn $person_table->error;
isa_ok( $name, 'SQL::Translator::Schema::Field', 'Field' );
is( $name->name, 'foo', 'Field name is "foo"' );
is( $name->data_type, '', 'Field data type is blank' );
is( $name->size, 0, 'Field size is "0"' );
is( $name->is_primary_key, '0', 'Field is_primary_key is false' );

#
# Field methods
#
is( $name->name('person_name'), 'person_name', 'Field name is "person_name"' );
is( $name->data_type('varchar'), 'varchar', 'Field data type is "varchar"' );
is( $name->size(30), '30', 'Field size is "30"' );
is( $name->is_primary_key(0), '0', 'Field is_primary_key is negative' );

#
# New field with args
#
my $age       = $person_table->add_field(
    name      => 'age',
    data_type => 'integer',
    size      => 3,
);
is( $age->name, 'age', 'Field name is "age"' );
is( $age->data_type, 'integer', 'Field data type is "integer"' );
is( $age->size, '3', 'Field size is "3"' );

#
# Index
#
my @indices = $person_table->get_indices;
is( scalar @indices, 0, 'No indices' );
like( $person_table->error, qr/no indices/i, 'Error for no indices' );
my $index = $person_table->add_index( name => "foo" ) 
    or warn $person_table->error;
isa_ok( $index, 'SQL::Translator::Schema::Index', 'Index' );
my $indices = $person_table->get_indices;
is( scalar @$indices, 1, 'One index' );
is( $indices->[0]->name, 'foo', '"foo" index' );

#
# Constraint
#
my @constraints = $person_table->get_constraints;
is( scalar @constraints, 0, 'No constraints' );
like( $person_table->error, qr/no constraints/i, 'Error for no constraints' );
my $constraint = $person_table->add_constraint( name => 'foo' ) 
    or warn $person_table->error;
isa_ok( $constraint, 'SQL::Translator::Schema::Constraint', 'Constraint' );
my $constraints = $person_table->get_constraints;
is( scalar @$constraints, 1, 'One constraint' );
is( $constraints->[0]->name, 'foo', '"foo" constraint' );

#
# View
#
my $view = $schema->add_view( name => 'view1' ) or warn $schema->error;
isa_ok( $view, 'SQL::Translator::Schema::View', 'View' );
my $view_sql = 'select * from table';
is( $view->sql( $view_sql ), $view_sql, 'View SQL is good' );

#
# $schema->get_*
#
my $bad_table = $schema->get_table;
like( $schema->error, qr/no table/i, 'Error on no arg to get_table' );

$bad_table = $schema->get_table('bar');
like( $schema->error, qr/does not exist/i, 
    'Error on bad arg to get_table' );

my $bad_view = $schema->get_view;
like( $schema->error, qr/no view/i, 'Error on no arg to get_view' );

$bad_view = $schema->get_view('bar');
like( $schema->error, qr/does not exist/i, 
    'Error on bad arg to get_view' );

my $good_table = $schema->get_table('foo');
isa_ok( $good_table, 'SQL::Translator::Schema::Table', 'Table "foo"' );

my $good_view = $schema->get_view('view1');
isa_ok( $good_view, 'SQL::Translator::Schema::View', 'View "view1"' );
is( $view->sql( $view_sql ), $view_sql, 'View SQL is good' );

#
# $schema->get_*s
#
my @tables = $schema->get_tables;
is( scalar @tables, 2, 'Found 2 tables' );

my @views = $schema->get_views;
is( scalar @views, 1, 'Found 1 view' );
