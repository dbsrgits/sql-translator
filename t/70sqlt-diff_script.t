#!/usr/bin/perl
# vim: set ft=perl:

use strict;

use File::Spec::Functions qw(catfile updir tmpdir);
use FindBin qw($Bin);
use IPC::Open3;
use Test::More;
use Test::SQL::Translator qw(maybe_plan);

my @script = qw(script sqlt-diff);
my @create1 = qw(data sqlite create.sql);
my @create2 = qw(data sqlite create2.sql);

my $sqlt_diff = catfile($Bin, updir, @script);
my $create1 = catfile($Bin, @create1);
my $create2 = catfile($Bin, @create2);

BEGIN {
    maybe_plan(16,
        'SQL::Translator::Parser::MySQL',
        );
}

$ENV{SQLT_NEWDIFF_NOWARN} = 1;

my @mysql_create1 = qw(data mysql create.sql);
my @mysql_create2 = qw(data mysql create2.sql);

my $mysql_create1 = (-d "t")
    ? catfile($Bin, @mysql_create1)
    : catfile($Bin, "t", @mysql_create1);

my $mysql_create2 = (-d "t")
    ? catfile($Bin, @mysql_create2)
    : catfile($Bin, "t", @mysql_create2);

# Test for differences
my $out = _run_cmd ($^X, $sqlt_diff, "$mysql_create1=MySQL", "$mysql_create2=MySQL");

like($out, qr/CHANGE COLUMN person_id/, "Detected altered 'person_id' field");
like($out, qr/CHANGE COLUMN iq/, "Detected altered 'iq' field");
like($out, qr/CHANGE COLUMN name/, "Detected altered 'name' field");
like($out, qr/CHANGE COLUMN age/, "Detected altered 'age' field");
like($out, qr/ADD COLUMN is_rock_star/,
    "Detected missing rock star field");
like($out, qr/ADD UNIQUE UC_person_id/,
    "Detected missing unique constraint");
like($out, qr/ADD UNIQUE INDEX unique_name/,
    "Detected unique index with different name");
like($out, qr/DROP FOREIGN KEY FK5302D47D93FE702E/,
    "Detected drop foreign key");
like($out, qr/ADD CONSTRAINT FK5302D47D93FE702E_diff/,
    "Detected add constraint");
unlike($out, qr/ADD PRIMARY KEY/, "Primary key looks different when it shouldn't");

# Test for quoted output
$out = _run_cmd ($^X, $sqlt_diff, '--quote=`', "$mysql_create1=MySQL", "$mysql_create2=MySQL");

like($out, qr/ALTER TABLE `person`/, "Quoted table name");
like($out, qr/CHANGE COLUMN `person_id`/, "Quoted 'person_id' field");
like($out, qr/CHANGE COLUMN `iq`/, "Quoted 'iq' field");
like($out, qr/CHANGE COLUMN `name`/, "Quoted 'name' field");
like($out, qr/CHANGE COLUMN `age`/, "Quoted 'age' field");

# Test for sameness
$out = _run_cmd ($^X, $sqlt_diff, "$mysql_create1=MySQL", "$mysql_create1=MySQL");

like($out, qr/No differences found/, "Properly detected no differences");

sub _run_cmd {
  my $out;
  my $pid = open3( undef, $out, undef, @_ );
  my $res = do { local $/; <$out> };
  waitpid($pid, 0);
  $res;
}
