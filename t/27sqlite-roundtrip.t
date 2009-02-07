#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use Test::SQL::Translator qw(maybe_plan);
use FindBin qw/$Bin/;

use SQL::Translator;
use SQL::Translator::Schema::Constants;

BEGIN {
    maybe_plan(7,
        'SQL::Translator::Parser::SQLite',
        'SQL::Translator::Producer::SQLite',
    );
}

my $file = "$Bin/data/sqlite/create.sql";

{
    #local $/;
    #open my $fh, "<$file" or die "Can't read file '$file': $!\n";
    #my $data = <$fh>;

    my $t = SQL::Translator->new;

    my $schema1 = $t->translate (
        parser => 'SQLite',
        file => $file,
        debug => 1
    ) or die $t->error;
    isa_ok ($schema1, 'SQL::Translator::Schema', 'First parser pass produced a schema');


    my $data2 = $t->translate (
        data => $schema1,
        producer => 'SQLite',
    ) or die $t->error;
    like ($data2, qr/BEGIN.+COMMIT/is, 'Received some meaningful output from the producer');

    # get a new translator
    $t = SQL::Translator->new;

    my $schema2 = $t->translate (
        parser => 'SQLite',
        data => \$data2,
    ) or die $t->error;
    isa_ok ($schema2, 'SQL::Translator::Schema', 'Second parser pass produced a schema');

    my @t1 = $schema1->get_tables;
    my @t2 = $schema2->get_tables;

    my @v1 = $schema1->get_views;
    my @v2 = $schema2->get_views;

    my @g1 = $schema1->get_triggers;
    my @g2 = $schema2->get_triggers;

    is (@t2, @t1, 'Equal amount of tables');

    is_deeply (
        [ map { $_->name } (@t1) ],
        [ map { $_->name } (@t2) ],
        'Table names match',
    );

    is (@v2, @v1, 'Equal amount of views');

    is (@g2, @g1, 'Equal amount of triggers');
}
