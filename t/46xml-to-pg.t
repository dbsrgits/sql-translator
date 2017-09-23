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
    maybe_plan(1, 'SQL::Translator::Parser::XML::SQLFairy',
              'SQL::Translator::Producer::PostgreSQL');
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
    to       => 'PostgreSQL',
    filename => $xmlfile,
) or die $sqlt->error;

eq_or_diff($sql, << "SQL");
DROP TABLE "Basic" CASCADE;
CREATE TABLE "Basic" (
  "id" serial NOT NULL,
  "title" character varying(100) DEFAULT 'hello' NOT NULL,
  "description" text DEFAULT '',
  "email" character varying(500),
  "explicitnulldef" character varying,
  "explicitemptystring" character varying DEFAULT '',
  -- Hello emptytagdef
  "emptytagdef" character varying DEFAULT '',
  "another_id" integer DEFAULT 2,
  "timest" timestamp,
  PRIMARY KEY ("id"),
  CONSTRAINT "emailuniqueindex" UNIQUE ("email"),
  CONSTRAINT "very_long_index_name_on_title_field_which_should_be_truncated_for_various_rdbms" UNIQUE ("title")
);
CREATE INDEX "titleindex" on "Basic" ("title");

DROP TABLE "Another" CASCADE;
CREATE TABLE "Another" (
  "id" serial NOT NULL,
  "num" numeric(10,2),
  PRIMARY KEY ("id")
);

DROP VIEW "email_list";
CREATE VIEW "email_list" ( "email" ) AS
    SELECT email FROM Basic WHERE (email IS NOT NULL)
;

DROP TRIGGER IF EXISTS "foo_trigger";

CREATE TRIGGER "foo_trigger" after insert ON "Basic" FOR EACH row update modified=timestamp();;

DROP TRIGGER IF EXISTS "bar_trigger";

CREATE TRIGGER "bar_trigger" before insert OR update ON "Basic" FOR EACH row update modified2=timestamp();;

ALTER TABLE "Basic" ADD FOREIGN KEY ("another_id")
  REFERENCES "Another" ("id") DEFERRABLE;

SQL
