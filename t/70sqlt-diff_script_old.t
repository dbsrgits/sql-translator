#!/usr/bin/perl
# vim: set ft=perl:

use strict;

use File::Spec::Functions qw(catfile updir tmpdir);
use FindBin               qw($Bin);
use Test::More;
use IPC::Open3;
use Test::SQL::Translator qw(maybe_plan);
use Text::ParseWords      qw(shellwords);

my @script  = qw(script sqlt-diff-old);
my @create1 = qw(data sqlite create.sql);
my @create2 = qw(data sqlite create2.sql);

my $sqlt_diff = catfile($Bin, updir, @script);
my $create1   = catfile($Bin, @create1);
my $create2   = catfile($Bin, @create2);

BEGIN {
  maybe_plan(
    21,
    'SQL::Translator::Parser::SQLite',
    'SQL::Translator::Parser::MySQL',
    'SQL::Translator::Parser::Oracle',
  );
}

ok(-e $sqlt_diff, 'Found sqlt-diff script');
my $out = _run_cmd($sqlt_diff, "$create1=SQLite", "$create2=SQLite");

like($out, qr/-- Target database SQLite is untested/, "Detected 'untested' comment");
like($out, qr/ALTER TABLE person CHANGE iq/,          "Detected altered 'iq' field");
like($out, qr/ALTER TABLE person ADD is_rock_star/,   "Detected missing rock star field");

$out = _run_cmd($sqlt_diff, "$create1=SQLite", "$create1=SQLite");

like($out, qr/There were no differences/, "Properly detected no differences");

my @mysql_create1 = qw(data mysql create.sql);
my @mysql_create2 = qw(data mysql create2.sql);

my $mysql_create1
    = (-d "t")
    ? catfile($Bin, @mysql_create1)
    : catfile($Bin, "t", @mysql_create1);

my $mysql_create2
    = (-d "t")
    ? catfile($Bin, @mysql_create2)
    : catfile($Bin, "t", @mysql_create2);

# Test for differences
$out = _run_cmd($sqlt_diff, "$mysql_create1=MySQL", "$mysql_create2=MySQL");

unlike($out, qr/-- Target database MySQL is untested/, "Did not detect 'untested' comment");
like($out, qr/ALTER TABLE person CHANGE person_id/,                      "Detected altered 'person_id' field");
like($out, qr/ALTER TABLE person CHANGE iq/,                             "Detected altered 'iq' field");
like($out, qr/ALTER TABLE person CHANGE name/,                           "Detected altered 'name' field");
like($out, qr/ALTER TABLE person CHANGE age/,                            "Detected altered 'age' field");
like($out, qr/ALTER TABLE person ADD is_rock_star/,                      "Detected missing rock star field");
like($out, qr/ALTER TABLE person ADD UNIQUE UC_person_id/,               "Detected missing unique constraint");
like($out, qr/CREATE UNIQUE INDEX unique_name/,                          "Detected unique index with different name");
like($out, qr/ALTER TABLE person ENGINE=InnoDB;/,                        "Detected altered table option");
like($out, qr/ALTER TABLE employee DROP FOREIGN KEY FK5302D47D93FE702E/, "Detected drop foreign key");
like($out, qr/ALTER TABLE employee ADD CONSTRAINT FK5302D47D93FE702E_diff/, "Detected add constraint");
unlike($out, qr/ALTER TABLE employee ADD PRIMARY KEY/, "Primary key looks different when it shouldn't");

# Test for sameness
$out = _run_cmd($sqlt_diff, "$mysql_create1=MySQL", "$mysql_create1=MySQL");

like($out, qr/There were no differences/, "Properly detected no differences");

my @oracle_create1 = qw(data oracle create.sql);
my @oracle_create2 = qw(data oracle create2.sql);

my $oracle_create1
    = (-d "t")
    ? catfile($Bin, @oracle_create1)
    : catfile($Bin, "t", @oracle_create1);

my $oracle_create2
    = (-d "t")
    ? catfile($Bin, @oracle_create2)
    : catfile($Bin, "t", @oracle_create2);

$out = _run_cmd($sqlt_diff, "$oracle_create1=Oracle", "$oracle_create2=Oracle");

unlike($out, qr/-- Target database Oracle is untested/, "Did not detect 'untested' comment");
like($out, qr/ALTER TABLE TABLE1 DROP FOREIGN KEY/, "Detected drop foreign key");
like($out, qr/ALTER TABLE TABLE1 ADD CONSTRAINT/,   "Detected add constraint");

sub _run_cmd {
  my $out;
  my $pid = open3(undef, $out, undef, $^X, shellwords($ENV{HARNESS_PERL_SWITCHES} || ''), @_);
  my $res = do { local $/; <$out> };
  waitpid($pid, 0);
  $res;
}
