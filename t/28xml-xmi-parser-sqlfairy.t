#!/usr/bin/perl -w
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use FindBin qw/$Bin/;
use Data::Dumper;

# run with -d for debug
my %opt;
BEGIN { map { $opt{$_}=1 if s/^-// } @ARGV; }
use constant DEBUG => (exists $opt{d} ? 1 : 0);

use Test::More;
use Test::SQL::Translator;
use SQL::Translator;
use SQL::Translator::Schema::Constants;

# Testing 1,2,3,..
#=============================================================================

BEGIN {
    maybe_plan(321,
        'SQL::Translator::Parser::XML::XMI::SQLFairy',
        'SQL::Translator::Producer::MySQL');
}

my $testschema = "$Bin/data/xmi/OrderDB.sqlfairy.poseidon2.xmi";
die "Can't find test schema $testschema" unless -e $testschema;

my $obj;
$obj = SQL::Translator->new(
    filename => $testschema,
    from     => 'XML-XMI-SQLFairy',
    to       => 'MySQL',
    debug          => DEBUG,
    show_warnings  => 1,
);
my $sql = $obj->translate;
ok( $sql, "Got some SQL");
print $sql if DEBUG;
print "Translator:",Dumper($obj) if DEBUG;


#
# Test the schema
#
my $scma = $obj->schema;
is( $scma->is_valid, 1, 'Schema is valid' );
my @tblnames = map {$_->name} $scma->get_tables;
is(scalar(@{$scma->get_tables}), scalar(@tblnames), "Right number of tables");
is_deeply( \@tblnames, 
    [qw/Order OrderLine Customer ContactDetails ContactDetails_Customer/]
,"tables");

table_ok( $scma->get_table("Customer"), {
    name => "Customer",
    fields => [
    {
        name => "name",
        data_type => "VARCHAR",
        size => 255,
        default_value => undef,
        is_nullable => 0,
        is_primary_key => 0,
    },
    {
        name => "email",
        data_type => "VARCHAR",
        size => 255,
        default_value => undef,
        is_nullable => 1,
        is_primary_key => 0,
    },
    {
        name => "CustomerID",
        data_type => "INT",
        size => 10,
        default_value => undef,
        is_nullable => 0,
        is_primary_key => 1,
        is_auto_increment => 1,
    },
    ],
    constraints => [
        {
            type => "PRIMARY KEY",
            fields => ["CustomerID"],
        },
        #{
        #    name => "UniqueEmail",
        #    type => "UNIQUE",
        #    fields => ["email"],
        #},
    ],
});

table_ok( $scma->get_table("ContactDetails_Customer"), {
    name => "ContactDetails_Customer",
    fields => [
    {
        name => "ContactDetailsID",
        data_type => "INT",
        size => 10,
        default_value => undef,
        is_nullable => 0,
        is_primary_key => 1,
        is_auto_increment => 0,
        is_foreign_key => 1,
    },
    {
        name => "CustomerID",
        data_type => "INT",
        size => 10,
        default_value => undef,
        is_nullable => 0,
        is_primary_key => 1,
        is_auto_increment => 0,
        is_foreign_key => 1,
    },
    ],
    constraints => [
        {
            type => "FOREIGN KEY",
            fields => ["ContactDetailsID"],
            reference_table => "ContactDetails",
            reference_fields => ["ContactDetailsID"],
        },
        {
            type => "FOREIGN KEY",
            fields => ["CustomerID"],
            reference_table => "Customer",
            reference_fields => ["CustomerID"],
        },
        {
            type => "PRIMARY KEY",
            fields => ["ContactDetailsID","CustomerID"],
        },
    ],
});

table_ok( $scma->get_table("ContactDetails"), {
    name => "ContactDetails",
    fields => [
    {
        name => "address",
        data_type => "VARCHAR",
        size => "255",
        default_value => undef,
        is_nullable => 1,
        is_primary_key => 0,
    },
    {
        name => "telephone",
        data_type => "VARCHAR",
        size => "255",
        default_value => undef,
        is_nullable => 1,
        is_primary_key => 0,
    },
    {
        name => "ContactDetailsID",
        data_type => "INT",
        size => 10,
        default_value => undef,
        is_nullable => 0,
        is_primary_key => 1,
        is_auto_increment => 1,
    },
    ],
    constraints => [
        {
            type => "PRIMARY KEY",
            fields => ["ContactDetailsID"],
        },
    ],
});

table_ok( $scma->get_table("Order"), {
    name => "Order",
    fields => [
    {
        name => "invoiceNumber",
        data_type => "INT",
        size => 10,
        default_value => undef,
        is_nullable => 0,
        is_primary_key => 1,
        is_auto_increment => 1,
    },
    {
        name => "orderDate",
        data_type => "DATE",
        default_value => undef,
        is_nullable => 0,
        is_primary_key => 0,
    },
    {
        name => "CustomerID",
        data_type => "INT",
        size => 10,
        default_value => undef,
        is_nullable => 0,
        is_primary_key => 0,
        is_foreign_key => 1,
    },
    ],
    constraints => [
        {
            type => "PRIMARY KEY",
            fields => ["invoiceNumber"],
        },
        {
            type => "FOREIGN KEY",
            fields => ["CustomerID"],
            reference_table => "Customer",
            reference_fields => ["CustomerID"],
        },
    ],
    # TODO
    #indexes => [
    #    {
    #        name => "idxOrderDate",
    #        type => "INDEX",
    #        fields => ["orderDate"],
    #    },
    #],
});


table_ok( $scma->get_table("OrderLine"), {
    name => "OrderLine",
    fields => [
    {
        name => "lineNumber",
        data_type => "INT",
        size => 255,
        default_value => 1,
        is_nullable => 0,
        is_primary_key => 0,
    },
    {
        name => "quantity",
        data_type => "INT",
        size => 255,
        default_value => 1,
        is_nullable => 0,
        is_primary_key => 0,
    },
    {
        name => "OrderLineID",
        data_type => "INT",
        size => 10,
        default_value => undef,
        is_nullable => 0,
        is_primary_key => 1,
        is_auto_increment => 1,
    },
    {
        name => "invoiceNumber",
        data_type => "INT",
        size => 10,
        default_value => undef,
        is_nullable => 1,
        is_primary_key => 1,
    },
    ],
    constraints => [
        {
            type => "PRIMARY KEY",
            fields => ["OrderLineID","invoiceNumber"],
        },
        {
            type => "FOREIGN KEY",
            fields => ["invoiceNumber"],
            reference_table => "Order",
            reference_fields => ["invoiceNumber"],
        },
    ],
});
