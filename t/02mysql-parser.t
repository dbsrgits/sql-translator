#!/usr/bin/perl
# vim: set ft=perl:
#
# NOTE!!!!
# For now, all this is testing is that Parse::RecDescent does not
# die with an error!  I am not verifying the validity of the data
# returned here, just that the parser actually completed its parsing!
#

use strict;

use Test::More tests => 11;
use SQL::Translator;
use SQL::Translator::Parser::MySQL qw(parse);

my $tr = SQL::Translator->new;
my $data = q|create table sessions (
    id char(32) not null primary key,
    a_session text
);|;

my $val = parse($tr, $data);

# $val holds the processed data structure.

# The data structure should have one key:
is(scalar keys %{$val}, 1);

# The data structure should have a single key, named sessions
ok(defined $val->{'sessions'});

# $val->{'sessions'} should have a single index (since we haven't
# defined an index, but have defined a primary key)
my $indices = $val->{'sessions'}->{'indices'};
is(scalar @{$indices}, 1, "correct index number");

is($indices->[0]->{'type'}, 'primary_key', "correct index type");
is($indices->[0]->{'fields'}->[0], 'id', "correct index name");

# $val->{'sessions'} should have two fields, id and a_sessionn
my $fields = $val->{'sessions'}->{'fields'};
is(scalar keys %{$fields}, 2, "correct fields number");

is($fields->{'id'}->{'data_type'}, 'char',
    "correct field type: id (char)");

is ($fields->{'a_session'}->{'data_type'}, 'text',
    "correct field type: a_session (text)");

is($fields->{'id'}->{'is_primary_key'}, 1, 
    "correct key identification (id == key)");

ok(! defined $fields->{'a_session'}->{'is_primary_key'}, 
    "correct key identification (a_session != key)");

# Test that the order is being maintained by the internal order
# data element
my @order = sort { $fields->{$a}->{'order'}
                             <=>
                   $fields->{$b}->{'order'}
                 } keys %{$fields};

ok($order[0] eq 'id' && $order[1] eq 'a_session', "ordering of fields");
