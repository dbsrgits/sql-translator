#!/usr/bin/perl
# vim: set ft=perl:

use strict;

use File::Spec::Functions qw(catfile updir tmpdir);
use FindBin qw($Bin);
use Test::More;
use Test::SQL::Translator qw(maybe_plan);

my @script = qw(blib script sqlt-diff);
my @create1 = qw(data sqlite create.sql);
my @create2 = qw(data sqlite create2.sql);

my $sqlt_diff = (-d "blib")
    ? catfile($Bin, updir, @script)
    : catfile($Bin, @script);

my $create1 = (-d "t")
    ? catfile($Bin, @create1)
    : catfile($Bin, "t", @create1);

my $create2 = (-d "t")
    ? catfile($Bin, @create2)
    : catfile($Bin, "t", @create2);

BEGIN {
    maybe_plan(16,
        'SQL::Translator::Parser::SQLite',
        'SQL::Translator::Parser::MySQL',
        'SQL::Translator::Parser::Oracle',
        );
}

ok(-e $sqlt_diff, 'Found sqlt-diff script'); 
my @cmd = ($sqlt_diff, "$create1=SQLite", "$create2=SQLite");

my $out = `@cmd`;

like($out, qr/ALTER TABLE person CHANGE iq/, "Detected altered 'iq' field");
like($out, qr/ALTER TABLE person ADD is_rock_star/, 
    "Detected missing rock star field");
    
@cmd = ($sqlt_diff, "$create1=SQLite", "$create1=SQLite");
$out = `@cmd`;

like($out, qr/No differences found/, "Properly detected no differences");

my @mysql_create1 = qw(data mysql create.sql);
my @mysql_create2 = qw(data mysql create2.sql);

my $mysql_create1 = (-d "t")
    ? catfile($Bin, @mysql_create1)
    : catfile($Bin, "t", @mysql_create1);

my $mysql_create2 = (-d "t")
    ? catfile($Bin, @mysql_create2)
    : catfile($Bin, "t", @mysql_create2);

@cmd = ($sqlt_diff, "$mysql_create1=MySQL", "$mysql_create2=MySQL");
$out = `@cmd`;

like($out, qr/ALTER TABLE person CHANGE person_id/, "Detected altered 'person_id' field");
like($out, qr/ALTER TABLE person CHANGE iq/, "Detected altered 'iq' field");
like($out, qr/ALTER TABLE person CHANGE name/, "Detected altered 'name' field");
like($out, qr/ALTER TABLE person CHANGE age/, "Detected altered 'age' field");
like($out, qr/ALTER TABLE person ADD is_rock_star/, 
    "Detected missing rock star field");
like($out, qr/ALTER TABLE person ADD UNIQUE UC_person_id/, 
    "Detected missing unique constraint");
like($out, qr/ALTER TABLE person ENGINE=InnoDB;/, 
    "Detected altered table option");
like($out, qr/ALTER TABLE employee DROP FOREIGN KEY/, 
    "Detected drop foreign key");
like($out, qr/ALTER TABLE employee ADD CONSTRAINT/, 
    "Detected add constraint");
    
@cmd = ($sqlt_diff, "$mysql_create1=MySQL", "$mysql_create1=MySQL");
$out = `@cmd`;

like($out, qr/No differences found/, "Properly detected no differences");

my @oracle_create1 = qw(data oracle create.sql);
my @oracle_create2 = qw(data oracle create2.sql);

my $oracle_create1 = (-d "t")
    ? catfile($Bin, @oracle_create1)
    : catfile($Bin, "t", @oracle_create1);

my $oracle_create2 = (-d "t")
    ? catfile($Bin, @oracle_create2)
    : catfile($Bin, "t", @oracle_create2);

@cmd = ($sqlt_diff, "$oracle_create1=Oracle", "$oracle_create2=Oracle");
$out = `@cmd`;

like($out, qr/ALTER TABLE TABLE1 DROP FOREIGN KEY/, 
    "Detected drop foreign key");
like($out, qr/ALTER TABLE TABLE1 ADD CONSTRAINT/, 
    "Detected add constraint");
