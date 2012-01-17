#!/usr/bin/perl
# vim: set ft=perl:

use Test::More;
use SQL::Translator;
use SQL::Translator::Schema::Constants;
use Test::SQL::Translator qw(maybe_plan);

BEGIN {
    maybe_plan(31, 'SQL::Translator::Parser::Excel');
    SQL::Translator::Parser::Excel->import('parse');
}

my $tr     = SQL::Translator->new(parser => "Excel");
my $t      = $tr->translate(filename => "t/data/Excel/t.xls");
my $schema = $tr->schema;

my @tables = $schema->get_tables;
is( scalar @tables, 1, 'Parsed 1 table' );

my $table = shift @tables;
is( $table->name, 'Sheet1', 'Table name is "Sheet1"' );

my @fields = $table->get_fields;
is( scalar @fields, 7, 'Table has 7 fields' );

my $f1 = shift @fields;
is( $f1->name, 'ID', 'First field name is "ID"' );
is( lc $f1->data_type, 'integer', 'Data type is "integer"' );
is( $f1->size, 5, 'Size is "5"' );
is( $f1->is_primary_key, 1, 'Field is PK' );

my $f2 = shift @fields;
is( $f2->name, 'text', 'Second field name is "text"' );
is( lc $f2->data_type, 'char', 'Data type is "char"' );
is( $f2->size, 7, 'Size is "7"' );
is( $f2->is_primary_key, 0, 'Field is not PK' );

my $f3 = shift @fields;
is( $f3->name, 'number', 'Third field name is "number"' );
is( lc $f3->data_type, 'integer', 'Data type is "integer"' );
is( $f3->size, 1, 'Size is "1"' );
is( $f3->is_primary_key, 0, 'Field is not PK' );

my $f4 = shift @fields;
TODO: {
    eval { require Spreadsheet::ParseExcel };
       todo_skip "Bug in Spreadsheet::ParseExcel, http://rt.cpan.org/Public/Bug/Display.html?id=39892", 4
               if ( $Spreadsheet::ParseExcel::VERSION > 0.32 and $Spreadsheet::ParseExcel::VERSION < 0.41 );

       is( $f4->name, 'math', 'Fourth field name is "math"' );
       is( lc $f4->data_type, 'float', 'Data type is "float"' );
       is( $f4->size, '3,1', 'Size is "3,1"' );
       is( $f4->is_primary_key, 0, 'Field is not PK' );
}

my $f5 = shift @fields;
is( $f5->name, 'bitmap', 'Fifth field name is "bitmap"' );
is( lc $f5->data_type, 'char', 'Data type is "char"' );
is( $f5->size, 1, 'Size is "1"' );
is( $f5->is_primary_key, 0, 'Field is not PK' );

my $f6 = shift @fields;
is( $f6->name, 'today', 'Sixth field name is "today"' );
is( lc $f6->data_type, 'char', 'Data type is "CHAR"' );
is( $f6->size, 10, 'Size is "10"' );
is( $f6->is_primary_key, 0, 'Field is not PK' );

my $f7 = shift @fields;
is( $f7->name, 'silly_field_with_random_characters',
    'Seventh field name is "silly_field_with_random_characters"' );
is( lc $f7->data_type, 'char', 'Data type is "CHAR"' );
is( $f7->size, 11, 'Size is "11"' );
is( $f7->is_primary_key, 0, 'Field is not PK' );
