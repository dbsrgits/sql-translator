#!perl

use strict;
use warnings;
use English '-no_match_vars';

use Test::More;
use SQL::Translator;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Parser::PostgreSQL ();
use Test::SQL::Translator qw(maybe_plan);

BEGIN {
  maybe_plan(undef, 'SQL::Translator::Parser::PostgreSQL');
  SQL::Translator::Parser::PostgreSQL->import('parse');
}

# $::RD_ERRORS = 1; #Parser dies when it encounters an error
# $::RD_WARN   = 1; #Enable warnings - warn on unused rules &c.
# $::RD_HINT   = 1; #Give out hints to help fix problems.
# $::RD_TRACE = 1; #Trace parsers' behaviour

my $t = SQL::Translator->new(trace => 0);

    # CREATE SEQUENCE "master" INCREMENT BY 1 MINVALUE 1 MAXVALUE 5 START WITH 1 CACHE 3 CYCLE OWNED BY NONE;
    # CREATE SEQUENCE service;
    # COMMENT on SEQUENCE service IS 'Sequence
    # has comment on two lines';
    # CREATE TEMPORARY SEQUENCE foo.bar INCREMENT BY 2 NO MINVALUE NO MAXVALUE NO CYCLE OWNED BY foo.baz.qux;
    #
    # COMMENT on SEQUENCE foo.bar IS 'Sequence tied to column qux in table foo.baz';
    #
    # COMMENT ON SEQUENCE master 'This becomes the second comment!';
    # create temporary sequence service1 owned by none;


my $sql = << 'EOF';
    -- Minimal configuration
    CREATE SEQUENCE master;

    create
    sequence
    service1;
    COMMENT
    ON
    SEQUENCE
    service1
    IS
    'This becomes the first comment!'
    ;

    -- Now for a temporary sequence
    CREATE TEMP SEQUENCE service2;
    comment on sequence service2 is 'This becomes the second comment!';

    CREATE UNLOGGED SEQUENCE service3;

    -- Attn. data type is "smallint", i.e. integer size 5!
    CREATE SEQUENCE service4 AS smallint;

    -- Not so orphaned comment.

    CREATE temporary sequence IF NOT EXISTS
    service5 ;

    -- Table required to test OWNED BY (connect to table).
    CREATE TABLE server(id INTEGER, name TEXT);

    -- Many options
    CREATE SEQUENCE service6 AS integer INCREMENT BY 5 MINVALUE 10 NO MAXVALUE START 225 CACHE 20 NO CYCLE OWNED BY server.id;

    CREATE SEQUENCE service7 OWNED BY "db"."public"."server"."id";

    CREATE SEQUENCE IF NOT EXISTS "seq_master" INCREMENT BY 1 MINVALUE 1 NO MAXVALUE START WITH 2 CACHE 1 NO CYCLE;
    COMMENT ON SEQUENCE "seq_master" IS 'Every operation has a unique sequence. For master data tables (permanent data). Becomes version in history tables.';
EOF

local $OUTPUT_AUTOFLUSH = 1;
my $data   = parse($t, $sql);
my $schema = $t->schema;
isa_ok($schema, 'SQL::Translator::Schema', 'Schema object');
# Sequences
#
my @seqs = $schema->get_sequences;
# is(scalar @sequences, 3, 'Three sequences');
# my ($s1, $s2, $s3) = @seqs;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
# diag 'got sequences: ' . Dumper( \@seqs );

my $seq0 = SQL::Translator::Parser::PostgreSQL->create_sequence(
  name => 'master', order => 1,
  temporary => 0, unlogged => 0, increment => 1, minvalue => 1, owner => 'NONE',
  comments => [ q{Minimal configuration}, ],
);
# diag '$seqs[0]:' . Dumper($seqs[0]->data);
# diag '$seq0:' . Dumper($seq0->data);
ok( $seq0->equals( $seqs[0] ), '$seqs[0] has correct values', );

my $seq1 = SQL::Translator::Parser::PostgreSQL->create_sequence(
  name => 'service1', order => 2,
  temporary => 0, unlogged => 0, increment => 1, minvalue => 1, owner => 'NONE',
  comments => [ 'This becomes the first comment!' ],
);
# diag '$seqs[1]:' . Dumper($seqs[1]->data);
# diag '$seq1:' . Dumper($seq1->data);
ok( $seq1->equals( $seqs[1] ), '$seqs[1] has correct values', );

my $seq2 = SQL::Translator::Parser::PostgreSQL->create_sequence(
  name => 'service2', order => 3,
  temporary => 1, unlogged => 0, increment => 1, minvalue => 1, owner => 'NONE',
  comments => [ 'Now for a temporary sequence', 'This becomes the second comment!' ],
);
# diag '$seqs[2]:' . Dumper($seqs[2]->data);
# diag '$seq2:' . Dumper($seq2->data);
ok( $seq2->equals( $seqs[2] ), '$seqs[2] has correct values', );

my $seq3 = SQL::Translator::Parser::PostgreSQL->create_sequence(
  name => 'service3', order => 4,
  temporary => 0, unlogged => 1, increment => 1, minvalue => 1, owner => 'NONE',
  comments => [ ],
);
# diag '$seqs[3]:' . Dumper($seqs[3]->data);
# diag '$seq3:' . Dumper($seq3->data);
ok( $seq3->equals( $seqs[3] ), '$seqs[3] has correct values', );

my $seq4 = SQL::Translator::Parser::PostgreSQL->create_sequence(
  name => 'service4', order => 5,
  data_type => SQL::Translator::Schema::DataType->new(type => 'integer', size => 5),
  temporary => 0, unlogged => 0,
  comments => [ 'Attn. data type is "smallint", i.e. integer size 5!' ],
);
# diag '$seqs[4]:' . Dumper($seqs[4]->data);
# diag '$seq4:' . Dumper($seq4->data);
ok( $seq4->equals( $seqs[4] ), '$seqs[4] has correct values', );

# IF NOT EXISTS is not a "feature" of sequence,
# but a feature of the creating of a sequence.
my $seq5 = SQL::Translator::Parser::PostgreSQL->create_sequence(
  name => 'service5', order => 6,
  temporary => 1,
  comments => [ 'Not so orphaned comment.' ],
);
# diag '$seqs[5]:' . Dumper($seqs[5]->data);
# diag '$seq5:' . Dumper($seq5->data);
ok( $seq5->equals( $seqs[5] ), '$seqs[5] has correct values', );

my $seq6 = SQL::Translator::Parser::PostgreSQL->create_sequence(
  name => 'service6', order => 7,
  data_type => SQL::Translator::Schema::DataType->new(type => 'integer', size => 10 ),
  increment => 5, minvalue => 10, start => 225, cache => 20, cycle => 0,
  owner => q{server.id},
  comments => [ 'Many options' ],
);
# diag '$seqs[6]:' . Dumper($seqs[6]->data);
# diag '$seq6:' . Dumper($seq6->data);
ok( $seq6->equals( $seqs[6] ), '$seqs[6] has correct values', );

my $seq7 = SQL::Translator::Parser::PostgreSQL->create_sequence(
  name => 'service7', order => 8,
  data_type => SQL::Translator::Schema::DataType->new(type => 'integer', size => 20 ),
  owner => q{db.public.server.id},
  comments => [ ],
);
# diag '$seqs[7]:' . Dumper($seqs[7]->data);
# diag '$seq7:' . Dumper($seq7->data);
ok( $seq7->equals( $seqs[7] ), '$seqs[7] has correct values', );

my $seq8 = SQL::Translator::Parser::PostgreSQL->create_sequence(
  name => 'seq_master', order => 9,
  data_type => SQL::Translator::Schema::DataType->new(type => 'integer', size => 20 ),
  increment => 1, minvalue => 1, maxvalue => 0, start => 2, cache => 1, cycle => 0,
  owner => q{NONE},
  comments => [ 'Every operation has a unique sequence. For master data tables (permanent data). Becomes version in history tables.' ],
);
# diag '$seqs[8]:' . Dumper($seqs[8]->data);
# diag '$seq8:' . Dumper($seq8->data);
ok( $seq8->equals( $seqs[8] ), '$seqs[7] has correct values', );

done_testing;
