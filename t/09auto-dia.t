#!/usr/bin/perl
# vim: set ft=perl:

use strict;

use File::Spec::Functions qw(catfile updir tmpdir);
use File::Temp qw(tempfile);
use FindBin qw($Bin);
use Test;

my @script = qw(blib script auto-dia.pl);
my @data = qw(data mysql Apache-Session-MySQL.sql);

my $auto_dia = (-d "blib")
    ? catfile($Bin, updir, @script)
    : catfile($Bin, @script);

my $test_data = (-d "t")
    ? catfile($Bin, @data)
    : catfile($Bin, "t", @data);

my (undef, $tmp) = tempfile("sqlXXXXX",
                             OPEN   => 0,
                             UNLINK => 1,
                             SUFFIX => '.png',
                             DIR    => tmpdir);

BEGIN {
    plan tests => 3;
}

ok(-e $auto_dia); 
eval { require GD; };
if ($@ && $@ =~ /locate GD.pm in /) {
    skip($@, "GD not installed");
    skip($@, "GD not installed");
} else {
    my @cmd = ($auto_dia, "-d", "MySQL", "-o", $tmp, $test_data);
    eval { system(@cmd); };
    ok(!$@ && ($? == 0));
    ok(-e $tmp); 
}
