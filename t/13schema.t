#!/usr/bin/perl

use strict;
use Test::More 'no_plan'; # plans => 1;

require_ok( 'SQL::Translator::Schema' );

#
# Schema
#
my $schema = SQL::Translator::Schema->new;

isa_ok( $schema, 'SQL::Translator::Schema' );

#
# Table default new
#
my $foo_table = $schema->add_table;
isa_ok( $foo_table, 'SQL::Translator::Schema::Table', 'Schema' );
is( $foo_table->name, '', 'Table name is empty' );
is( $foo_table->is_valid, 0, 'Table is not yet valid' );
my %fields = $foo_table->fields;
cmp_ok( scalar keys %fields, '==', 0, 'No fields' );

#
# Table methods
#
is( $foo_table->name('foo'), 'foo', 'Table name is "foo"' );

#
# New table with args
#
my $person_table = $schema->add_table( name => 'person' );
is( $person_table->name, 'person', 'Table name is "person"' );
is( $person_table->is_valid, 0, 'Table is still not valid' );

#
# Field default new
#
my $name = $person_table->add_field or warn $person_table->error;
isa_ok( $name, 'SQL::Translator::Schema::Field', 'Field' );
is( $name->name, '', 'Field name is blank' );
is( $name->data_type, '', 'Field data type is blank' );
is( $name->size, 0, 'Field size is "0"' );
is( $name->is_primary_key, '0', 'Field is_primary_key is negative' );

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
my $index = $person_table->add_index or warn $person_table->error;
isa_ok( $index, 'SQL::Translator::Schema::Index', 'Index' );

#
# Constraint
#
my $constraint = $person_table->add_constraint or warn $person_table->error;
isa_ok( $constraint, 'SQL::Translator::Schema::Constraint', 'Constraint' );

#
# View
#
my $view = $schema->add_view or warn $schema->error;
isa_ok( $view, 'SQL::Translator::Schema::View', 'View' );
