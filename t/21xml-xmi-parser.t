#!/usr/bin/perl -w 
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#
# Tests basic functionality and the default xmi2schema
#

use strict;
use FindBin qw/$Bin/;
use Data::Dumper;

# run test with -d for debug
my %opt;
BEGIN { map { $opt{$_}=1 if s/^-// } @ARGV; }
use constant DEBUG => (exists $opt{d} ? 1 : 0);

use Test::More;
use Test::Exception;
use SQL::Translator;
use SQL::Translator::Schema::Constants;

# Usefull test subs for the schema objs
#=============================================================================

my %ATTRIBUTES;
$ATTRIBUTES{field} = [qw/
name
data_type
default_value
size
is_primary_key
is_unique
is_nullable
is_foreign_key
is_auto_increment
/];

sub test_field {
    my ($fld,$test) = @_;
    die "test_field needs a least a name!" unless $test->{name};
    my $name = $test->{name};

    foreach my $attr ( @{$ATTRIBUTES{field}} ) {
        if ( exists $test->{$attr} ) {
            my $ans = $test->{$attr};
            if ( $attr =~ m/^is_/ ) {
                if ($ans) { ok $fld->$attr,  " $name - $attr true"; }
                else      { ok !$fld->$attr, " $name - $attr false"; }
            }
            else {
                is $fld->$attr, $ans, " $name - $attr = '"
                                     .(defined $ans ? $ans : "NULL" )."'";
            }
        }
        else {
            ok !$fld->$attr, "$name - $attr not set";
        }
    }
}

sub test_table {
    my $tbl = shift;
    my %arg = @_;
    my $name = $arg{name} || die "Need a table name to test.";
    my @fldnames = map { $_->{name} } @{$arg{fields}};
    is_deeply( [ map {$_->name}   $tbl->get_fields ],
               [ map {$_->{name}} @{$arg{fields}} ],
               "Table $name\'s fields" );
    foreach ( @{$arg{fields}} ) {
        my $name = $_->{name} || die "Need a field name to test.";
        test_field( $tbl->get_field($name), $_ );
    }
}

# Testing 1,2,3,..
#=============================================================================

plan tests => 103;

my $testschema = "$Bin/data/xmi/Foo.poseidon2.xmi";
die "Can't find test schema $testschema" unless -e $testschema;

my $obj;
$obj = SQL::Translator->new(
    filename => $testschema,
    from     => 'XML-XMI',
    to       => 'MySQL',
    debug          => DEBUG,
    show_warnings  => 1,
);
my $sql = $obj->translate;
print $sql if DEBUG;

#
# Test the schema
#
my $scma = $obj->schema;
my @tblnames = map {$_->name} $scma->get_tables;
is_deeply( \@tblnames, [qw/Foo PrivateFoo Recording CD Track ProtectedFoo/]
    ,"tables");

#
# Tables
#
# Foo
#
test_table( $scma->get_table("Foo"),
    name => "Foo",
    fields => [
        {
            name => "fooid",
            data_type => "int",
            default_value => undef,
            is_nullable => 1,
            is_primary_key => 1,
        },
        {
            name => "name",
            data_type => "varchar",
            default_value => "",
            is_nullable => 1,
        },
        {
            name => "protectedname",
            data_type => "varchar",
            default_value => undef,
            is_nullable => 1,
        },
        {
            name => "privatename",
            data_type => "varchar",
            default_value => undef,
            is_nullable => 1,
        },
    ],
);

#
# Recording
#
test_table( $scma->get_table("Recording"),
    name => "Recording",
    fields => [
    {
        name => "recordingid",
        data_type => "int",
        default_value => undef,
        is_nullable => 1,
        is_primary_key => 1,
    },
    {
        name => "title",
        data_type => "varchar",
        is_nullable => 1,
    },
    {
        name => "type",
        data_type => "varchar",
        is_nullable => 1,
    },
    ],
);

#
# Track
#
test_table( $scma->get_table("Track"),
    name => "Track",
    fields => [
    {
        name => "trackid",
        data_type => "int",
        default_value => undef,
        is_nullable => 1,
        is_primary_key => 1,
    },
    {
        name => "recordingid",
        data_type => "int",
        default_value => undef,
        is_nullable => 1,
        is_primary_key => 0,
        #is_foreign_key => 1,
    },
    {
        name => "number",
        data_type => "int",
        default_value => "1",
        is_nullable => 1,
    },
    {
        name => "name",
        data_type => "varchar",
        is_nullable => 1,
    },
    ],
);
