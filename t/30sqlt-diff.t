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
    maybe_plan(3,
        'SQL::Translator::Parser::SQLite',
        'SQL::Translator::Producer::YAML',
        );
}

ok(-e $sqlt_diff, 'Found sqlt-diff script'); 
my @cmd = ($sqlt_diff, "$create1=SQLite", "$create2=SQLite");

my $out = `@cmd`;

like($out, qr/ALTER TABLE person CHANGE iq/, "Detected altered 'iq' field");
like($out, qr/ALTER TABLE person ADD is_rock_star/, 
    "Detected missing rock star field");
