#!/usr/local/bin/perl -w
# vim: set ft=perl:

# This test creates an HTML::Parser instance and uses it to selectively
# parse the output of the HTML producer.  Rather than try to ensure
# that the produced HTML turns into a particular parse tree or anything
# like that, it performs some heuristics on the output.

use strict;
use vars qw(%HANDLERS);
use Test::More;
use Test::SQL::Translator qw(maybe_plan);
use SQL::Translator;

BEGIN {
    maybe_plan(5,
        'HTML::Parser',
        'SQL::Translator::Parser::MySQL',
        'SQL::Translator::Producer::HTML');
}

my ($p, $tables, $classes);
$p = HTML::Parser->new(api_version => 3);
$p->strict_names(1);

my $create = q|
CREATE TABLE foo (
    int id PRIMARY KEY AUTO_INCREMENT NOT NULL,
    name VARCHAR(255)
);
|;

my $tr = SQL::Translator->new(parser => 'MySQL', producer => 'HTML');
my $parsed = $tr->translate(data => $create) or die $tr->error;
my $status;

eval {
    $status = $p->parse($parsed);
};
if ($@) {
    daig $@;
    fail("Unable to parse the output!");
}

# General
ok($parsed, "Parsed table OK");
ok($status, "Parsed HTML OK");

$p->handler(start => @{$HANDLERS{count_tables}});
$p->parse($parsed);

is($tables, 3, "One table in the SQL produces 3 <table> tags");
$tables = $classes = 0;

$p->handler(start => @{$HANDLERS{count_classes}});
$p->parse($parsed);

is($classes, 1, "One 'LinkTable' class");
$tables = $classes = 0;

$p->handler(start => @{$HANDLERS{sqlfairy}});
$p->parse($parsed);

is($classes, 1, "SQLfairy plug is alive and well ");
$tables = $classes = 0;

# Handler functions for the parser
BEGIN {
    %HANDLERS = (
        count_tables => [
            sub {
                my $tagname = shift;
                $tables++ if ($tagname eq 'table');
            }, 'tagname',
        ],

        count_classes => [
            sub {
                my ($tagname, $attr) = @_;
                if ($tagname eq 'table' &&
                    $attr->{'class'} &&
                    $attr->{'class'} eq 'LinkTable') {
                    $classes++;
                }
            }, 'tagname,attr',
        ],

        sqlfairy => [
            sub {
                my ($tagname, $attr) = @_;
                if ($tagname eq 'a' &&
                    $attr->{'href'} &&
                    $attr->{'href'} =~ /sqlfairy/i) {
                    $classes++;
                }
            }, 'tagname,attr',
        ],
    );
}
