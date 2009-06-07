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
    maybe_plan(2, 'SQL::Translator::Parser::XML::SQLFairy',
                  'SQL::Translator::Producer::Oracle');
}

my $xmlfile = "$Bin/data/xml/schema.xml";

my $sqlt;
$sqlt = SQL::Translator->new(
    no_comments => 1,
    show_warnings  => 0,
    add_drop_table => 1,
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
'DROP TABLE Basic CASCADE CONSTRAINTS',
          'DROP SEQUENCE sq_Basic_id',
          'CREATE SEQUENCE sq_Basic_id',
          'CREATE TABLE Basic (
  id number(10) NOT NULL,
  title varchar2(100) DEFAULT \'hello\' NOT NULL,
  description clob DEFAULT \'\',
  email varchar2(500),
  explicitnulldef varchar2,
  explicitemptystring varchar2 DEFAULT \'\',
  emptytagdef varchar2 DEFAULT \'\',
  another_id number(10) DEFAULT \'2\',
  timest date,
  PRIMARY KEY (id),
  CONSTRAINT emailuniqueindex UNIQUE (email)
)',
          'DROP TABLE Another CASCADE CONSTRAINTS',
          'DROP SEQUENCE sq_Another_id',
          'CREATE SEQUENCE sq_Another_id',
          'CREATE TABLE Another (
  id number(10) NOT NULL,
  PRIMARY KEY (id)
)',
          'CREATE VIEW email_list AS
SELECT email FROM Basic WHERE (email IS NOT NULL)',
          'ALTER TABLE Basic ADD CONSTRAINT Basic_another_id_fk FOREIGN KEY (another_id) REFERENCES Another (id)',
          'CREATE OR REPLACE TRIGGER ai_Basic_id
BEFORE INSERT ON Basic
FOR EACH ROW WHEN (
 new.id IS NULL OR new.id = 0
)
BEGIN
 SELECT sq_Basic_id.nextval
 INTO :new.id
 FROM dual;
END;
',
          'CREATE OR REPLACE TRIGGER ts_Basic_timest
BEFORE INSERT OR UPDATE ON Basic
FOR EACH ROW WHEN (new.timest IS NULL)
BEGIN 
 SELECT sysdate INTO :new.timest FROM dual;
END;
',
          'CREATE OR REPLACE TRIGGER ai_Another_id
BEFORE INSERT ON Another
FOR EACH ROW WHEN (
 new.id IS NULL OR new.id = 0
)
BEGIN
 SELECT sq_Another_id.nextval
 INTO :new.id
 FROM dual;
END;
',
'CREATE INDEX titleindex on Basic (title)'];

is_deeply(\@sql, $want, 'Got correct Oracle statements in list context');

is($sql_string, q|DROP TABLE Basic CASCADE CONSTRAINTS;

DROP SEQUENCE sq_Basic_id01;

CREATE SEQUENCE sq_Basic_id01;

CREATE TABLE Basic (
  id number(10) NOT NULL,
  title varchar2(100) DEFAULT 'hello' NOT NULL,
  description clob DEFAULT '',
  email varchar2(500),
  explicitnulldef varchar2,
  explicitemptystring varchar2 DEFAULT '',
  emptytagdef varchar2 DEFAULT '',
  another_id number(10) DEFAULT '2',
  timest date,
  PRIMARY KEY (id),
  CONSTRAINT emailuniqueindex UNIQUE (email)
);

DROP TABLE Another CASCADE CONSTRAINTS;

DROP SEQUENCE sq_Another_id01;

CREATE SEQUENCE sq_Another_id01;

CREATE TABLE Another (
  id number(10) NOT NULL,
  PRIMARY KEY (id)
);

CREATE VIEW email_list AS
SELECT email FROM Basic WHERE (email IS NOT NULL);

ALTER TABLE Basic ADD CONSTRAINT Basic_another_id_fk01 FOREIGN KEY (another_id) REFERENCES Another (id);

CREATE INDEX titleindex01 on Basic (title);

CREATE OR REPLACE TRIGGER ai_Basic_id01
BEFORE INSERT ON Basic
FOR EACH ROW WHEN (
 new.id IS NULL OR new.id = 0
)
BEGIN
 SELECT sq_Basic_id01.nextval
 INTO :new.id
 FROM dual;
END;
/

CREATE OR REPLACE TRIGGER ts_Basic_timest01
BEFORE INSERT OR UPDATE ON Basic
FOR EACH ROW WHEN (new.timest IS NULL)
BEGIN 
 SELECT sysdate INTO :new.timest FROM dual;
END;
/

CREATE OR REPLACE TRIGGER ai_Another_id01
BEFORE INSERT ON Another
FOR EACH ROW WHEN (
 new.id IS NULL OR new.id = 0
)
BEGIN
 SELECT sq_Another_id01.nextval
 INTO :new.id
 FROM dual;
END;
/|);
