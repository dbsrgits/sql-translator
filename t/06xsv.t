#!/usr/bin/perl
# vim: set ft=perl:

#
# Tests for xSV parser
#
use strict;
use SQL::Translator;
use SQL::Translator::Schema;
use SQL::Translator::Schema::Constants;
use Test::More;
use Test::SQL::Translator qw(maybe_plan);

BEGIN {
    maybe_plan(25, 'SQL::Translator::Parser::xSV');
    SQL::Translator::Parser::xSV->import('parse');
}

my $tr = SQL::Translator->new;
my $s  = SQL::Translator::Schema->new;
my $data = q|One, Two, Three, Four, Five, Six, Seven
I, Am, Some, Data, Yo, -10, .04
And, So, am, I, "you crazy, crazy bastard", 500982, 1.1
|;

$tr->parser_args( trim_fields => 1, scan_fields => 1 );
my $val = parse($tr, $data, $s);

my $schema = $tr->schema;
my @tables = $schema->get_tables;
is( scalar @tables, 1, 'Correct number of tables (1)' );

my $table = shift @tables;
is( $table->name, 'table1', 'Table is named "table1"' );

my @fields = $table->get_fields;
is( scalar @fields, 7, 'Correct number of fields (7)' );

my $f1 = $fields[0];
is( $f1->name, 'One', 'First field name is "One"' );
is( $f1->data_type, 'char', 'Data type is "char"' );
is( $f1->size, '3', 'Size is "3"' );
is( $f1->is_primary_key, 1, 'Field is PK' );

my $f2 = $fields[1];
is( $f2->name, 'Two', 'First field name is "Two"' );
is( $f2->data_type, 'char', 'Data type is "char"' );
is( $f2->size, '2', 'Size is "2"' );
is( $f2->is_primary_key, 0, 'Field is not PK' );

my $f5 = $fields[4];
is( $f5->name, 'Five', 'Fifth field name is "Five"' );
is( $f5->data_type, 'char', 'Data type is "char"' );
is( $f5->size, '26', 'Size is "26"' );
is( $f5->is_primary_key, 0, 'Field is not PK' );

my $f6 = $fields[5];
is( $f6->name, 'Six', 'Sixth field name is "Six"' );
is( $f6->data_type, 'integer', 'Data type is "integer"' );
is( $f6->size, '6', 'Size is "6"' );

my $f7 = $fields[6];
is( $f7->name, 'Seven', 'Seventh field name is "Seven"' );
is( $f7->data_type, 'float', 'Data type is "float"' );
is( $f7->size, '3,2', 'Size is "3,2"' );

my @indices = $table->get_indices;
is( scalar @indices, 0, 'Correct number of indices (0)' );

my @constraints = $table->get_constraints;
is( scalar @constraints, 1, 'Correct number of constraints (1)' );
my $c = shift @constraints;
is( $c->type, PRIMARY_KEY, 'Constraint is a PK' );
is( join(',', $c->fields), 'One', 'On field "One"' );
