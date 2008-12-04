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

my $xmlfile = "$Bin/data/xml/samefield.xml";

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
DROP TABLE "one" CASCADE;
CREATE TABLE "one" (
  "same" character varying(100) DEFAULT 'hello' NOT NULL
);

DROP TABLE "two" CASCADE;
CREATE TABLE "two" (
  "same" character varying(100) DEFAULT 'hello' NOT NULL
);

SQL

### This doesnt work, cant add a field with a name thats already there, so how do we test dupe field names?!

# my $table = $sqlt->schema->get_table('two');
# $table->add_field(name => 'same');
# print Dumper($table);
# $sql = SQL::Translator::Producer::PostgreSQL::produce($sqlt);
# print ">>$sql<<\n";
