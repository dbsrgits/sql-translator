#!/usr/bin/perl
# vim: set ft=perl:
#

use strict;
use Data::Dumper;
use SQL::Translator;
use SQL::Translator::Parser::MySQL qw(parse);

$SQL::Translator::DEBUG = 0;

my $tr = SQL::Translator->new;

my $datafile = "t/data/mysql/BGEP-RE-create.sql";
my $data;
open FH, $datafile or die "Can't open $datafile: $!";
read(FH, $data, -s $datafile);
close FH;

print "Data is ", length $data, " bytes\n";
#print $data;

my $val = parse($tr, $data);
print Dumper($val);
