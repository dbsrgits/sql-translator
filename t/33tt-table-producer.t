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
use File::Temp qw/tempdir/;

# Testing 1,2,3,4...
#=============================================================================

BEGIN {
    maybe_plan(8, 'Template 2.20', 'Test::Differences')
}
use Test::Differences;

use SQL::Translator;
use SQL::Translator::Producer::TT::Table;

# Setup a tmp directory we can output files to.
my $tdir = tempdir( CLEANUP => 1 );

# Parse the test XML schema
my $obj;
$obj = SQL::Translator->new(
    debug          => DEBUG, #$opt{d},
    show_warnings  => 1,
    add_drop_table => 1,
    from           => "SQLite",
    filename       => "$Bin/data/sqlite/create.sql",
    to             => "TT-Table",
    producer_args  => {
        tt_table => "$Bin/data/template/table.tt",
        mk_files      => 1,
        mk_files_base => "$tdir",
        mk_file_ext   => "txt",
        on_exists     => "replace",
    },
);
my $out;
lives_ok { $out = $obj->translate; }  "Translate ran";
ok $out ne ""                        ,"Produced something!";
warn $obj->error unless $out;

# Normal output looks ok
local $/ = undef; # slurp
eq_or_diff $out, <DATA>              ,"Output looks right";

# File output
my @files = glob("$tdir/*.txt");
ok( @files == 2, "Wrote 2 files." );
is( $files[0], "$tdir/person.txt" , "Wrote person.txt" );
is( $files[1], "$tdir/pet.txt"    , "Wrote pet.txt" );

open(FILE, "$tdir/person.txt") || die "Couldn't open $tdir/person.txt : $!";
eq_or_diff <FILE>, qq{Table: person
  Primary Key:  person_id
  Foreign Keys: 
  Data Fields:  name, age, weight, iq, description

}
, "person.txt looks right";
close(FILE);

open(FILE, "$tdir/pet.txt") || die "Couldn't open $tdir/pet.txt : $!";
eq_or_diff <FILE>, qq{Table: pet
  Primary Key:  pet_id, person_id
  Foreign Keys: 
  Data Fields:  name, age

}
, "pet.txt looks right";
close(FILE);


print $out if DEBUG;
#print "Debug:", Dumper($obj) if DEBUG;

__DATA__
Table: person
  Primary Key:  person_id
  Foreign Keys: 
  Data Fields:  name, age, weight, iq, description

Table: pet
  Primary Key:  pet_id, person_id
  Foreign Keys: 
  Data Fields:  name, age

