#!/usr/bin/perl
# vim: set ft=perl:
#
# NOTE!!!!
# For now, all this is testing is that Parse::RecDescent does not
# die with an error!  I am not verifying the validity of the data
# returned here, just that the parser actually completed its parsing!
#

use strict;
use SQL::Translator;
use SQL::Translator::Parser::MySQL qw(parse);

$SQL::Translator::DEBUG = 0;

my $tr = SQL::Translator->new;
my $data = q|create table sessions (
    id char(32) not null primary key,
    a_session text
);|;

BEGIN { print "1..11\n"; }

my $val = parse($tr, $data);

# $val holds the processed data structure.

# The data structure should have one key:
print "not " if (scalar keys %{$val} != 1);
print "ok 1\n";

# The data structure should have a single key, named sessions
print "not " unless (defined $val->{'sessions'});
print qq(ok 2 # has a key named "sessions"\n);

# $val->{'sessions'} should have a single index (since we haven't
# defined an index, but have defined a primary key)
my $indeces = $val->{'sessions'}->{'indeces'};
print "not " unless (scalar @{$indeces} == 1);
print "ok 3 # correct index number\n";

print "not " unless ($indeces->[0]->{'type'} eq 'primary_key');
print "ok 4 # correct index type\n";
print "not " unless ($indeces->[0]->{'fields'}->[0] eq 'id');
print "ok 5 # correct index name\n";

# $val->{'sessions'} should have two fields, id and a_sessionn
my $fields = $val->{'sessions'}->{'fields'};
print "not " unless (scalar keys %{$fields} == 2);
print "ok 6 # correct fields number\n";

print "not " unless ($fields->{'id'}->{'data_type'} eq 'char');
print "ok 7 # correct field type: id (char)\n";

print "not " unless ($fields->{'a_session'}->{'data_type'} eq 'text');
print "ok 8 # correct field type: a_session (text)\n";

print "not " unless ($fields->{'id'}->{'is_primary_key'} == 1);
print "ok 9 # correct key identification (id == key)\n";

print "not " if (defined $fields->{'a_session'}->{'is_primary_key'});
print "ok 10 # correct key identification (a_session != key)\n";

# Test that the order is being maintained by the internal order
# data element
my @order = sort { $fields->{$a}->{'order'}
                             <=>
                   $fields->{$b}->{'order'}
                 } keys %{$fields};
print "not " unless ($order[0] eq 'id' && $order[1] eq 'a_session');
print "ok 11 # ordering of fields\n";
