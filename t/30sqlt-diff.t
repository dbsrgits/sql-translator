#!/usr/bin/perl
# vim: set ft=perl:

use strict;

use File::Spec::Functions qw(catfile updir tmpdir);
use FindBin qw($Bin);
use Test::More;

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

plan tests => 2;

ok(-e $sqlt_diff); 
my @cmd = ($sqlt_diff, "$create1=SQLite", "$create2=SQLite");

close STDERR;
my $out = `@cmd`;

like($out, qr/ is missing field/, "Detected missing field 'lemon'");
