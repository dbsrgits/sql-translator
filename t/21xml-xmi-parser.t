#!/usr/bin/perl -w 
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#
# basic.t
# -------
# Tests that;
#

use strict;
use Test::More;
use Test::Exception;

use strict;
use Data::Dumper;
my %opt;
BEGIN { map { $opt{$_}=1 if s/^-// } @ARGV; }
use constant DEBUG => (exists $opt{d} ? 1 : 0);
local $SIG{__WARN__} = sub { diag "[warn] ", @_; };

use FindBin qw/$Bin/;

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

plan tests => 111;

use SQL::Translator;
use SQL::Translator::Schema::Constants;

my $testschema = "$Bin/data/xmi/Foo.poseidon2.xmi";
die "Can't find test schema $testschema" unless -e $testschema;
my %base_translator_args = ( 
    filename => $testschema,
    from     => 'XML-XMI',
    to       => 'MySQL',
    debug          => DEBUG,
    show_warnings  => 1,
    add_drop_table => 1,
);

#
# Basic tests
#
{

my $obj;
$obj = SQL::Translator->new(
    filename => $testschema,
    from     => 'XML-XMI',
    to       => 'MySQL',
    debug          => DEBUG,
    show_warnings  => 1,
    add_drop_table => 1,
);
my $sql = $obj->translate;
print $sql if DEBUG;
#print "Debug: translator", Dumper($obj) if DEBUG;
#print "Debug: schema", Dumper($obj->schema) if DEBUG;

#
# Test the schema
#
my $scma = $obj->schema;
my @tblnames = map {$_->name} $scma->get_tables;
is_deeply( \@tblnames, [qw/Foo PrivateFoo Recording Track ProtectedFoo/]
    ,"tables");

# 

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

} # end basic tests

#
# Visibility tests
#
{

# Classes
my @testd = (
    ""          => [qw/Foo PrivateFoo Recording Track ProtectedFoo/],
                   [qw/fooid name protectedname privatename/],
    "public"    => [qw/Foo Recording Track/],
                   [qw/fooid name /],
    "protected" => [qw/Foo Recording Track ProtectedFoo/],
                   [qw/fooid name protectedname/],
    "private"   => [qw/Foo PrivateFoo Recording Track ProtectedFoo/],
                   [qw/fooid name protectedname privatename/],
);
    while ( my ($vis,$tables,$foofields) = splice @testd,0,3 ) {
    my $obj;
    $obj = SQL::Translator->new(
        filename => $testschema,
        from     => 'XML-XMI',
        to       => 'MySQL',
        debug          => DEBUG,
        show_warnings  => 1,
        add_drop_table => 1,
        parser_args => {
            visibility => $vis,
        },
    );
    my $sql = $obj->translate;
    my $scma = $obj->schema;
    
    my @tblnames = map {$_->name} $scma->get_tables;
    is_deeply( \@tblnames, $tables, "Tables with visibility => '$vis'");
    
    my @fldnames = map {$_->name} $scma->get_table("Foo")->get_fields;
    is_deeply( \@fldnames, $foofields, "Foo fields with visibility => '$vis'");
    
    #print "Debug: translator", Dumper($obj) if DEBUG;
    #print "Debug: schema", Dumper($obj->schema) if DEBUG;
}

# # Classes
# %testd = (
#     ""          => [qw/fooid name protectedname privatename/],
#     "public"    => [qw/fooid name /],
#     "protected" => [qw/fooid name protectedname/],
#     "private"   => [qw/fooid name protectedname privatename/],
# );
#     while ( my ($vis,$ans) = each %testd ) {
#     my $obj;
#     $obj = SQL::Translator->new(
#         filename => $testschema,
#         from     => 'XML-XMI',
#         to       => 'MySQL',
#         debug          => DEBUG,
#         show_warnings  => 1,
#         add_drop_table => 1,
#         parser_args => {
#             visibility => $vis,
#         },
#     );
#     my $sql = $obj->translate;
#     my $scma = $obj->schema;
#     my @names = map {$_->name} $scma->get_table("Foo")->get_fields;
#     is_deeply( \@names, $ans, "Foo fields with visibility => '$vis'");
#     
#     #print "Debug: translator", Dumper($obj) if DEBUG;
#     #print "Debug: schema", Dumper($obj->schema) if DEBUG;
# }
# 
} # end visibility tests
