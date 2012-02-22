#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use Test::Differences;
use SQL::Translator;
use SQL::Translator::Parser::SQLite;
use SQL::Translator::Diff;


ok my $version1 = SQL::Translator->new(from=>'SQLite')
  ->translate(\<<SQL);
CREATE TABLE "Foo" (
  "foo" INTEGER PRIMARY KEY NOT NULL,
  "bar" VARCHAR(10) NOT NULL,
  "biff" VARCHAR(10)
);
SQL

ok my $version2 = SQL::Translator->new(from=>'SQLite')
  ->translate(\<<SQL);
CREATE TABLE "Foo" (
  "foo" INTEGER PRIMARY KEY NOT NULL,
  "bar" VARCHAR(10) NOT NULL,
  "baz" VARCHAR(10),
  "doomed" VARCHAR(10)
);
SQL

ok my $upgrade_sql = SQL::Translator::Diff->new({
  output_db     => 'SQLite',
  source_schema => $version1,
  target_schema => $version2,
})->compute_differences->produce_diff_sql;

eq_or_diff($upgrade_sql, <<'## END OF DIFF', "Diff as expected");
-- Convert schema '' to '':;

BEGIN;

CREATE TEMPORARY TABLE Foo_temp_alter (
  foo INTEGER PRIMARY KEY NOT NULL,
  bar VARCHAR(10) NOT NULL,
  baz VARCHAR(10),
  doomed VARCHAR(10)
);

INSERT INTO Foo_temp_alter( foo, bar) SELECT foo, bar FROM Foo;

DROP TABLE Foo;

CREATE TABLE Foo (
  foo INTEGER PRIMARY KEY NOT NULL,
  bar VARCHAR(10) NOT NULL,
  baz VARCHAR(10),
  doomed VARCHAR(10)
);

INSERT INTO Foo SELECT foo, bar, baz, doomed FROM Foo_temp_alter;

DROP TABLE Foo_temp_alter;


COMMIT;

## END OF DIFF

