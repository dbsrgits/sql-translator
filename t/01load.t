#!/usr/bin/perl
# vim: set ft=perl:
#
# This test attempts to load every .pm file in MANIFEST.
# It might be naive.
#

my @perlmods;
my $count = 0;

unless (open MANIFH, "MANIFEST") {
    print "1..1\n";
    print "not ok 1\n";
    exit;
}
while (<MANIFH>) {
    chomp;
    if (s/\.pm$//) {
        s,/,::,g;
        s/^lib:://;
        push @perlmods, $_
    }
}

print "1.." . scalar @perlmods . "\n";

close MANIFH;

for my $mod (@perlmods) {
    $count++;
    $mod =~ s,/,::,g;
    eval "use $mod;";
    print "not " if ($@);
    print "ok $count # $mod\n";
}

