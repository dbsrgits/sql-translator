#!/usr/bin/perl
# vim: set ft=perl:
#

use strict;
use FindBin qw/$Bin/;
use Test::More;
use SQL::Translator;
use Test::SQL::Translator qw(maybe_plan);

BEGIN {
    maybe_plan(
        1, 
        'SQL::Translator::Parser::SQLite',
        'SQL::Translator::Producer::Dumper'
    );
}

my $file            = "$Bin/data/sqlite/create.sql";
my $t               = SQL::Translator->new(
    from            => 'SQLite',
    to              => 'Dumper',
    producer_args   => {
        skip        => $skip,
        skiplike    => $skiplike,
        db_user     => $db_user,
        db_password => $db_pass,
        dsn         => $dsn,
    }
);

my $output = $t->translate( $file );
