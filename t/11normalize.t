#!/usr/bin/perl
# vim: set ft=perl:

use strict;
use Test::More;
use SQL::Translator::Utils qw(normalize_name);

my %tests = (
    "silly field (with random characters)" => "silly_field_with_random_characters",
    "444"   => "_444",
    "hello, world" => "hello_world",
    "- 9s80     qwehjf 4r" => "_9s80_qwehjf_4r",
);

plan tests => scalar(keys %tests) + 1;

# Superfluous test, but that's ok
use_ok("SQL::Translator::Utils");

for my $test (keys %tests) {
    is(normalize_name($test) => $tests{$test},
        "normalize_name('$test') => '$tests{$test}'");
}
