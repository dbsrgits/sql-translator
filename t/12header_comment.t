#!/usr/bin/perl
# vim: set ft=perl:

use Test::More;
use SQL::Translator::Utils qw($DEFAULT_COMMENT header_comment);

plan tests => 5;

# Superfluous test, but that's ok
use_ok("SQL::Translator::Utils");

is($DEFAULT_COMMENT, '-- ', 'default comment');
like(header_comment("foo"), qr/[-][-] Created by foo/, "Created by...");

my $comm = header_comment("My::Producer",
                          $DEFAULT_COMMENT,
                          "Hi mom!");
like($comm, qr/[-][-] Created by My::Producer/, 'Multiline header comment...');
like($comm, qr/[-][-] Hi mom!/, '...with additional junk');
