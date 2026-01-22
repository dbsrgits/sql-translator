#!perl

use strict;
use warnings;
use English '-no_match_vars';

use Test::More;
use Test::Exception;
use SQL::Translator;
use SQL::Translator::Schema::Constants;
use Test::SQL::Translator qw(maybe_plan);

BEGIN {
  $SQL::Translator::DEBUG = 1;
  maybe_plan(undef, 'SQL::Translator::Parser::PostgreSQL');
  SQL::Translator::Parser::PostgreSQL->import('parse');
}

my $t = SQL::Translator->new(trace => 0);

    # CREATE SEQUENCE "master" INCREMENT BY 1 MINVALUE 1 MAXVALUE 5 START WITH 1 CACHE 3 CYCLE OWNED BY NONE;
    # CREATE SEQUENCE service;
    # COMMENT on SEQUENCE service IS 'Sequence
    # has comment on two lines';
    # CREATE TEMPORARY SEQUENCE foo.bar INCREMENT BY 2 NO MINVALUE NO MAXVALUE NO CYCLE OWNED BY foo.baz.qux;
    #
    # COMMENT on SEQUENCE foo.bar IS 'Sequence tied to column qux in table foo.baz';
subtest 'any SQL comment' => sub {
  my $seq_id = 'non.existing';
  my $sql = << "EOF";
  --COMMENT ON SEQUENCE $seq_id 'Some comment. This fails.';
EOF

  local $OUTPUT_AUTOFLUSH = 1;

  lives_ok { parse($t, $sql) } 'Lives okay';
  # TODO Fix parsing so that empty becomes possible
  done_testing;
};

subtest 'Failing comment' => sub {
  my $seq_id = 'non.existing';
  my $sql = << "EOF";
  -- fasd

  COMMENT ON SEQUENCE $seq_id 'Some comment. This fails.';
EOF

  local $OUTPUT_AUTOFLUSH = 1;

  dies_ok { parse($t, $sql) } 'Dies okay';
  # throws_ok { parse($t, $sql) } "No such sequence as '$seq_id'", 'Throws right error';
  # ATTN Parsing errors are swallowed. This requires major change.
  # ok( 1, 'We are okay' );
  done_testing;
};

done_testing;
