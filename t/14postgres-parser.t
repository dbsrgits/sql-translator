#!/usr/bin/perl

use strict;
use Data::Dumper;
use Test::More 'no_plan'; # plans => 1;
use SQL::Translator;
use SQL::Translator::Parser::PostgreSQL qw(parse);

my $t   = SQL::Translator->new( trace => 0 );
my $sql = q[
    create table t_test1 (
        f_serial serial NOT NULL primary key,
        f_varchar character varying (255),
        f_double double precision,
        f_bigint bigint,
        f_char character(10),
        f_bool boolean,
        f_bin binary data(100),
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

    alter table only t_test1 add constraint "$1" foreign key (f_fk2)
    references t_test2 (f_id) on update no action on delete cascade;
];

$| = 1;

my $data = parse( $t, $sql );
#print Dumper($data),"\n";

is( ref $data, 'HASH', 'Data is a hashref' );
is( scalar keys %{ $data || {} }, 2, 'Two tables' );

ok( defined $data->{'t_test1'}, 'Table t_test1 exists' );
ok( defined $data->{'t_test2'}, 'Table t_test2 exists' );

my $t1 = $data->{'t_test1'};
my $t1_fields = $t1->{'fields'};
is( scalar keys %{ $t1_fields }, 11, '11 fields in t_test1' );
is( $t1_fields->{'f_serial'}{'data_type'}, 'integer', 'Field is an integer' );
is( $t1_fields->{'f_varchar'}{'data_type'}, 'varchar', 'Field is a varchar' );
is( $t1_fields->{'f_double'}{'data_type'}, 'float', 'Field is a float' );
is( $t1_fields->{'f_bigint'}{'data_type'}, 'integer', 'Field is an integer' );
is( $t1_fields->{'f_char'}{'data_type'}, 'char', 'Field is char' );
is( $t1_fields->{'f_bool'}{'data_type'}, 'boolean', 'Field is a boolean' );
is( $t1_fields->{'f_bin'}{'data_type'}, 'binary', 'Field is binary' );
is( $t1_fields->{'f_tz'}{'data_type'}, 'timestamp', 'Field is a timestamp' );
is( $t1_fields->{'f_text'}{'data_type'}, 'text', 'Field is text' );
is( $t1_fields->{'f_fk1'}{'data_type'}, 'integer', 'Field is an integer' );
is( $t1_fields->{'f_fk2'}{'data_type'}, 'integer', 'Field is an integer' );

is( $t1_fields->{'f_serial'}{'is_primary_key'}, 1, 
    'Field "f_serial" is primary key' );

my $t1_constraints = $t1->{'constraints'};
#print Dumper($t1_constraints),"\n";
is( scalar @{ $t1_constraints || [] }, 6, '6 constraints on t_test1' );
is( $t1_constraints->[-2]{'type'}, 'unique', 'Constraint is unique' );
is( $t1_constraints->[-2]{'fields'}[0], 'f_varchar', 
    'Constraint is on field "f_varchar"' );

is( $t1_constraints->[-1]{'type'}, 'foreign_key', 'Constraint is foreign key' );
is( $t1_constraints->[-1]{'fields'}[0], 'f_fk2', 
    'Constraint is on field "f_fk2"' );
is( $t1_constraints->[-1]{'reference_table'}, 't_test2', 
    'Constraint is to table "t_test2"' );
is( $t1_constraints->[-1]{'reference_fields'}[0], 'f_id', 
    'Constraint is to field "f_id"' );
is( $t1_constraints->[-1]{'on_update_do'}, 'no_action', 
    'No action on update' );
is( $t1_constraints->[-1]{'on_delete_do'}, 'cascade', 
    'Cascade on delete' );

my $t2 = $data->{'t_test2'};
my $t2_fields = $t2->{'fields'};
is( scalar keys %{ $t2_fields }, 2, '2 fields in t_test2' );
is( $t2_fields->{'f_id'}{'data_type'}, 'integer', 'Field is an integer' );
is( $t2_fields->{'f_varchar'}{'data_type'}, 'varchar', 'Field is an varchar' );
