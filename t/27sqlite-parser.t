#!/usr/bin/perl
# vim: set ft=perl:

use strict;

use Test::More 'no_plan'; #tests => 180;
use SQL::Translator;
use SQL::Translator::Parser::SQLite qw(parse);
use SQL::Translator::Schema::Constants;

{
    my $t = SQL::Translator->new;
}
