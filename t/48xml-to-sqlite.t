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
              'SQL::Translator::Producer::SQLite');
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
    to       => 'SQLite',
    filename => $xmlfile,
) or die $sqlt->error;

# print ">>$sql<<\n";

is($sql, << "SQL");
BEGIN TRANSACTION;


DROP TABLE Basic;
CREATE TABLE Basic (
  id INTEGER PRIMARY KEY NOT NULL,
  title varchar(100) NOT NULL DEFAULT 'hello',
  description text DEFAULT '',
  email varchar(255),
  explicitnulldef varchar,
  explicitemptystring varchar DEFAULT '',
  -- Hello emptytagdef
  emptytagdef varchar DEFAULT '',
  another_id int(10) DEFAULT '2',
  timest timestamp
);

CREATE INDEX titleindex_Basic on Basic (title);
CREATE UNIQUE INDEX emailuniqueindex_Basic on Basic (email);

DROP TABLE Another;
CREATE TABLE Another (
  id INTEGER PRIMARY KEY NOT NULL
);


COMMIT;
SQL
