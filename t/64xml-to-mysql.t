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
              'SQL::Translator::Producer::MySQL');
}

my $xmlfile = "$Bin/data/xml/schema.xml";

my $sqlt;
$sqlt = SQL::Translator->new(
    no_comments => 1,
    show_warnings  => 0,
    add_drop_table => 1,
    producer_args => {
        mysql_version => 5.005,
    },
);

die "Can't find test schema $xmlfile" unless -e $xmlfile;

my @want = (
    q[SET foreign_key_checks=0],

    q[DROP TABLE IF EXISTS `Basic`],
    q[CREATE TABLE `Basic` (
  `id` integer(10) zerofill NOT NULL auto_increment,
  `title` varchar(100) NOT NULL DEFAULT 'hello',
  `description` text NULL DEFAULT '',
  `email` varchar(500) NULL,
  `explicitnulldef` varchar(255) NULL,
  `explicitemptystring` varchar(255) NULL DEFAULT '',
  `emptytagdef` varchar(255) NULL DEFAULT '' comment 'Hello emptytagdef',
  `another_id` integer(10) NULL DEFAULT 2,
  `timest` timestamp NULL,
  INDEX `titleindex` (`title`),
  INDEX (`another_id`),
  PRIMARY KEY (`id`),
  UNIQUE `emailuniqueindex` (`email`),
  UNIQUE `very_long_index_name_on_title_field_which_should_be_tru_14b59999` (`title`),
  CONSTRAINT `Basic_fk` FOREIGN KEY (`another_id`) REFERENCES `Another` (`id`)
) ENGINE=InnoDB],

    q[DROP TABLE IF EXISTS `Another`],
    q[CREATE TABLE `Another` (
  `id` integer(10) NOT NULL auto_increment,
  `num` numeric(10, 2) NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB],
    q[CREATE OR REPLACE
  VIEW `email_list` ( `email` ) AS
    SELECT email FROM Basic WHERE (email IS NOT NULL)
],

    q[DROP TRIGGER IF EXISTS `foo_trigger`],
    q[CREATE TRIGGER `foo_trigger` after insert ON `Basic`
  FOR EACH ROW BEGIN update modified=timestamp(); END],

    q[DROP TRIGGER IF EXISTS `bar_trigger_insert`],
    q[CREATE TRIGGER `bar_trigger_insert` before insert ON `Basic`
  FOR EACH ROW BEGIN update modified2=timestamp(); END],

    q[DROP TRIGGER IF EXISTS `bar_trigger_update`],
    q[CREATE TRIGGER `bar_trigger_update` before update ON `Basic`
  FOR EACH ROW BEGIN update modified2=timestamp(); END],

    q[SET foreign_key_checks=1],
);

my $sql = $sqlt->translate(
    from     => 'XML-SQLFairy',
    to       => 'MySQL',
    filename => $xmlfile,
) or die $sqlt->error;

eq_or_diff($sql, join("", map { "$_;\n\n" } @want));

my @sql = $sqlt->translate(
    from     => 'XML-SQLFairy',
    to       => 'MySQL',
    filename => $xmlfile,
) or die $sqlt->error;

is_deeply(\@sql, \@want);
