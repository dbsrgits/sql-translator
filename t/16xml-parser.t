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
 
BEGIN {
    maybe_plan(284, 'SQL::Translator::Parser::XML::SQLFairy');
}

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

    # Hmmm, when using schema_ok the field test data gets a bit too nested and
    # fiddly to work with. (See 28xml-xmi-parser-sqlfairy.t for more split out
    # version)
    schema_ok( $scma, {
        tables => [
            {
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
            } # end table Basic
        ], # end tables

        views => [
            {
                name => 'email_list',
                sql => "SELECT email FROM Basic WHERE email IS NOT NULL",
                fields => ['email'],
            },
        ],

        triggers => [
            {
                name                => 'foo_trigger',
                perform_action_when => 'after',
                database_event      => 'insert',
                on_table            => 'foo',
                action              => 'update modified=timestamp();',
            },
        ],

        procedures => [
            {
                name       => 'foo_proc',
                sql        => 'select foo from bar',
                parameters => ['foo', 'bar'],
                owner      => 'Nomar',
                comments   => 'Go Sox!',
            },
        ],

    }); # end schema

} # end do_file()
