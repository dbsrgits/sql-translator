#!/usr/bin/perl
# vim: set ft=perl:

#
# Tests for xSV parser
#
use strict;
use SQL::Translator;
use SQL::Translator::Parser::xSV qw(parse);
use Test::More tests => 13;

my $tr = SQL::Translator->new;
my $data = q|One, Two, Three, Four, Five, Six, Seven
I, Am, Some, Data, Yo, -10, .04
And, So, am, I, "you crazy, crazy bastard", 500982, 1.1
|;

$tr->parser_args( trim_fields => 1, scan_fields => 1 );
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
is(scalar keys %{$fields} => 7 => "7 fields in %fields");

is($fields->{'One'}->{'data_type'}, 'char',
    "\$fields->{'One'}->{'data_type'} == 'char'");

my $size = join(',', @{ $fields->{'One'}{'size'} } );
is( $size, 3, "\$fields->{'One'}->{'size'} == 3");

is($fields->{'One'}->{'is_primary_key'} => 1,
    "\$fields->{'One'}->{'is_primary_key'} == 1");

ok(! defined $fields->{'Two'}->{'is_primary_key'},
    "\$fields->{'Two'}->{'is_primary_key'} == 0");

is($fields->{'Six'}->{'data_type'}, 'integer',
    "\$fields->{'Six'}->{'data_type'} == 'integer'");

is($fields->{'Seven'}->{'data_type'}, 'float',
    "\$fields->{'Seven'}->{'data_type'} == 'float'");

# Test that the order is being maintained by the internal order
# data element
my @order = sort { $fields->{$a}->{'order'}
                             <=>
                   $fields->{$b}->{'order'}
                 } keys %{$fields};
ok($order[0] eq 'One' && $order[4] eq 'Five', "Ordering OK");
