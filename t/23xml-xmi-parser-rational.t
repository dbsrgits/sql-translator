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
use Test::Exception;
use Test::SQL::Translator qw(maybe_plan);
use SQL::Translator;
use SQL::Translator::Schema::Constants;

BEGIN {
    maybe_plan(92,
        'SQL::Translator::Parser::XML::XMI::Rational',
        'SQL::Translator::Producer::MySQL');
}

# Usefull test subs for the schema objs
#=============================================================================

sub test_field {
    my ($f1,$test) = @_;

	is( $f1->name, $test->{name}, "  Field name '$test->{name}'" );
    
	is( $f1->data_type, $test->{data_type}, "    Type is '$test->{data_type}'" )
	if exists $test->{data_type};
    
	is( $f1->size, $test->{size}, "    Size is '$test->{size}'" )
	if exists $test->{size};
    
	is( $f1->default_value, $test->{default_value},
	"    Default value is ".(defined($test->{default_value}) ? "'$test->{default_value}'" : "UNDEF" ) )
	if exists $test->{default_value};
	
	is( $f1->is_nullable, $test->{is_nullable}, 
		"    ".($test->{is_nullable} ? 'can' : 'cannot').' be null' )
	if exists $test->{is_nullable};
    
	is( $f1->is_unique, $test->{is_unique}, 
		"    ".($test->{is_unique} ? 'can' : 'cannot').' be unique' )
	if exists $test->{is_unique};
    
	is( $f1->is_primary_key, $test->{is_primary_key}, 
		"    is ".($test->{is_primary_key} ? '' : 'not').' a primary_key' )
	if exists $test->{is_primary_key};
    
	is( $f1->is_foreign_key, $test->{is_foreign_key}, 
		"    is ".($test->{is_foreign_key} ? '' : 'not').' a foreign_key' )
	if exists $test->{is_foreign_key};
    
	is( $f1->is_auto_increment, $test->{is_auto_increment}, 
	"    is ".($test->{is_auto_increment} ?  '' : 'not').' an auto_increment' )
	if exists $test->{is_auto_increment};
}

sub constraint_ok {
    my ($con,$test) = @_;
	#$test->{name} ||= "<anon>";

	if ( exists $test->{name} ) {
		is( $con->name, $test->{name}, "  Constraint '$test->{name}'" );
	}
	else {
		ok( $con, "  Constraint" );
	}
	
	is( $con->type, $test->{type}, "    type is '$test->{type}'" )
	if exists $test->{type};
	
	is( $con->table->name, $test->{table}, "    table is '$test->{table}'" )
	if exists $test->{table};
	
	is( join(",",$con->fields), $test->{fields},
	"    fields is '$test->{fields}'" )
	if exists $test->{fields};
	
	is( $con->reference_table, $test->{reference_table},
	"    reference_table is '$test->{reference_table}'" )
	if exists $test->{reference_table};
	
	is( join(",",$con->reference_fields), $test->{reference_fields},
	"    reference_fields is '$test->{reference_fields}'" )
	if exists $test->{reference_fields};
	
	is( $con->match_type, $test->{match_type},
	"    match_type is '$test->{match_type}'" )
	if exists $test->{match_type};
	
	is( $con->on_delete, $test->{on_delete},
	"    on_delete is '$test->{on_delete}'" )
	if exists $test->{on_delete};
	
	is( $con->on_update, $test->{on_update},
	"    on_update is '$test->{on_update}'" )
	if exists $test->{on_update};
}

sub test_table {
    my $tbl = shift;
    my %arg = @_;
	$arg{constraints} ||= [];
    my $name = $arg{name} || die "Need a table name to test.";
    
	my @fldnames = map { $_->{name} } @{$arg{fields}};
	is_deeply( [ map {$_->name}   $tbl->get_fields ],
               [ map {$_->{name}} @{$arg{fields}} ],
               "Table $name\'s fields" );
    foreach ( @{$arg{fields}} ) {
        my $name = $_->{name} || die "Need a field name to test.";
        test_field( $tbl->get_field($name), $_ );
    }
	
	if ( my @tcons = @{$arg{constraints}} ) {
		my @cons = $tbl->get_constraints;
		is(scalar(@cons), scalar(@tcons),
		"Table $name has ".scalar(@tcons)." Constraints");
		foreach ( @cons ) {
			my $ans = { table => $tbl->name, %{shift @tcons}};
			constraint_ok( $_, $ans  );
		}
	}
}

# Testing 1,2,3,..
#=============================================================================

my $testschema = "$Bin/data/xmi/OrderDB.rationalprofile.poseidon2.xmi";
die "Can't find test schema $testschema" unless -e $testschema;

my $obj;
$obj = SQL::Translator->new(
    filename => $testschema,
    from     => 'XML-XMI-Rational',
    to       => 'MySQL',
    debug          => DEBUG,
    show_warnings  => 1,
    add_drop_table => 0,
);
my $sql = $obj->translate;
print $sql if DEBUG;

#
# Test the schema
#
my $scma = $obj->schema;
is( $scma->is_valid, 1, 'Schema is valid' );
my @tblnames = map {$_->name} $scma->get_tables;
is(scalar(@{$scma->get_tables}), scalar(@tblnames), "Right number of tables");
is_deeply( \@tblnames, [qw/Order OrderLine Customer/]
    ,"tables");

test_table( $scma->get_table("Customer"),
    name => "Customer",
    fields => [
    {
        name => "customerID",
        data_type => "INT",
		size => 10,
        default_value => undef,
        is_nullable => 0,
        is_primary_key => 1,
    },
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
    ],
	constraints => [
		{
			type => "PRIMARY KEY",
			fields => "customerID",
		},
		{
			name => "UniqueEmail",
			type => "UNIQUE",
			fields => "email",
		},
	],
);

test_table( $scma->get_table("Order"),
    name => "Order",
    fields => [
    {
        name => "orderID",
        data_type => "INT",
		size => 10,
        default_value => undef,
        is_nullable => 0,
        is_primary_key => 1,
    },
    {
        name => "customerID",
        data_type => "INT",
		size => 10,
        default_value => undef,
        is_nullable => 0,
        is_primary_key => 0,
        is_foreign_key => 1,
    },
    {
        name => "orderDate",
        data_type => "DATE",
        default_value => undef,
        is_nullable => 0,
        is_primary_key => 0,
    },
    ],
	constraints => [
		{
			type => "PRIMARY KEY",
			fields => "orderID",
		},
		{
			type => "FOREIGN KEY",
			fields => "customerID",
			reference_table => "Customer",
			reference_fields => "customerID",
		},
	],
	# TODO
	#indexes => [
	#	{
	#		name => "idxOrderDate",
	#		type => "INDEX",
	#		fields => "orderDate",
	#	},
	#],
);


test_table( $scma->get_table("OrderLine"),
    name => "OrderLine",
    fields => [
    {
        name => "lineNumber",
        data_type => "INT",
		size => 10,
        default_value => 1,
        is_nullable => 0,
        is_primary_key => 1,
    },
    {
        name => "orderID",
        data_type => "INT",
		size => 10,
        default_value => undef,
        is_nullable => 0,
        is_primary_key => 0,
        is_foreign_key => 1,
    },
    {
        name => "quantity",
        data_type => "INT",
		size => 2,
        default_value => 1,
        is_nullable => 0,
        is_primary_key => 0,
    },
    ],
	constraints => [
		{
			type => "PRIMARY KEY",
			fields => "lineNumber,orderID",
		},
		{
			type => "FOREIGN KEY",
			fields => "orderID",
			reference_table => "Order",
			reference_fields => "orderID",
		},
	],
);
