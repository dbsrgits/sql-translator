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
use Test::Exception;
use Data::Dumper;
use SQL::Translator;
use SQL::Translator::Schema::Constants;

# Simple options. -d for debug
my %opt;
BEGIN { map { $opt{$_}=1 if s/^-// } @ARGV; }
use constant DEBUG => (exists $opt{d} ? 1 : 0);


# Testing 1,2,3,4...
#=============================================================================

plan tests => 274;

foreach (
    "$Bin/data/xml/schema-basic.xml",
    "$Bin/data/xml/schema-basic-attribs.xml"
) {
    do_file($_);
}

sub do_file {
    my $testschema = shift;
    # Parse the test XML schema
    my $obj;
    $obj = SQL::Translator->new(
        debug          => DEBUG,
        show_warnings  => 1,
        add_drop_table => 1,
    );
    die "Can't find test schema $testschema" unless -e $testschema;
    my $sql = $obj->translate(
        from     => 'XML-SQLFairy',
        to       => 'MySQL',
        filename => $testschema,
    );
    print $sql if DEBUG;

    # Test the schema objs generted from the XML
    #
    my $scma = $obj->schema;
    my @tblnames = map {$_->name} $scma->get_tables;
    is_deeply( \@tblnames, [qw/Basic/], "tables");

    # Basic
    my $tbl = $scma->get_table("Basic");
    is_deeply( [map {$_->name} $tbl->get_fields], [qw/
        id title description email explicitnulldef explicitemptystring emptytagdef
    /] , "Table Basic's fields");

    table_ok( $scma->get_table("Basic"), {
        name => "Basic",
        fields => [
        {
            name => "id",
            data_type => "int",
            default_value => undef,
            is_nullable => 0,
            size => 10,
            is_primary_key => 1,
            is_auto_increment => 1,
        },
        {
            name => "title",
            data_type => "varchar",
            is_nullable => 0,
            default_value => "hello",
            size => 100,
        },
        {
            name => "description",
            data_type => "text",
            is_nullable => 1,
            default_value => "",
        },
        {
            name => "email",
            data_type => "varchar",
            size => 255,
            is_unique => 1,
            default_value => undef,
            is_nullable => 1,
        },
        {
            name => "explicitnulldef",
            data_type => "varchar",
            default_value => undef,
            is_nullable => 1,
        },
        {
            name => "explicitemptystring",
            data_type => "varchar",
            default_value => "",
            is_nullable => 1,
        },
        {
            name => "emptytagdef",
            data_type => "varchar",
            default_value => "",
            is_nullable => 1,
        },
        ],
        constraints => [
        {
            type => PRIMARY_KEY,
            fields => ["id"],
        },
        {
            name => 'emailuniqueindex',
            type => UNIQUE,
            fields => ["email"],
        }
        ],
        indices => [
        {
            name => "titleindex",
            fields => ["title"],
        },
        ],
    });

    #
    # View
    #
    my @views = $scma->get_views;
    view_ok( $views[0], {
        name => 'email_list',
        sql => "SELECT email FROM Basic WHERE email IS NOT NULL",
        fields => ['email'],
    });

    my @triggs = $scma->get_triggers;
    trigger_ok( $triggs[0], {
        name                => 'foo_trigger',
        perform_action_when => 'after',
        database_event      => 'insert',
        on_table            => 'foo',
        action              => 'update modified=timestamp();',
    });


    #
    # Procedure
    #
    my @procs = $scma->get_procedures;
    procedure_ok( $procs[0], {
        name       => 'foo_proc',
        sql        => 'select foo from bar',
        parameters => ['foo', 'bar'],
        owner      => 'Nomar',
        comments   => 'Go Sox!',
    });

    print "Debug:", Dumper($obj) if DEBUG;
} # /Test of schema
