#!/usr/bin/perl -w
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use Test::More;
use Test::Exception;
use Test::SQL::Translator qw(maybe_plan);

use Data::Dumper;
use FindBin qw/$Bin/;

# Testing 1,2,3,4...
#=============================================================================

BEGIN {
    maybe_plan(6,
        'SQL::Translator::Parser::XML::SQLFairy',
        'Template 2.20',
        'Test::Differences'
    );
}
use Test::Differences;

use SQL::Translator;
use SQL::Translator::Producer::TTSchema;

# Main test. Template whole schema and test tt_vars
{
    my $obj;
    $obj = SQL::Translator->new(
        show_warnings  => 0,
        from           => "XML-SQLFairy",
        filename       => "$Bin/data/xml/schema.xml",
        to             => "TTSchema",
        producer_args  => {
            ttfile  => "$Bin/data/template/basic.tt",
            tt_vars => {
                foo   => 'bar',
                hello => 'world',
            },
        },
    );
    my $out;
    lives_ok { $out = $obj->translate; }  "Translate ran";
    ok $out ne ""                        ,"Produced something!";
    eq_or_diff
      $out,
      do { local (@ARGV, $/) = "$Bin/data/template/testresult_basic.txt"; <> },
      "Output looks right"
    ;
}

# Test passing of Template config
{
    my $tmpl = q{
    [%- FOREACH table = schema.get_tables %]
    Table: $table
    [%- END %]};
    my $obj;
    $obj = SQL::Translator->new(
        show_warnings  => 0,
        from           => "XML-SQLFairy",
        filename       => "$Bin/data/xml/schema.xml",
        to             => "TTSchema",
        producer_args  => {
            ttfile  => \$tmpl,
            tt_conf => {
                INTERPOLATE => 1,
            },
            tt_vars => {
                foo   => 'bar',
                hello => 'world',
            },
        },
    );
    my $out;
    lives_ok { $out = $obj->translate; }  "Translate ran";
    ok $out ne ""                        ,"Produced something!";
    local $/ = undef; # slurp
    eq_or_diff $out, q{
    Table: Basic
    Table: Another}
    ,"Output looks right";
}
