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
  maybe_plan(2, 'SQL::Translator::Parser::XML::SQLFairy', 'SQL::Translator::Producer::Oracle');
}

my $xmlfile = "$Bin/data/xml/schema.xml";

my $sqlt;
$sqlt = SQL::Translator->new(
  no_comments       => 1,
  quote_table_names => 1,
  quote_field_names => 1,
  show_warnings     => 0,
  add_drop_table    => 1,
);

die "Can't find test schema $xmlfile" unless -e $xmlfile;

my @sql = $sqlt->translate(
  from     => 'XML-SQLFairy',
  to       => 'Oracle',
  filename => $xmlfile,
) or die $sqlt->error;

my $sql_string = $sqlt->translate(
  from     => 'XML-SQLFairy',
  to       => 'Oracle',
  filename => $xmlfile,
) or die $sqlt->error;

my $want = [
  'DROP TABLE "Basic" CASCADE CONSTRAINTS',
  'DROP SEQUENCE "sq_Basic_id"',
  'CREATE SEQUENCE "sq_Basic_id"',
  'CREATE TABLE "Basic" (
  "id" number(10) NOT NULL,
  "title" varchar2(100) DEFAULT \'hello\' NOT NULL,
  "description" clob DEFAULT \'\',
  "email" varchar2(500),
  "explicitnulldef" varchar2(4000),
  "explicitemptystring" varchar2(4000) DEFAULT \'\',
  "emptytagdef" varchar2(4000) DEFAULT \'\',
  "another_id" number(10) DEFAULT \'2\',
  "timest" date,
  PRIMARY KEY ("id"),
  CONSTRAINT "u_Basic_emailuniqueindex" UNIQUE ("email"),
  CONSTRAINT "u_Basic_very_long_index_name_o" UNIQUE ("title")
)',
  'DROP TABLE "Another" CASCADE CONSTRAINTS',
  'DROP SEQUENCE "sq_Another_id"',
  'CREATE SEQUENCE "sq_Another_id"',
  'CREATE TABLE "Another" (
  "id" number(10) NOT NULL,
  "num" number(10,2),
  PRIMARY KEY ("id")
)',
  'DROP VIEW "email_list"',
  'CREATE VIEW "email_list" AS
SELECT email FROM Basic WHERE (email IS NOT NULL)',
  'ALTER TABLE "Basic" ADD CONSTRAINT "Basic_another_id_fk" FOREIGN KEY ("another_id") REFERENCES "Another" ("id")',
  'CREATE OR REPLACE TRIGGER "ai_Basic_id"
BEFORE INSERT ON "Basic"
FOR EACH ROW WHEN (
 new."id" IS NULL OR new."id" = 0
)
BEGIN
 SELECT "sq_Basic_id".nextval
 INTO :new."id"
 FROM dual;
END;
',
  'CREATE OR REPLACE TRIGGER "ai_Another_id"
BEFORE INSERT ON "Another"
FOR EACH ROW WHEN (
 new."id" IS NULL OR new."id" = 0
)
BEGIN
 SELECT "sq_Another_id".nextval
 INTO :new."id"
 FROM dual;
END;
',
  'CREATE INDEX "titleindex" ON "Basic" ("title")'
];

is_deeply(\@sql, $want, 'Got correct Oracle statements in list context');

eq_or_diff(
  $sql_string, q|DROP TABLE "Basic" CASCADE CONSTRAINTS;

DROP SEQUENCE "sq_Basic_id01";

CREATE SEQUENCE "sq_Basic_id01";

CREATE TABLE "Basic" (
  "id" number(10) NOT NULL,
  "title" varchar2(100) DEFAULT 'hello' NOT NULL,
  "description" clob DEFAULT '',
  "email" varchar2(500),
  "explicitnulldef" varchar2(4000),
  "explicitemptystring" varchar2(4000) DEFAULT '',
  "emptytagdef" varchar2(4000) DEFAULT '',
  "another_id" number(10) DEFAULT '2',
  "timest" date,
  PRIMARY KEY ("id"),
  CONSTRAINT "u_Basic_emailuniqueindex01" UNIQUE ("email"),
  CONSTRAINT "u_Basic_very_long_index_name01" UNIQUE ("title")
);

DROP TABLE "Another" CASCADE CONSTRAINTS;

DROP SEQUENCE "sq_Another_id01";

CREATE SEQUENCE "sq_Another_id01";

CREATE TABLE "Another" (
  "id" number(10) NOT NULL,
  "num" number(10,2),
  PRIMARY KEY ("id")
);

DROP VIEW "email_list";

CREATE VIEW "email_list" AS
SELECT email FROM Basic WHERE (email IS NOT NULL);

ALTER TABLE "Basic" ADD CONSTRAINT "Basic_another_id_fk01" FOREIGN KEY ("another_id") REFERENCES "Another" ("id");

CREATE INDEX "titleindex01" ON "Basic" ("title");

CREATE OR REPLACE TRIGGER "ai_Basic_id01"
BEFORE INSERT ON "Basic"
FOR EACH ROW WHEN (
 new."id" IS NULL OR new."id" = 0
)
BEGIN
 SELECT "sq_Basic_id01".nextval
 INTO :new."id"
 FROM dual;
END;
/

CREATE OR REPLACE TRIGGER "ai_Another_id01"
BEFORE INSERT ON "Another"
FOR EACH ROW WHEN (
 new."id" IS NULL OR new."id" = 0
)
BEGIN
 SELECT "sq_Another_id01".nextval
 INTO :new."id"
 FROM dual;
END;
/

|
);
