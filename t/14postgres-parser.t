#!/usr/bin/perl

use strict;
use Test::More tests => 105;
use SQL::Translator;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Parser::PostgreSQL qw(parse);

my $t   = SQL::Translator->new( trace => 0 );
my $sql = q[
    create table t_test1 (
        f_serial serial NOT NULL default '0' primary key,
        f_varchar character varying (255),
        f_double double precision,
        f_bigint bigint not null,
        f_char character(10),
        f_bool boolean,
        f_bin bytea,
        f_tz timestamp,
        f_text text,
        f_fk1 integer not null references t_test2 (f_id),
        f_fk2 integer
    );

    create table t_test2 (
        f_id integer NOT NULL,
        f_varchar varchar(25),
        primary key (f_id)
    );

    alter table only t_test1 add constraint c_u1 unique (f_varchar);

    alter table only t_test1 add constraint "c_fk2" foreign key (f_fk2)
    references t_test2 (f_id) on update no action on delete cascade;
];

$| = 1;

my $data   = parse( $t, $sql );
my $schema = $t->schema;

isa_ok( $schema, 'SQL::Translator::Schema', 'Schema object' );
my @tables = $schema->get_tables;
is( scalar @tables, 2, 'Two tables' );

my $t1 = shift @tables;
is( $t1->name, 't_test1', 'Table t_test1 exists' );

my @t1_fields = $t1->get_fields;
is( scalar @t1_fields, 11, '11 fields in t_test1' );

my $f1 = shift @t1_fields;
is( $f1->name, 'f_serial', 'First field is "f_serial"' );
is( $f1->data_type, 'integer', 'Field is an integer' );
is( $f1->is_nullable, 0, 'Field cannot be null' );
is( $f1->size, 4, 'Size is "4"' );
is( $f1->default_value, '0', 'Default value is "0"' );
is( $f1->is_primary_key, 1, 'Field is PK' );

my $f2 = shift @t1_fields;
is( $f2->name, 'f_varchar', 'Second field is "f_varchar"' );
is( $f2->data_type, 'varchar', 'Field is a varchar' );
is( $f2->is_nullable, 1, 'Field can be null' );
is( $f2->size, 255, 'Size is "255"' );
is( $f2->default_value, undef, 'Default value is undefined' );
is( $f2->is_primary_key, 0, 'Field is not PK' );

my $f3 = shift @t1_fields;
is( $f3->name, 'f_double', 'Third field is "f_double"' );
is( $f3->data_type, 'float', 'Field is a float' );
is( $f3->is_nullable, 1, 'Field can be null' );
is( $f3->size, 8, 'Size is "8"' );
is( $f3->default_value, undef, 'Default value is undefined' );
is( $f3->is_primary_key, 0, 'Field is not PK' );

my $f4 = shift @t1_fields;
is( $f4->name, 'f_bigint', 'Fourth field is "f_bigint"' );
is( $f4->data_type, 'integer', 'Field is an integer' );
is( $f4->is_nullable, 0, 'Field cannot be null' );
is( $f4->size, 8, 'Size is "8"' );
is( $f4->default_value, undef, 'Default value is undefined' );
is( $f4->is_primary_key, 0, 'Field is not PK' );

my $f5 = shift @t1_fields;
is( $f5->name, 'f_char', 'Fifth field is "f_char"' );
is( $f5->data_type, 'char', 'Field is char' );
is( $f5->is_nullable, 1, 'Field can be null' );
is( $f5->size, 10, 'Size is "10"' );
is( $f5->default_value, undef, 'Default value is undefined' );
is( $f5->is_primary_key, 0, 'Field is not PK' );

my $f6 = shift @t1_fields;
is( $f6->name, 'f_bool', 'Sixth field is "f_bool"' );
is( $f6->data_type, 'boolean', 'Field is a boolean' );
is( $f6->is_nullable, 1, 'Field can be null' );
is( $f6->size, 0, 'Size is "0"' );
is( $f6->default_value, undef, 'Default value is undefined' );
is( $f6->is_primary_key, 0, 'Field is not PK' );

my $f7 = shift @t1_fields;
is( $f7->name, 'f_bin', 'Seventh field is "f_bin"' );
is( $f7->data_type, 'bytea', 'Field is bytea' );
is( $f7->is_nullable, 1, 'Field can be null' );
is( $f7->size, 0, 'Size is "0"' );
is( $f7->default_value, undef, 'Default value is undefined' );
is( $f7->is_primary_key, 0, 'Field is not PK' );

my $f8 = shift @t1_fields;
is( $f8->name, 'f_tz', 'Eighth field is "f_tz"' );
is( $f8->data_type, 'timestamp', 'Field is a timestamp' );
is( $f8->is_nullable, 1, 'Field can be null' );
is( $f8->size, 0, 'Size is "0"' );
is( $f8->default_value, undef, 'Default value is undefined' );
is( $f8->is_primary_key, 0, 'Field is not PK' );

my $f9 = shift @t1_fields;
is( $f9->name, 'f_text', 'Ninth field is "f_text"' );
is( $f9->data_type, 'text', 'Field is text' );
is( $f9->is_nullable, 1, 'Field can be null' );
is( $f9->size, 0, 'Size is "0"' );
is( $f9->default_value, undef, 'Default value is undefined' );
is( $f9->is_primary_key, 0, 'Field is not PK' );

my $f10 = shift @t1_fields;
is( $f10->name, 'f_fk1', 'Tenth field is "f_fk1"' );
is( $f10->data_type, 'integer', 'Field is an integer' );
is( $f10->is_nullable, 0, 'Field cannot be null' );
is( $f10->size, 4, 'Size is "4"' );
is( $f10->default_value, undef, 'Default value is undefined' );
is( $f10->is_primary_key, 0, 'Field is not PK' );
is( $f10->is_foreign_key, 1, 'Field is a FK' );
my $fk_ref1 = $f10->foreign_key_reference;
isa_ok( $fk_ref1, 'SQL::Translator::Schema::Constraint', 'FK' );
is( $fk_ref1->reference_table, 't_test2', 'FK is to "t_test2" table' );

my $f11 = shift @t1_fields;
is( $f11->name, 'f_fk2', 'Eleventh field is "f_fk2"' );
is( $f11->data_type, 'integer', 'Field is an integer' );
is( $f11->is_nullable, 1, 'Field can be null' );
is( $f11->size, 4, 'Size is "4"' );
is( $f11->default_value, undef, 'Default value is undefined' );
is( $f11->is_primary_key, 0, 'Field is not PK' );
is( $f11->is_foreign_key, 1, 'Field is a FK' );
my $fk_ref2 = $f11->foreign_key_reference;
isa_ok( $fk_ref2, 'SQL::Translator::Schema::Constraint', 'FK' );
is( $fk_ref2->reference_table, 't_test2', 'FK is to "t_test2" table' );

my @t1_constraints = $t1->get_constraints;
is( scalar @t1_constraints, 4, '4 constraints on t_test1' );

my $c1 = $t1_constraints[0];
is( $c1->type, PRIMARY_KEY, 'First constraint is PK' );
is( join(',', $c1->fields), 'f_serial', 'Constraint is on field "f_serial"' );

my $c2 = $t1_constraints[1];
is( $c2->type, FOREIGN_KEY, 'Second constraint is foreign key' );
is( join(',', $c2->fields), 'f_fk1', 'Constraint is on field "f_fk1"' );
is( $c2->reference_table, 't_test2', 'Constraint is to table "t_test2"' );
is( join(',', $c2->reference_fields), 'f_id', 'Constraint is to field "f_id"' );

my $c3 = $t1_constraints[2];
is( $c3->type, UNIQUE, 'Third constraint is unique' );
is( join(',', $c3->fields), 'f_varchar', 'Constraint is on field "f_varchar"' );

my $c4 = $t1_constraints[3];
is( $c4->type, FOREIGN_KEY, 'Fourth constraint is foreign key' );
is( join(',', $c4->fields), 'f_fk2', 'Constraint is on field "f_fk2"' );
is( $c4->reference_table, 't_test2', 'Constraint is to table "t_test2"' );
is( join(',', $c4->reference_fields), 'f_id', 'Constraint is to field "f_id"' );
is( $c4->on_delete, 'cascade', 'On delete: cascade' );
is( $c4->on_update, 'no_action', 'On delete: no action' );

my $t2 = shift @tables;
is( $t2->name, 't_test2', 'Table t_test2 exists' );

my @t2_fields = $t2->get_fields;
is( scalar @t2_fields, 2, '2 fields in t_test2' );

my $t2_f1 = shift @t2_fields;
is( $t2_f1->name, 'f_id', 'First field is "f_id"' );
is( $t2_f1->data_type, 'integer', 'Field is an integer' );
is( $t2_f1->is_nullable, 0, 'Field cannot be null' );
is( $t2_f1->size, 4, 'Size is "4"' );
is( $t2_f1->default_value, undef, 'Default value is undefined' );
is( $t2_f1->is_primary_key, 1, 'Field is PK' );

my $t2_f2 = shift @t2_fields;
is( $t2_f2->name, 'f_varchar', 'First field is "f_varchar"' );
is( $t2_f2->data_type, 'varchar', 'Field is an varchar' );
is( $t2_f2->is_nullable, 1, 'Field can be null' );
is( $t2_f2->size, 25, 'Size is "25"' );
is( $t2_f2->default_value, undef, 'Default value is undefined' );
is( $t2_f2->is_primary_key, 0, 'Field is not PK' );
