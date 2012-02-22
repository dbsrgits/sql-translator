#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;
use Test::Exception;
use Test::Differences;
use SQL::Translator;
use SQL::Translator::Parser::SQLite;
use SQL::Translator::Diff;

my $ddl = <<DDL;
CREATE TABLE "Foo" (
  "foo" INTEGER PRIMARY KEY NOT NULL,
  "bar" VARCHAR(10) NOT NULL,
  "biff" VARCHAR(10)
);
DDL

my %common_args = (
  no_comments => 1,
  from => 'SQLite',
  to => 'SQLite');

my $unquoted = SQL::Translator
  ->new(%common_args)
  ->translate(\$ddl);

eq_or_diff($unquoted, <<'DDL', 'DDL with default quoting');
BEGIN TRANSACTION;

CREATE TABLE Foo (
  foo INTEGER PRIMARY KEY NOT NULL,
  bar VARCHAR(10) NOT NULL,
  biff VARCHAR(10)
);

COMMIT;
DDL

dies_ok { SQL::Translator
  ->new(%common_args, quote_table_names=>0, quote_field_names => 1)
  ->translate(\$ddl) } 'mix and match quotes is asinine';

my $quoteall = SQL::Translator
  ->new(%common_args, quote_identifiers=>1)
  ->translate(\$ddl);

eq_or_diff($quoteall, <<'DDL', 'DDL with quoting');
BEGIN TRANSACTION;

CREATE TABLE "Foo" (
  "foo" INTEGER PRIMARY KEY NOT NULL,
  "bar" VARCHAR(10) NOT NULL,
  "biff" VARCHAR(10)
);

COMMIT;
DDL

=begin FOR TODO

# FIGURE OUT HOW TO DO QUOTED DIFFS EVEN WHEN QUOTING IS DEFAULT OFF
#

eq_or_diff($upgrade_sql, <<'## END OF DIFF', "Diff as expected");
-- Convert schema '' to '':;

BEGIN;

CREATE TEMPORARY TABLE "Foo_temp_alter" (
  "foo" INTEGER PRIMARY KEY NOT NULL,
  "bar" VARCHAR(10) NOT NULL,
  "baz" VARCHAR(10),
  "doomed" VARCHAR(10)
);

INSERT INTO "Foo_temp_alter"( "foo", "bar") SELECT "foo", "bar" FROM "Foo";

DROP TABLE "Foo";

CREATE TABLE "Foo" (
  "foo" INTEGER PRIMARY KEY NOT NULL,
  "bar" VARCHAR(10) NOT NULL,
  "baz" VARCHAR(10),
  "doomed" VARCHAR(10)
);

INSERT INTO "Foo" SELECT "foo", "bar", "baz", "doomed" FROM "Foo_temp_alter";

DROP TABLE "Foo_temp_alter";


COMMIT;

## END OF DIFF

=cut


