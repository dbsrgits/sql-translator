#!/usr/bin/perl -w 
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use Test::More;
use Test::Exception;
use Test::SQL::Translator qw(maybe_plan);

use Data::Dumper;
use vars '%opt';
BEGIN { map { $opt{$_}=1 if s/^-// } @ARGV; }
use constant DEBUG => (exists $opt{d} ? 1 : 0);

use FindBin qw/$Bin/;
use lib ("$Bin/lib");

# Testing 1,2,3,4...
#=============================================================================
package main;

BEGIN {
    maybe_plan(4, 'Template', 'Test::Differences')
}
use Test::Differences;

use SQL::Translator;
use SQL::Translator::Producer::TTSchema;

# Parse the test XML schema
my $obj;
$obj = SQL::Translator->new(
    debug          => DEBUG, #$opt{d},
    show_warnings  => 1,
    add_drop_table => 1,
    from           => "XML-SQLFairy",
    filename       => "$Bin/data/xml/schema-basic.xml",
    to             => "Producer::BaseTest::produce",
    producer_args  => {
        ttfile => "$Bin/data/template/basic.tt",
    },
);
my $out;
lives_ok { $out = $obj->translate; }  "Translate ran";
is $obj->error, ''                   ,"No errors";
ok $out ne ""                        ,"Produced something!";
local $/ = undef; # slurp
eq_or_diff $out, <DATA>              ,"Output looks right";

print $out if DEBUG;
#print "Debug:", Dumper($obj) if DEBUG;

__DATA__
Hello World
Basic
foo:bar
