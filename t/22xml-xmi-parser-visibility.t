#!/usr/bin/perl -w 
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#
# Tests the visibility arg.
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
use Test::SQL::Translator qw(maybe_plan);
use SQL::Translator;
use SQL::Translator::Schema::Constants;


maybe_plan(8,
    'SQL::Translator::Parser::XML::XMI',
    'SQL::Translator::Producer::MySQL');

my $testschema = "$Bin/data/xmi/Foo.poseidon2.xmi";
die "Can't find test schema $testschema" unless -e $testschema;

my @testd = (
    ""          => [qw/Foo PrivateFoo Recording CD Track ProtectedFoo/],
                   [qw/fooid name protectedname privatename/],
    "public"    => [qw/Foo Recording CD Track/],
                   [qw/fooid name /],
    "protected" => [qw/Foo Recording CD Track ProtectedFoo/],
                   [qw/fooid name protectedname/],
    "private"   => [qw/Foo PrivateFoo Recording CD Track ProtectedFoo/],
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
        parser_args => {
            visibility => $vis,
        },
    );
    my $sql = $obj->translate;
	print $sql if DEBUG;
    my $scma = $obj->schema;

	# Tables from classes
	my @tblnames = map {$_->name} $scma->get_tables;
    is_deeply( \@tblnames, $tables, "Tables with visibility => '$vis'");

	# Fields from attributes
    my @fldnames = map {$_->name} $scma->get_table("Foo")->get_fields;
    is_deeply( \@fldnames, $foofields, "Foo fields with visibility => '$vis'");
}
