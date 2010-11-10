#!/usr/bin/perl -w
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
#
# Run script with -d for debug.

use strict;
use FindBin qw/$Bin/;

use Test::More;
use Test::SQL::Translator;
#use Test::Exception;
use Data::Dumper;
use SQL::Translator;
use SQL::Translator::Schema;
use SQL::Translator::Schema::Constants;

# Simple options. -d for debug
my %opt;
BEGIN { map { $opt{$_}=1 if s/^-// } @ARGV; }
use constant DEBUG => (exists $opt{d} ? 1 : 0);

# Setup a (somewaht contrived!) test schema
#=============================================================================

my $schema = SQL::Translator::Schema->new( name => "Lookup-tests" );

my $tbl_order = $schema->add_table( name => "Order" );

# Fields
$tbl_order->add_field(
    name => "order_id",
    data_type => "INT",
    size => "10",
    is_primary_key => 1,
);
$tbl_order->add_field(
    name => "customer_id",
    data_type => "INT",
    size => "10",
);
$tbl_order->add_field(
    name => "invoice_number",
    data_type => "VARCHAR",
    size => "20",
);
$tbl_order->add_field(
    name => "notes",
    data_type => "TEXT",
);

# Constraints
$tbl_order->add_constraint(
    name   => "con_pkey",
    type   => PRIMARY_KEY,
    fields => "order_id",
);
$tbl_order->add_constraint(
    name   => "con_customer_fkey",
    type   => FOREIGN_KEY,
    fields => "customer_id",
    reference_table  => "Customer",
    reference_fields => "customer_id",
);
$tbl_order->add_constraint(
    name   => "con_unique_invoice",
    type   => UNIQUE,
    fields => "invoice_number",
);

print STDERR "Test Schema:",Dumper($schema) if DEBUG;
die "Test is schema is invalid! : ".$schema->err unless $schema->is_valid;


# Testing 1,2,3,..
#=============================================================================

plan( tests => 15 );

my (@flds,@cons);

@flds = $tbl_order->pkey_fields;
is( join(",",@flds), "order_id", "pkey_fields" );
isa_ok( $flds[0], "SQL::Translator::Schema::Field" );

@flds = $tbl_order->fkey_fields;
is( join(",",@flds), "customer_id", "fkey_fields" );
isa_ok( $flds[0], "SQL::Translator::Schema::Field" );

@flds = $tbl_order->nonpkey_fields;
is( join(",",@flds), "customer_id,invoice_number,notes", "nonpkey_fields" );
isa_ok( $flds[0], "SQL::Translator::Schema::Field" );
isa_ok( $flds[1], "SQL::Translator::Schema::Field" );

@flds = $tbl_order->data_fields;
is( join(",",@flds), "invoice_number,notes", "data_fields" );
isa_ok( $flds[0], "SQL::Translator::Schema::Field" );

@flds = $tbl_order->unique_fields;
is( join(",",@flds), "invoice_number", "unique_fields" );
isa_ok( $flds[0], "SQL::Translator::Schema::Field" );

@cons = $tbl_order->unique_constraints;
is( scalar @cons, 1, "Number of unique_constraints is 1" );
is( $cons[0]->name, "con_unique_invoice", "unique_constraints" );

@cons = $tbl_order->fkey_constraints;
is( scalar @cons, 1, "Number of fkey_constraints is 1" );
is( $cons[0]->name, "con_customer_fkey", "fkey_constraints" );

