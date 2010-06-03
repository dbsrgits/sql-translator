#!/usr/bin/perl
# vim: set ft=perl:

use strict;
use warnings;
use SQL::Translator;

use File::Spec::Functions qw(catfile updir tmpdir);
use FindBin qw($Bin);
use Test::More;
use Test::Differences;
use Test::SQL::Translator qw(maybe_plan);

plan tests => 4;

use_ok('SQL::Translator::Diff') or die "Cannot continue\n";

my $tr            = SQL::Translator->new;

my ( $source_schema, $target_schema ) = map {
    my $t = SQL::Translator->new;
    $t->parser( 'YAML' )
      or die $tr->error;
    my $out = $t->translate( catfile($Bin, qw/data diff/, $_ ) )
      or die $tr->error;
    
    my $schema = $t->schema;
    unless ( $schema->name ) {
        $schema->name( $_ );
    }
    ($schema);
} (qw/create1.yml create2.yml/);

# Test for differences
my $out = SQL::Translator::Diff::schema_diff( $source_schema, 'SQLite', $target_schema, 'SQLite', 
  { no_batch_alters => 1, 
    ignore_missing_methods => 1,
    output_db => 'SQLite',
  } 
);

eq_or_diff($out, <<'## END OF DIFF', "Diff as expected");
-- Convert schema 'create1.yml' to 'create2.yml':;

BEGIN;

CREATE TABLE added (
  id int(11)
);

ALTER TABLE old_name RENAME TO new_name;

DROP INDEX FK5302D47D93FE702E;

DROP INDEX UC_age_name;

DROP INDEX u_name;

-- SQL::Translator::Producer::SQLite cant drop_field;

ALTER TABLE new_name ADD COLUMN new_field int;

ALTER TABLE person ADD COLUMN is_rock_star tinyint(4) DEFAULT 1;

-- SQL::Translator::Producer::SQLite cant alter_field;

-- SQL::Translator::Producer::SQLite cant rename_field;

CREATE UNIQUE INDEX unique_name ON person (name);

CREATE UNIQUE INDEX UC_person_id ON person (person_id);

CREATE UNIQUE INDEX UC_age_name ON person (age, name);

DROP TABLE deleted;


COMMIT;

## END OF DIFF


$out = SQL::Translator::Diff::schema_diff($source_schema, 'SQLite', $target_schema, 'SQLite',
    { ignore_index_names => 1,
      ignore_constraint_names => 1,
      output_db => 'SQLite',
    });

eq_or_diff($out, <<'## END OF DIFF', "Diff as expected");
-- Convert schema 'create1.yml' to 'create2.yml':;

BEGIN;

CREATE TABLE added (
  id int(11)
);

CREATE TEMPORARY TABLE employee_temp_alter (
  position varchar(50) NOT NULL,
  employee_id int(11) NOT NULL,
  PRIMARY KEY (position, employee_id)
);

INSERT INTO employee_temp_alter SELECT position, employee_id FROM employee;

DROP TABLE employee;

CREATE TABLE employee (
  position varchar(50) NOT NULL,
  employee_id int(11) NOT NULL,
  PRIMARY KEY (position, employee_id)
);

INSERT INTO employee SELECT position, employee_id FROM employee_temp_alter;

DROP TABLE employee_temp_alter;

ALTER TABLE old_name RENAME TO new_name;

ALTER TABLE new_name ADD COLUMN new_field int;

CREATE TEMPORARY TABLE person_temp_alter (
  person_id INTEGER PRIMARY KEY NOT NULL,
  name varchar(20) NOT NULL,
  age int(11) DEFAULT 18,
  weight double(11,2),
  iq int(11) DEFAULT 0,
  is_rock_star tinyint(4) DEFAULT 1,
  physical_description text
);

INSERT INTO person_temp_alter SELECT person_id, name, age, weight, iq, is_rock_star, physical_description FROM person;

DROP TABLE person;

CREATE TABLE person (
  person_id INTEGER PRIMARY KEY NOT NULL,
  name varchar(20) NOT NULL,
  age int(11) DEFAULT 18,
  weight double(11,2),
  iq int(11) DEFAULT 0,
  is_rock_star tinyint(4) DEFAULT 1,
  physical_description text
);

CREATE UNIQUE INDEX unique_name02 ON person (name);

CREATE UNIQUE INDEX UC_person_id02 ON person (person_id);

CREATE UNIQUE INDEX UC_age_name02 ON person (age, name);

INSERT INTO person SELECT person_id, name, age, weight, iq, is_rock_star, physical_description FROM person_temp_alter;

DROP TABLE person_temp_alter;

DROP TABLE deleted;


COMMIT;

## END OF DIFF

# Note the 02 in the 3 names above (end of diff) are an implementation
# quirk - there is nothing to reset the global seen-names register
# The rewrite should abolish this altogether, and carry the register in
# the main schema object

# Test for sameness
$out = SQL::Translator::Diff::schema_diff($source_schema, 'MySQL', $source_schema, 'MySQL' );

eq_or_diff($out, <<'## END OF DIFF', "No differences found");
-- Convert schema 'create1.yml' to 'create1.yml':;

-- No differences found;

## END OF DIFF

