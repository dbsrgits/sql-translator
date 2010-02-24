#!/usr/bin/perl
# vim: set ft=perl:

use strict;
use Test::More;
use Test::SQL::Translator qw(maybe_plan);
use FindBin qw/$Bin/;

use SQL::Translator;
use SQL::Translator::Schema::Constants;

BEGIN {
    maybe_plan(19,
        'SQL::Translator::Parser::SQLite');
}
SQL::Translator::Parser::SQLite->import('parse');

my $file = "$Bin/data/sqlite/create.sql";

{
    local $/;
    open my $fh, "<$file" or die "Can't read file '$file': $!\n";
    my $data = <$fh>;
    my $t = SQL::Translator->new;
    parse($t, $data);

    my $schema = $t->schema;

    my @tables = $schema->get_tables;
    is( scalar @tables, 2, 'Parsed two tables' );

    my $t1 = shift @tables;
    is( $t1->name, 'person', "'Person' table" );

    my @fields = $t1->get_fields;
    is( scalar @fields, 6, 'Six fields in "person" table');
    my $fld1 = shift @fields;
    is( $fld1->name, 'person_id', 'First field is "person_id"');
    is( $fld1->is_auto_increment, 1, 'Is an autoincrement field');

    my $t2 = shift @tables;
    is( $t2->name, 'pet', "'Pet' table" );

    my @constraints = $t2->get_constraints;
    is( scalar @constraints, 3, '3 constraints on pet' );

    my $c1 = pop @constraints;
    is( $c1->type, 'FOREIGN KEY', 'FK constraint' );
    is( $c1->reference_table, 'person', 'References person table' );
    is( join(',', $c1->reference_fields), 'person_id', 
        'References person_id field' );

    my @views = $schema->get_views;
    is( scalar @views, 1, 'Parsed one views' );

    my @triggers = $schema->get_triggers;
    is( scalar @triggers, 1, 'Parsed one triggers' );
}

$file = "$Bin/data/sqlite/named.sql";
{
    local $/;
    open my $fh, "<$file" or die "Can't read file '$file': $!\n";
    my $data = <$fh>;
    my $t = SQL::Translator->new;
    parse($t, $data);

    my $schema = $t->schema;

    my @tables = $schema->get_tables;
    is( scalar @tables, 1, 'Parsed one table' );

    my $t1 = shift @tables;
    is( $t1->name, 'pet', "'Pet' table" );

    my @constraints = $t1->get_constraints;
    is( scalar @constraints, 3, '3 constraints on pet' );

    my $c1 = pop @constraints;
    is( $c1->type, 'FOREIGN KEY', 'FK constraint' );
    is( $c1->reference_table, 'person', 'References person table' );
    is( $c1->name, 'fk_person_id', 'Constraint name fk_person_id' );
    is( join(',', $c1->reference_fields), 'person_id', 
        'References person_id field' );

}
