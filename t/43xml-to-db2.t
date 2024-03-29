#!/usr/bin/perl
use strict;

use FindBin qw/$Bin/;
use Test::More;
use Test::SQL::Translator;
use Test::Differences;
use Test::Exception;
use Data::Dumper;
use SQL::Translator;
use SQL::Translator::Schema::Constants;

BEGIN {
  maybe_plan(1, 'SQL::Translator::Parser::XML::SQLFairy', 'SQL::Translator::Producer::DB2');
}

my $xmlfile = "$Bin/data/xml/schema.xml";

my $sqlt;
$sqlt = SQL::Translator->new(
  no_comments    => 1,
  show_warnings  => 0,
  add_drop_table => 1,
);

die "Can't find test schema $xmlfile" unless -e $xmlfile;

my $sql = $sqlt->translate(
  from     => 'XML-SQLFairy',
  to       => 'DB2',
  filename => $xmlfile,
) or die $sqlt->error;

eq_or_diff($sql, << "SQL");
DROP TABLE Basic;

CREATE TABLE Basic (
  id INTEGER GENERATED BY DEFAULT AS IDENTITY (START WITH 1, INCREMENT BY 1) NOT NULL,
  title VARCHAR(100) NOT NULL DEFAULT 'hello',
  description VARCHAR(0) DEFAULT '',
  email VARCHAR(500),
  explicitnulldef VARCHAR(0),
  explicitemptystring VARCHAR(0) DEFAULT '',
  emptytagdef VARCHAR(0) DEFAULT '',
  another_id INTEGER DEFAULT 2,
  timest TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT emailuniqueindex UNIQUE (email),
  CONSTRAINT very_long_index_name_on_title_field_which_should_be_truncated_for_various_rdbms UNIQUE (title)
);

DROP TABLE Another;

CREATE TABLE Another (
  id INTEGER GENERATED BY DEFAULT AS IDENTITY (START WITH 1, INCREMENT BY 1) NOT NULL,
  num NUMERIC(10,2),
  PRIMARY KEY (id)
);

ALTER TABLE Basic ADD FOREIGN KEY (another_id) REFERENCES Another(id);

CREATE INDEX titleindex ON Basic ( title );

CREATE VIEW email_list AS
SELECT email FROM Basic WHERE (email IS NOT NULL);

CREATE TRIGGER foo_trigger after insert ON Basic REFERENCING OLD AS oldrow NEW AS newrow FOR EACH ROW MODE DB2SQL update modified=timestamp();

CREATE TRIGGER bar_trigger before insert, update ON Basic REFERENCING OLD AS oldrow NEW AS newrow FOR EACH ROW MODE DB2SQL update modified2=timestamp();
SQL
