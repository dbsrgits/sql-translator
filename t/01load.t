#!/usr/bin/perl
# vim: set ft=perl:
#
# This test attempts to load every .pm file in MANIFEST.
# It might be naive.
#

my @perlmods;

use Test::More;
use SQL::Translator;

unless (open MANIFH, "MANIFEST") {
    plan skip_all => "Can't open MANIFEST! ($!)";
    exit;
}

while (<MANIFH>) {
    chomp;
    if (s,^lib/,, && s/\.pm$//) {
        s,/,::,g;
        push @perlmods, $_
    }
}

close MANIFH;

@perlmods = sort @perlmods; # aesthetics
plan tests => scalar @perlmods;

for my $mod (@perlmods) {
    use_ok($mod);
}

