#!/usr/bin/perl

use strict;
use Test::More tests => 76;
use SQL::Translator;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Parser::Oracle qw(parse);

my $t   = SQL::Translator->new( trace => 0 );
my $sql = q[
    CREATE TABLE qtl_trait_category
    (
        qtl_trait_category_id       NUMBER(11)      NOT NULL    
            CONSTRAINT pk_qtl_trait_category PRIMARY KEY,
        trait_category              VARCHAR2(100)   NOT NULL,
        UNIQUE ( trait_category )
    );
    comment on table qtl_trait_category is 'hey, hey, hey, hey';
    comment on column qtl_trait_category.qtl_trait_category_id 
        is 'the primary key!';

    -- foo bar comment
    CREATE TABLE qtl_trait
    (
        qtl_trait_id            NUMBER(11)      NOT NULL    
            CONSTRAINT pk_qtl_trait PRIMARY KEY,
        trait_symbol            VARCHAR2(100)   NOT NULL,
        trait_name              VARCHAR2(200)   NOT NULL,
        qtl_trait_category_id   NUMBER(11)      NOT NULL,
        UNIQUE ( trait_symbol ),
        UNIQUE ( trait_name ),
        FOREIGN KEY ( qtl_trait_category_id ) REFERENCES qtl_trait_category
    );

    /* qtl table comment */
    CREATE TABLE qtl
    (
        /* qtl_id comment */
        qtl_id              NUMBER(11)      NOT NULL    
            CONSTRAINT pk_qtl PRIMARY KEY,
        qtl_accession_id    VARCHAR2(20)    NOT NULL /* accession comment */,
        published_symbol    VARCHAR2(100),
        qtl_trait_id        NUMBER(11)      NOT NULL,
        linkage_group       VARCHAR2(32)    NOT NULL,
        start_position      NUMBER(11,2)    NOT NULL,
        stop_position       NUMBER(11,2)    NOT NULL,
        comments            long,
        UNIQUE ( qtl_accession_id ),
        FOREIGN KEY ( qtl_trait_id ) REFERENCES qtl_trait
    );

    CREATE TABLE qtl_trait_synonym
    (
        qtl_trait_synonym_id    NUMBER(11)      NOT NULL    
            CONSTRAINT pk_qtl_trait_synonym PRIMARY KEY,
        trait_synonym           VARCHAR2(200)   NOT NULL,
        qtl_trait_id            NUMBER(11)      NOT NULL,
        UNIQUE( qtl_trait_id, trait_synonym ),
        FOREIGN KEY ( qtl_trait_id ) REFERENCES qtl_trait
    );
];

$| = 1;

my $data   = parse( $t, $sql );
my $schema = $t->schema;

isa_ok( $schema, 'SQL::Translator::Schema', 'Schema object' );
my @tables = $schema->get_tables;
is( scalar @tables, 4, 'Found four tables' );

#
# qtl_trait_category
#
my $t1 = shift @tables;
is( $t1->name, 'qtl_trait_category', 'First table is "qtl_trait_category"' );
is( $t1->comments, 'hey, hey, hey, hey', 'Comment = "hey, hey, hey, hey"' );

my @t1_fields = $t1->get_fields;
is( scalar @t1_fields, 2, '2 fields in table' );

my $f1 = shift @t1_fields;
is( $f1->name, 'qtl_trait_category_id', 
    'First field is "qtl_trait_category_id"' );
is( $f1->data_type, 'number', 'Field is a number' );
is( $f1->size, 11, 'Size is "11"' );
is( $f1->is_nullable, 0, 'Field cannot be null' );
is( $f1->default_value, undef, 'Default value is undefined' );
is( $f1->is_primary_key, 1, 'Field is PK' );
is( join(',', $f1->comments), 'the primary key!', 'Comment = "the primary key!"' );

my $f2 = shift @t1_fields;
is( $f2->name, 'trait_category', 'Second field is "trait_category"' );
is( $f2->data_type, 'varchar2', 'Field is a varchar2' );
is( $f2->size, 100, 'Size is "100"' );
is( $f2->is_nullable, 0, 'Field cannot be null' );
is( $f2->default_value, undef, 'Default value is undefined' );
is( $f2->is_primary_key, 0, 'Field is not PK' );

my @t1_indices = $t1->get_indices;
is( scalar @t1_indices, 0, '0 indices on table' );

my @t1_constraints = $t1->get_constraints;
is( scalar @t1_constraints, 2, '2 constraints on table' );

my $c1 = $t1_constraints[0];
is( $c1->name, 'pk_qtl_trait_category', 
    'Constraint name is "pk_qtl_trait_category"' );
is( $c1->type, PRIMARY_KEY, 'First constraint is PK' );
is( join(',', $c1->fields), 'qtl_trait_category_id', 
    'Constraint is on field "qtl_trait_category_id"' );

my $c2 = $t1_constraints[1];
is( $c2->type, UNIQUE, 'Second constraint is unique' );
is( join(',', $c2->fields), 'trait_category', 
    'Constraint is on field "trait_category"' );

#
# qtl_trait
#
my $t2 = shift @tables;
is( $t2->name, 'qtl_trait', 'Table "qtl_trait" exists' );
is( $t2->comments, 'foo bar comment', 'Comment "foo bar" exists' );

my @t2_fields = $t2->get_fields;
is( scalar @t2_fields, 4, '4 fields in table' );

my $t2_f1 = shift @t2_fields;
is( $t2_f1->name, 'qtl_trait_id', 'First field is "qtl_trait_id"' );
is( $t2_f1->data_type, 'number', 'Field is a number' );
is( $t2_f1->size, 11, 'Size is "11"' );
is( $t2_f1->is_nullable, 0, 'Field cannot be null' );
is( $t2_f1->default_value, undef, 'Default value is undefined' );
is( $t2_f1->is_primary_key, 1, 'Field is PK' );

my $t2_f2 = shift @t2_fields;
is( $t2_f2->name, 'trait_symbol', 'Second field is "trait_symbol"' );
is( $t2_f2->data_type, 'varchar2', 'Field is a varchar2' );
is( $t2_f2->size, 100, 'Size is "100"' );
is( $t2_f2->is_nullable, 0, 'Field cannot be null' );
is( $t2_f2->is_foreign_key, 0, 'Field is not a FK' );

my $t2_f3 = shift @t2_fields;
is( $t2_f3->name, 'trait_name', 'Third field is "trait_name"' );
is( $t2_f3->data_type, 'varchar2', 'Field is a varchar2' );
is( $t2_f3->size, 200, 'Size is "200"' );
is( $t2_f3->is_nullable, 0, 'Field cannot be null' );
is( $t2_f3->is_foreign_key, 0, 'Field is not a FK' );

my $t2_f4 = shift @t2_fields;
is( $t2_f4->name, 'qtl_trait_category_id', 
    'Fourth field is "qtl_trait_category_id"' );
is( $t2_f4->data_type, 'number', 'Field is a number' );
is( $t2_f4->size, 11, 'Size is "11"' );
is( $t2_f4->is_nullable, 0, 'Field cannot be null' );
is( $t2_f4->is_foreign_key, 1, 'Field is a FK' );
my $f4_fk = $t2_f4->foreign_key_reference;
isa_ok( $f4_fk, 'SQL::Translator::Schema::Constraint', 'FK' );
is( $f4_fk->reference_table, 'qtl_trait_category', 
    'FK references table "qtl_trait_category"' );
is( join(',', $f4_fk->reference_fields), 'qtl_trait_category_id', 
    'FK references field "qtl_trait_category_id"' );

my @t2_constraints = $t2->get_constraints;
is( scalar @t2_constraints, 4, '4 constraints on table' );

my $t2_c1 = shift @t2_constraints;
is( $t2_c1->type, PRIMARY_KEY, 'First constraint is PK' );
is( $t2_c1->name, 'pk_qtl_trait', 'Name is "pk_qtl_trait"' );
is( join(',', $t2_c1->fields), 'qtl_trait_id', 'Fields = "qtl_trait_id"' );

my $t2_c2 = shift @t2_constraints;
is( $t2_c2->type, UNIQUE, 'Second constraint is unique' );
is( $t2_c2->name, '', 'No name' );
is( join(',', $t2_c2->fields), 'trait_symbol', 'Fields = "trait_symbol"' );

my $t2_c3 = shift @t2_constraints;
is( $t2_c3->type, UNIQUE, 'Third constraint is unique' );
is( $t2_c3->name, '', 'No name' );
is( join(',', $t2_c3->fields), 'trait_name', 'Fields = "trait_name"' );

my $t2_c4 = shift @t2_constraints;
is( $t2_c4->type, FOREIGN_KEY, 'Fourth constraint is FK' );
is( $t2_c4->name, '', 'No name' );
is( join(',', $t2_c4->fields), 'qtl_trait_category_id', 
    'Fields = "qtl_trait_category_id"' );
is( $t2_c4->reference_table, 'qtl_trait_category', 
    'Reference table = "qtl_trait_category"' );
is( join(',', $t2_c4->reference_fields), 'qtl_trait_category_id', 
    'Reference fields = "qtl_trait_category_id"' );


#
# qtl
#
my $t3 = shift @tables;
is( $t3->name, 'qtl', 'Table "qtl" exists' );

my @t3_fields = $t3->get_fields;
is( scalar @t3_fields, 8, '8 fields in table' );

my @t3_constraints = $t3->get_constraints;
is( scalar @t3_constraints, 3, '3 constraints on table' );

is( $t3->comments, 'qtl table comment', 'Comment "qtl table comment" exists' );

my $t3_f1     = shift @t3_fields;
is( $t3_f1->comments, 'qtl_id comment', 'Comment "qtl_id comment" exists' );

my $t3_f2     = shift @t3_fields;
is( $t3_f2->comments, 'accession comment', 
    'Comment "accession comment" exists' );

#
# qtl_trait_synonym
#
my $t4 = shift @tables;
is( $t4->name, 'qtl_trait_synonym', 'Table "qtl_trait_synonym" exists' );

my @t4_fields = $t4->get_fields;
is( scalar @t4_fields, 3, '3 fields in table' );

my @t4_constraints = $t4->get_constraints;
is( scalar @t4_constraints, 3, '3 constraints on table' );
