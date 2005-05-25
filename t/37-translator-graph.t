#!/usr/bin/perl
# vim: set ft=perl:

use strict;

use Test::More;
use SQL::Translator;
use SQL::Translator::Schema::Constants;
use Test::SQL::Translator qw(maybe_plan);

BEGIN {
    maybe_plan(3, "SQL::Translator");
}

{
    my $tr = SQL::Translator->new(
        parser   => "PostgreSQL",
    );

    ok( $tr->translate('t/data/pgsql/turnkey.sql'), 'Translate PG' );
    ok( my $schema = $tr->schema, 'Got Schema' );
    ok( my $graph = $schema->as_graph, 'Graph made');
}
