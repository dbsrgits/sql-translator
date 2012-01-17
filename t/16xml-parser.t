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
    maybe_plan(238, 'SQL::Translator::Parser::XML::SQLFairy');
}

my $testschema = "$Bin/data/xml/schema.xml";

my $sqlt;
$sqlt = SQL::Translator->new(
    debug          => DEBUG,
    show_warnings  => 1,
    add_drop_table => 1,
);
die "Can't find test schema $testschema" unless -e $testschema;

my $sql;
{
  my @w;
  local $SIG{__WARN__} = sub { push @w, $_[0] if $_[0] =~ /The database_event tag is deprecated - please use database_events/ };

  $sql = $sqlt->translate(
    from     => 'XML-SQLFairy',
    to       => 'MySQL',
    filename => $testschema,
  ) or die $sqlt->error;
  print $sql if DEBUG;

  ok (@w, 'database_event deprecation warning issued');
}

# Test the schema objs generted from the XML
#
my $scma = $sqlt->schema;

# Hmmm, when using schema_ok the field test data gets a bit too nested and
# fiddly to work with. (See 28xml-xmi-parser-sqlfairy.t for more a split out
# version)
schema_ok( $scma, {
    tables => [
        {
            name => "Basic",
            options => [ { ENGINE => 'InnoDB' } ],
            extra => {
                foo => "bar",
                hello => "world",
                bar => "baz",
            },
            fields => [
                {
                    name => "id",
                    data_type => "int",
                    default_value => undef,
                    is_nullable => 0,
                    size => 10,
                    is_primary_key => 1,
                    is_auto_increment => 1,
                    extra => { ZEROFILL => 1 },
                },
                {
                    name => "title",
                    data_type => "varchar",
                    is_nullable => 0,
                    default_value => "hello",
                    size => 100,
                    is_unique => 1,
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
                    size => 500,
                    is_unique => 1,
                    default_value => undef,
                    is_nullable => 1,
                    extra => {
                        foo => "bar",
                        hello => "world",
                        bar => "baz",
                    }
                },
                {
                    name => "explicitnulldef",
                    data_type => "varchar",
                    default_value => undef,
                    is_nullable => 1,
                    size => 255,
                },
                {
                    name => "explicitemptystring",
                    data_type => "varchar",
                    default_value => "",
                    is_nullable => 1,
                    size => 255,
                },
                {
                    name => "emptytagdef",
                    data_type => "varchar",
                    default_value => "",
                    is_nullable => 1,
                    comments => "Hello emptytagdef",
                    size => 255,
                },
                {
                    name => "another_id",
                    data_type => "int",
                    size => "10",
                    default_value => 2,
                    is_nullable => 1,
                    is_foreign_key => 1,
                },
                {
                    name => "timest",
                    data_type => "timestamp",
                    size => "0",
                    is_nullable => 1,
                },
            ],
            constraints => [
                {
                    type => PRIMARY_KEY,
                    fields => ["id"],
                    extra => {
                        foo => "bar",
                        hello => "world",
                        bar => "baz",
                    },
                },
                {
                    name => 'emailuniqueindex',
                    type => UNIQUE,
                    fields => ["email"],
                },
                {
                    name => 'very_long_index_name_on_title_field_which_should_be_truncated_for_various_rdbms',
                    type => UNIQUE,
                    fields => ["title"],
                },
                {
                    type => FOREIGN_KEY,
                    fields => ["another_id"],
                    reference_table => "Another",
                    reference_fields => ["id"],
                    name => 'Basic_fk'
                },
            ],
            indices => [
                {
                    name => "titleindex",
                    fields => ["title"],
                    extra => {
                        foo => "bar",
                        hello => "world",
                        bar => "baz",
                    },
                },
            ],
        }, # end table Basic
        {
            name => "Another",
            extra => {
                foo => "bar",
                hello => "world",
                bar => "baz",
            },
            options => [ { ENGINE => 'InnoDB' } ],
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
                    name => "num",
                    data_type => "numeric",
                    default_value => undef,
                    size => '10,2',
                },
            ],
        }, # end table Another
    ], # end tables

    views => [
        {
            name => 'email_list',
            sql => "SELECT email FROM Basic WHERE (email IS NOT NULL)",
            fields => ['email'],
            extra => {
                foo => "bar",
                hello => "world",
                bar => "baz",
            },
        },
    ],

    triggers => [
        {
            name                => 'foo_trigger',
            perform_action_when => 'after',
            database_events     => 'insert',
            on_table            => 'Basic',
            action              => 'update modified=timestamp();',
            extra => {
                foo => "bar",
                hello => "world",
                bar => "baz",
            },
        },
        {
            name                => 'bar_trigger',
            perform_action_when => 'before',
            database_events     => 'insert,update',
            on_table            => 'Basic',
            action              => 'update modified2=timestamp();',
            extra => {
                hello => "aliens",
            },
        },
    ],

    procedures => [
        {
            name       => 'foo_proc',
            sql        => 'select foo from bar',
            parameters => ['foo', 'bar'],
            owner      => 'Nomar',
            comments   => 'Go Sox!',
            extra => {
                foo => "bar",
                hello => "world",
                bar => "baz",
            },
        },
    ],

}); # end schema
