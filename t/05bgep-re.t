#!/usr/bin/perl
# vim: set ft=perl:
#

BEGIN { print "1..1\n"; }

use strict;
use Data::Dumper;
use SQL::Translator;
use SQL::Translator::Parser::MySQL;
use SQL::Translator::Producer::XML;

$SQL::Translator::DEBUG = 0;

my $tr = SQL::Translator->new(parser => "MySQL", producer => "XML");

my $datafile = "t/data/mysql/BGEP-RE-create.sql";
my $data;
open FH, $datafile or die "Can't open $datafile: $!";
read(FH, $data, -s $datafile);
close FH;


print $tr->translate(\$data);
print "ok 1\n";

