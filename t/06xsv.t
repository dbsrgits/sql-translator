#!/usr/bin/perl
# vim: set ft=perl:
#
#

use strict;
use SQL::Translator;
use SQL::Translator::Parser::xSV qw(parse);

$SQL::Translator::DEBUG = 0;

my $tr = SQL::Translator->new;
my $data = q|One, Two, Three, Four, Five
I, Am, Some, Data, Yo
And, So, am, I, "you crazy, crazy bastard"
);|;

BEGIN { print "1..10\n"; }

my $val = parse($tr, $data);

# $val holds the processed data structure.

# The data structure should have one key:
print "not " if (scalar keys %{$val} != 1);
print "ok 1\n";

# The data structure should have a single key, named sessions
print "not " unless (defined $val->{'table1'});
print qq(ok 2 # has a key named "table1"\n);

# $val->{'table1'} should have a single index (since we haven't
# defined an index, but have defined a primary key)
my $indices = $val->{'table1'}->{'indices'};
print "not " unless (scalar @{$indices} == 1);
print "ok 3 # correct index number\n";

print "not " unless ($indices->[0]->{'type'} eq 'primary_key');
print "ok 4 # correct index type\n";
print "not " unless ($indices->[0]->{'fields'}->[0] eq 'One');
print "ok 5 # correct index name\n";

# $val->{'table1'} should have two fields, id and a_sessionn
my $fields = $val->{'table1'}->{'fields'};
print "not " unless (scalar keys %{$fields} == 5);
print "ok 6 # correct number of fields (5)\n";

print "not " unless ($fields->{'One'}->{'data_type'} eq 'char');
print "ok 7 # correct field type: One (char)\n";

print "not " unless ($fields->{'One'}->{'is_primary_key'} == 1);
print "ok 8 # correct key identification (One == key)\n";

print "not " if (defined $fields->{'Two'}->{'is_primary_key'});
print "ok 9 # correct key identification (Two != key)\n";

# Test that the order is being maintained by the internal order
# data element
my @order = sort { $fields->{$a}->{'order'}
                             <=>
                   $fields->{$b}->{'order'}
                 } keys %{$fields};
print "not " unless ($order[0] eq 'One' && $order[4] eq 'Five');
print "ok 10 # ordering of fields\n";
