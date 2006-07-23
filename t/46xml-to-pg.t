#!/usr/bin/perl
use strict;

use FindBin qw/$Bin/;
use Test::More;
use Test::SQL::Translator;
use Test::Exception;
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
    show_warnings  => 1,
    add_drop_table => 1,
);

die "Can't find test schema $xmlfile" unless -e $xmlfile;

my $sql = $sqlt->translate(
    from     => 'XML-SQLFairy',
    to       => 'PostgreSQL',
    filename => $xmlfile,
) or die $sqlt->error;

is($sql, << "SQL");
DROP TABLE "Basic";
CREATE TABLE "Basic" (
  "id" serial NOT NULL,
  "title" character varying(100) DEFAULT 'hello' NOT NULL,
  "description" text DEFAULT '',
  "email" character varying(255),
  "explicitnulldef" character varying,
  "explicitemptystring" character varying DEFAULT '',
  -- Hello emptytagdef
  "emptytagdef" character varying DEFAULT '',
  PRIMARY KEY ("id"),
  Constraint "emailuniqueindex" UNIQUE ("email")
);
CREATE INDEX "titleindex" on "Basic" ("title");
SQL
