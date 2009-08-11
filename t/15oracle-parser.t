#!/usr/bin/perl
# vim: set ft=perl:

use strict;
use Test::More;
use SQL::Translator;
use SQL::Translator::Schema::Constants;
use Test::SQL::Translator qw(maybe_plan);

maybe_plan(99, 'SQL::Translator::Parser::Oracle');
SQL::Translator::Parser::Oracle->import('parse');

my $t   = SQL::Translator->new( trace => 0 );
my $sql = q[
    CREATE TABLE qtl_trait_category
    (
        qtl_trait_category_id       NUMBER(11)      NOT NULL    
            CONSTRAINT pk_qtl_trait_category PRIMARY KEY,
        trait_category              VARCHAR2(100)   NOT NULL,
        CONSTRAINT AVCON_4287_PARAM_000 CHECK 
            (trait_category IN ('S', 'A', 'E')) ENABLE,
        UNIQUE ( trait_category )
    );
    COMMENT ON TABLE qtl_trait_category IS 
    'hey, hey, hey, hey';
    comment on column qtl_trait_category.qtl_trait_category_id 
        is 'the primary key!';

    -- foo bar comment
    CREATE TABLE qtl_trait
    (
        qtl_trait_id            NUMBER(11)      NOT NULL    
            CONSTRAINT pk_qtl_trait PRIMARY KEY,
        trait_symbol            VARCHAR2(100 BYTE)   NOT NULL,
        trait_name              VARCHAR2(200 CHAR)   NOT NULL,
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
        FOREIGN KEY ( qtl_trait_id ) REFERENCES qtl_trait
    );

    CREATE UNIQUE INDEX qtl_accession ON qtl ( qtl_accession_id );
    CREATE UNIQUE INDEX qtl_accession_upper ON qtl ( UPPER(qtl_accession_id) );
    CREATE INDEX qtl_index ON qtl ( qtl_accession_id );

    CREATE TABLE qtl_trait_synonym
    (
        qtl_trait_synonym_id    NUMBER(11)      NOT NULL    
            CONSTRAINT pk_qtl_trait_synonym PRIMARY KEY,
        trait_synonym           VARCHAR2(200)   NOT NULL,
        qtl_trait_id            NUMBER(11)      NOT NULL,
        UNIQUE( qtl_trait_id, trait_synonym ),
        FOREIGN KEY ( qtl_trait_id ) REFERENCES qtl_trait ON DELETE SET NULL
    );

-- View and procedure testing
	CREATE OR REPLACE PROCEDURE CMDOMAIN_LATEST.P_24_HOUR_EVENT_SUMMARY
	IS
	            ldate                   varchar2(10);
	            user_added              INT;
	            user_deleted            INT;
	            workingsets_created     INT;
	            change_executed         INT;
	            change_detected         INT;
	            reports_run             INT;
	            backup_complete         INT;
	            backup_failed           INT;
	            devices_in_inventory    INT;
	
	
	BEGIN
	
	           select CAST(TO_CHAR(sysdate,'MM/DD/YYYY') AS varchar2(10))  INTO ldate  from  dual;
	END;
/
	
	CREATE OR REPLACE FORCE VIEW CMDOMAIN_MIG.VS_ASSET (ASSET_ID, FQ_NAME, FOLDER_NAME, ASSET_NAME, ANNOTATION, ASSET_TYPE, FOREIGN_ASSET_ID, FOREIGN_ASSET_ID2, DATE_CREATED, DATE_MODIFIED, CONTAINER_ID, CREATOR_ID, MODIFIER_ID, USER_ACCESS) AS
	  SELECT
	    a.asset_id, a.fq_name,
	    ap_extract_folder(a.fq_name) AS folder_name,
	    ap_extract_asset(a.fq_name)  AS asset_name,
	    a.annotation,
	    a.asset_type,
	    a.foreign_asset_id,
	    a.foreign_asset_id2,
	    a.dateCreated AS date_created,
	    a.dateModified AS date_modified,
	    a.container_id,
	    a.creator_id,
	    a.modifier_id,
	    m.user_id AS user_access
	from asset a
	JOIN M_ACCESS_CONTROL m on a.acl_id = m.acl_id;

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
#use Data::Dumper;
#print STDERR Dumper(\@t1_constraints), "\n";
is( scalar @t1_constraints, 3, '3 constraints on table' );

my $c1 = $t1_constraints[0];
is( $c1->name, 'pk_qtl_trait_category', 
    'Constraint name is "pk_qtl_trait_category"' );
is( $c1->type, PRIMARY_KEY, 'First constraint is PK' );
is( join(',', $c1->fields), 'qtl_trait_category_id', 
    'Constraint is on field "qtl_trait_category_id"' );

my $c2 = $t1_constraints[1];
is( $c2->type, CHECK_C, 'Second constraint is a check' );
is( $c2->expression, 
    "( trait_category IN ('S', 'A', 'E') ) ENABLE",
    'Constraint is on field "trait_category"' );

my $c3 = $t1_constraints[2];
is( $c3->type, UNIQUE, 'Third constraint is unique' );
is( join(',', $c3->fields), 'trait_category', 
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
is( scalar @t3_constraints, 4, '4 constraints on table' );
my $t3_c4 = $t3_constraints[3];
is( $t3_c4->type, UNIQUE, 'Fourth constraint is unique' );
is( $t3_c4->name, 'qtl_accession_upper', 'Name = "qtl_accession_upper"' );
is( join(',', $t3_c4->fields), 'UPPER(qtl_accession_id)', 'Fields = "UPPER(qtl_accession_id)"' );

is( $t3->comments, 'qtl table comment', 'Comment "qtl table comment" exists' );

my $t3_f1     = shift @t3_fields;
is( $t3_f1->comments, 'qtl_id comment', 'Comment "qtl_id comment" exists' );

my $t3_f2     = shift @t3_fields;
is( $t3_f2->comments, 'accession comment', 
    'Comment "accession comment" exists' );

my @t3_indices = $t3->get_indices;
is( scalar @t3_indices, 1, '1 index on table' );

my $t3_i1 = shift @t3_indices;
is( $t3_i1->type, 'NORMAL', 'First index is normal' );
is( $t3_i1->name, 'qtl_index', 'Name is "qtl_index"' );
is( join(',', $t3_i1->fields), 'qtl_accession_id', 'Fields = "qtl_accession_id"' );

#
# qtl_trait_synonym
#
my $t4 = shift @tables;
is( $t4->name, 'qtl_trait_synonym', 'Table "qtl_trait_synonym" exists' );

my @t4_fields = $t4->get_fields;
is( scalar @t4_fields, 3, '3 fields in table' );

my @t4_constraints = $t4->get_constraints;
is( scalar @t4_constraints, 3, '3 constraints on table' );
my $t4_c3 = $t4_constraints[2];
is( $t4_c3->type, FOREIGN_KEY, 'Third constraint is FK' );
is( $t4_c3->name, '', 'No name' );
is( join(',', $t4_c3->fields), 'qtl_trait_id', 
    'Fields = "qtl_trait_id"' );
is( $t4_c3->reference_table, 'qtl_trait', 
    'Reference table = "qtl_trait"' );
is( join(',', $t4_c3->reference_fields), 'qtl_trait_id', 
    'Reference fields = "qtl_trait_id"' );
is( $t4_c3->on_delete, 'SET NULL', 
    'on_delete = "SET NULL"' );

my @views = $schema->get_views;
is( scalar @views, 1, 'Right number of views (1)' );
my $view1 = shift @views;
is( $view1->name, 'VS_ASSET', 'Found "VS_ASSET" view' );
like($view1->sql, qr/VS_ASSET/, "Detected view VS_ASSET");
unlike($view1->sql, qr/CMDOMAIN_MIG/, "Did not detect CMDOMAIN_MIG");
    
my @procs = $schema->get_procedures;
is( scalar @procs, 1, 'Right number of procedures (1)' );
my $proc1 = shift @procs;
is( $proc1->name, 'P_24_HOUR_EVENT_SUMMARY', 'Found "P_24_HOUR_EVENT_SUMMARY" procedure' );
like($proc1->sql, qr/P_24_HOUR_EVENT_SUMMARY/, "Detected procedure P_24_HOUR_EVENT_SUMMARY");
unlike($proc1->sql, qr/CMDOMAIN_MIG/, "Did not detect CMDOMAIN_MIG");
