#!/usr/bin/perl
use strict;

use FindBin qw/$Bin/;
use Test::More;
use Test::SQL::Translator;
use Test::Exception;
use Test::Differences;
use Data::Dumper;
use SQL::Translator;
use SQL::Translator::Schema::Constants;


BEGIN {
    maybe_plan(2, 'SQL::Translator::Parser::XML::SQLFairy',
              'SQL::Translator::Producer::SQLite');
}

my $xmlfile = "$Bin/data/xml/schema.xml";

my $sqlt;
$sqlt = SQL::Translator->new(
    no_comments => 1,
    show_warnings  => 0,
    add_drop_table => 1,
);

die "Can't find test schema $xmlfile" unless -e $xmlfile;

my $sql = $sqlt->translate(
    from     => 'XML-SQLFairy',
    to       => 'SQLite',
    filename => $xmlfile,
) or die $sqlt->error;

eq_or_diff($sql, << "SQL");
BEGIN TRANSACTION;

DROP TABLE Basic;

CREATE TABLE Basic (
  id INTEGER PRIMARY KEY NOT NULL,
  title varchar(100) NOT NULL DEFAULT 'hello',
  description text DEFAULT '',
  email varchar(500),
  explicitnulldef varchar,
  explicitemptystring varchar DEFAULT '',
  -- Hello emptytagdef
  emptytagdef varchar DEFAULT '',
  another_id int(10) DEFAULT 2,
  timest timestamp
);

CREATE INDEX titleindex ON Basic (title);

CREATE UNIQUE INDEX emailuniqueindex ON Basic (email);

CREATE UNIQUE INDEX very_long_index_name_on_title_field_which_should_be_truncated_for_various_rdbms ON Basic (title);

DROP TABLE Another;

CREATE TABLE Another (
  id INTEGER PRIMARY KEY NOT NULL,
  num numeric(10,2)
);

DROP VIEW IF EXISTS email_list;

CREATE VIEW email_list AS
    SELECT email FROM Basic WHERE (email IS NOT NULL);

DROP TRIGGER IF EXISTS foo_trigger;

CREATE TRIGGER foo_trigger after insert on Basic BEGIN update modified=timestamp(); END;

DROP TRIGGER IF EXISTS bar_trigger_insert;

CREATE TRIGGER bar_trigger_insert before insert on Basic BEGIN update modified2=timestamp(); END;

DROP TRIGGER IF EXISTS bar_trigger_update;

CREATE TRIGGER bar_trigger_update before update on Basic BEGIN update modified2=timestamp(); END;

COMMIT;
SQL

# Test in list context
my @sql = $sqlt->translate(
    from     => 'XML-SQLFairy',
    to       => 'SQLite',
    filename => $xmlfile,
) or die $sqlt->error;

eq_or_diff(\@sql, 
          [
          'BEGIN TRANSACTION',
          'DROP TABLE Basic',
          'CREATE TABLE Basic (
  id INTEGER PRIMARY KEY NOT NULL,
  title varchar(100) NOT NULL DEFAULT \'hello\',
  description text DEFAULT \'\',
  email varchar(500),
  explicitnulldef varchar,
  explicitemptystring varchar DEFAULT \'\',
  -- Hello emptytagdef
  emptytagdef varchar DEFAULT \'\',
  another_id int(10) DEFAULT 2,
  timest timestamp
)',
          'CREATE INDEX titleindex ON Basic (title)',
          'CREATE UNIQUE INDEX emailuniqueindex ON Basic (email)',
          'CREATE UNIQUE INDEX very_long_index_name_on_title_field_which_should_be_truncated_for_various_rdbms ON Basic (title)',
          'DROP TABLE Another',
          'CREATE TABLE Another (
  id INTEGER PRIMARY KEY NOT NULL,
  num numeric(10,2)
)',
          'DROP VIEW IF EXISTS email_list',
          'CREATE VIEW email_list AS
    SELECT email FROM Basic WHERE (email IS NOT NULL)',
          'DROP TRIGGER IF EXISTS foo_trigger',
          'CREATE TRIGGER foo_trigger after insert on Basic BEGIN update modified=timestamp(); END',
          'DROP TRIGGER IF EXISTS bar_trigger_insert',
          'CREATE TRIGGER bar_trigger_insert before insert on Basic BEGIN update modified2=timestamp(); END',
          'DROP TRIGGER IF EXISTS bar_trigger_update',
          'CREATE TRIGGER bar_trigger_update before update on Basic BEGIN update modified2=timestamp(); END',
          'COMMIT',

          ], 'SQLite translate in list context matches');


