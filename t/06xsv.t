#!/usr/bin/perl
# vim: set ft=perl:
#
#

use strict;
use SQL::Translator;
use SQL::Translator::Parser::xSV qw(parse);
use Test::More;

plan tests => 10;

my $tr = SQL::Translator->new;
my $data = q|One, Two, Three, Four, Five
I, Am, Some, Data, Yo
And, So, am, I, "you crazy, crazy bastard"
);|;

my $val = parse($tr, $data);

# $val holds the processed data structure.

# The data structure should have one key:
is(scalar keys %{$val}, 1, "One table...");

# The data structure should have a single key, named sessions
ok(defined $val->{'table1'} => "...named 'table1'");

# $val->{'table1'} should have a single index (since we haven't
# defined an index, but have defined a primary key)
my $indices = $val->{'table1'}->{'indices'};
is(scalar @{$indices}, 1, "correct index number");

is($indices->[0]->{'type'}, 'primary_key', "correct index type");
is($indices->[0]->{'fields'}->[0], 'One', "correct index name");

# $val->{'table1'} should have two fields, id and a_sessionn
my $fields = $val->{'table1'}->{'fields'};
is(scalar keys %{$fields} => 5 => "5 fields in %fields");

is($fields->{'One'}->{'data_type'}, 'char',
    "\$fields->{'One'}->{'data_type'} == 'char'");

is($fields->{'One'}->{'is_primary_key'} => 1,
    "\$fields->{'One'}->{'is_primary_key'} == 1");

ok(! defined $fields->{'Two'}->{'is_primary_key'},
    "\$fields->{'Two'}->{'is_primary_key'} == 0");

# Test that the order is being maintained by the internal order
# data element
my @order = sort { $fields->{$a}->{'order'}
                             <=>
                   $fields->{$b}->{'order'}
                 } keys %{$fields};
ok($order[0] eq 'One' && $order[4] eq 'Five', "Ordering OK");
