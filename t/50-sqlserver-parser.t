#!/usr/bin/perl
# vim: set ft=perl ts=4 et:
#

# Copied from 19sybase-parser.t with some additions

use strict;

use FindBin qw/$Bin/;
use Test::More;
use Test::SQL::Translator qw(maybe_plan);
use SQL::Translator;
use SQL::Translator::Schema::Constants;

BEGIN {
    maybe_plan(46, 'SQL::Translator::Parser::SQLServer');
    SQL::Translator::Parser::SQLServer->import('parse');
}

my $file = "$Bin/data/sqlserver/create.sql";

ok( -e $file, "File exists" );

my $data;
{
    local $/;
    open my $fh, "<$file" or die "Can't read file '$file': $!\n";
    $data = <$fh>;
    close $fh;
}

ok( $data, 'Data' );

my $t = SQL::Translator->new;

my $val = parse($t, $data);

is( $val, 1, 'Parse' );

my $schema = $t->schema;

isa_ok( $schema, 'SQL::Translator::Schema', 'Schema' );

is( $schema->is_valid, 1, 'Schema is valid' );

my @tables = $schema->get_tables;

is( scalar @tables, 8, 'Eight tables' );

{
    my $t = $schema->get_table( 'jdbc_function_escapes' );
    isa_ok( $t, 'SQL::Translator::Schema::Table', 'Table' );
    is( $t->name, 'jdbc_function_escapes', "Name = 'jdbc_function_escapes'" );

    my @fields = $t->get_fields;
    is( scalar @fields, 2, 'Two fields' );

    is( $fields[0]->name, 'escape_name', "First field name is 'escape_name'" );
    is( $fields[0]->data_type, 'varchar', "First field is 'varchar'" );
    is( $fields[0]->size, 40, "First field size is '40'" );
    is( $fields[0]->is_nullable, 0, "First field cannot be null" );

    is( $fields[1]->name, 'map_string', "Second field name is 'map_string'" );
    is( $fields[1]->data_type, 'varchar', "Second field is 'varchar'" );
    is( $fields[1]->size, 40, "Second field size is '40'" );
    is( $fields[1]->is_nullable, 0, "Second field cannot be null" );
}

{
    my $t = $schema->get_table( 'spt_jtext' );
    isa_ok( $t, 'SQL::Translator::Schema::Table', 'Table' );
    is( $t->name, 'spt_jtext', "Name = 'spt_jtext'" );

    my @fields = $t->get_fields;
    is( scalar @fields, 2, 'Two fields' );

    is( $fields[0]->name, 'mdinfo', "First field name is 'mdinfo'" );
    is( $fields[0]->data_type, 'varchar', "First field is 'varchar'" );
    is( $fields[0]->size, 30, "First field size is '30'" );
    is( $fields[0]->is_nullable, 0, "First field cannot be null" );

    is( $fields[1]->name, 'value', "Second field name is 'value'" );
    is( $fields[1]->data_type, 'text', "Second field is 'text'" );
    is( $fields[1]->size, 0, "Second field size is '0'" );
    is( $fields[1]->is_nullable, 0, "Second field cannot be null" );

    my @constraints = $t->get_constraints;
    is( scalar @constraints, 1, 'One constraint' );

    is( $constraints[0]->type, UNIQUE, 'Constraint is UNIQUE' );
    is( join(',', $constraints[0]->fields), 'mdinfo', 'On "mdinfo"' );
}

{
    my $t = $schema->get_table( 'spt_mda' );
    isa_ok( $t, 'SQL::Translator::Schema::Table', 'Table' );
    is( $t->name, 'spt_mda', "Name = 'spt_mda'" );

    my @fields = $t->get_fields;
    is( scalar @fields, 7, 'Seven fields' );

    is( $fields[0]->name, 'mdinfo', "First field name is 'mdinfo'" );
    is( $fields[0]->data_type, 'varchar', "First field is 'varchar'" );
    is( $fields[0]->size, 30, "First field size is '30'" );
    is( $fields[0]->is_nullable, 0, "First field cannot be null" );

    my @constraints = $t->get_constraints;
    is( scalar @constraints, 1, 'One constraint' );

    is( $constraints[0]->type, UNIQUE, 'Constraint is UNIQUE' );
    is( join(',', $constraints[0]->fields),
        'mdinfo,mdaver_end,srvver_end', 'On "mdinfo,mdaver_end,srvver_end"' );
}

# New testing for views and procedures
my @views = $schema->get_views;

is( scalar @views, 1, 'One view' );
like($views[0]->sql, qr/vs_xdp_data/, "Detected view vs_xdp_data");

my @procedures = $schema->get_procedures;

is( scalar @procedures, 10, 'Ten procedures' );
like($procedures[8]->sql, qr/Tx_B_Get_Vlan/, "Detected procedure Tx_B_Get_Vlan");
like($procedures[9]->sql, qr/\[dbo\].inet_ntoa/, "Detected function [dbo].inet_ntoa");

