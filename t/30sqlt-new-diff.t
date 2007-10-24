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
    maybe_plan(16,        'SQL::Translator::Parser::MySQL',
        );
}

ok(-e $sqlt_diff, 'Found sqlt-diff script'); 

my @mysql_create1 = qw(data mysql create.sql);
my @mysql_create2 = qw(data mysql create2.sql);

my $mysql_create1 = (-d "t")
    ? catfile($Bin, @mysql_create1)
    : catfile($Bin, "t", @mysql_create1);

my $mysql_create2 = (-d "t")
    ? catfile($Bin, @mysql_create2)
    : catfile($Bin, "t", @mysql_create2);

# Test for differences
my @cmd = ($sqlt_diff, "$mysql_create1=MySQL", "$mysql_create2=MySQL");
my $out = `@cmd`;

unlike($out, qr/-- Target database MySQL is untested/, "Did not detect 'untested' comment");
like($out, qr/ALTER TABLE person CHANGE COLUMN person_id/, "Detected altered 'person_id' field");
like($out, qr/ALTER TABLE person CHANGE COLUMN iq/, "Detected altered 'iq' field");
like($out, qr/ALTER TABLE person CHANGE COLUMN name/, "Detected altered 'name' field");
like($out, qr/ALTER TABLE person CHANGE COLUMN age/, "Detected altered 'age' field");
like($out, qr/ALTER TABLE person ADD COLUMN is_rock_star/, 
    "Detected missing rock star field");
like($out, qr/ALTER TABLE person ADD UNIQUE UC_person_id/, 
    "Detected missing unique constraint");
like($out, qr/ALTER TABLE person ADD UNIQUE INDEX unique_name/, 
    "Detected unique index with different name");
like($out, qr/ALTER TABLE person ENGINE=InnoDB;/, 
    "Detected altered table option");
like($out, qr/ALTER TABLE employee DROP FOREIGN KEY FK5302D47D93FE702E/, 
    "Detected drop foreign key");
like($out, qr/ALTER TABLE employee ADD CONSTRAINT FK5302D47D93FE702E_diff/, 
    "Detected add constraint");
unlike($out, qr/ALTER TABLE employee ADD PRIMARY KEY/, "Primary key looks different when it shouldn't");

# Test ignore parameters
@cmd = ($sqlt_diff, "--ignore-index-names", "--ignore-constraint-names",
    "$mysql_create1=MySQL", "$mysql_create2=MySQL");
$out = `@cmd`;

unlike($out, qr/CREATE UNIQUE INDEX unique_name/, 
    "Detected unique index with different name");
unlike($out, qr/ALTER TABLE employee ADD CONSTRAINT employee_FK5302D47D93FE702E_diff/, 
    "Detected add constraint");

# Test for sameness
@cmd = ($sqlt_diff, "$mysql_create1=MySQL", "$mysql_create1=MySQL");
$out = `@cmd`;

like($out, qr/No differences found/, "Properly detected no differences");

