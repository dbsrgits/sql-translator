#!/usr/bin/perl
# vim: set ft=perl:
#
# NOTE!!!!
# For now, all this is testing is that Parse::RecDescent does not
# die with an error!  I am not verifying the validity of the data
# returned here, just that the parser actually completed its parsing!
#

use Symbol;
use Data::Dumper;
use SQL::Translator::Parser::MySQL qw(parse);

my $datafile = "t/data/mysql/Apache-Session-MySQL.sql";
my $data;
my $fh = gensym;

open $fh, $datafile or die "Can't open '$datafile' for reading: $!";
read($fh, $data, -s $datafile);
close $fh or die "Can't close '$datafile': $!";

BEGIN { print "1..1\n"; }

eval { parse($data); };

print "not " if $@;
print "ok 1\n";
