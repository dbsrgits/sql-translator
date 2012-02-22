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
use SQL::Translator::Schema::Constants;
use Storable 'dclone';

plan tests => 4;

use_ok('SQL::Translator::Diff') or die "Cannot continue\n";

my $tr = SQL::Translator->new;

my ( $source_schema, $target_schema, $parsed_sql_schema ) = map {
    my $t = SQL::Translator->new;
    $t->parser( 'YAML' )
      or die $tr->error;
    my $out = $t->translate( catfile($Bin, qw/data diff pgsql/, $_ ) )
      or die $tr->error;

    my $schema = $t->schema;
    unless ( $schema->name ) {
        $schema->name( $_ );
    }
    ($schema);
} (qw( create1.yml create2.yml ));

# Test for differences
my $out = SQL::Translator::Diff::schema_diff(
    $source_schema,
   'PostgreSQL',
    $target_schema,
   'PostgreSQL',
   {
     producer_args => {
         quote_identifiers => 0,
     }
   }
);

eq_or_diff($out, <<'## END OF DIFF', "Diff as expected");
-- Convert schema 'create1.yml' to 'create2.yml':;

BEGIN;

CREATE TABLE added (
  id bigint
);

ALTER TABLE old_name RENAME TO new_name;

ALTER TABLE employee DROP CONSTRAINT FK5302D47D93FE702E;

ALTER TABLE person DROP CONSTRAINT UC_age_name;

DROP INDEX u_name;

ALTER TABLE employee DROP COLUMN job_title;

ALTER TABLE new_name ADD COLUMN new_field integer;

ALTER TABLE person ADD COLUMN is_rock_star smallint DEFAULT 1;

ALTER TABLE person ALTER COLUMN person_id TYPE serial;

ALTER TABLE person ALTER COLUMN name SET NOT NULL;

ALTER TABLE person ALTER COLUMN age SET DEFAULT 18;

ALTER TABLE person ALTER COLUMN iq TYPE bigint;

ALTER TABLE person RENAME COLUMN description TO physical_description;

ALTER TABLE person ADD CONSTRAINT unique_name UNIQUE (name);

ALTER TABLE employee ADD CONSTRAINT FK5302D47D93FE702E_diff FOREIGN KEY (employee_id)
  REFERENCES person (person_id) DEFERRABLE;

ALTER TABLE person ADD CONSTRAINT UC_person_id UNIQUE (person_id);

ALTER TABLE person ADD CONSTRAINT UC_age_name UNIQUE (age, name);

DROP TABLE deleted CASCADE;


COMMIT;

## END OF DIFF

$out = SQL::Translator::Diff::schema_diff(
    $source_schema, 'PostgreSQL', $target_schema, 'PostgreSQL',
    { ignore_index_names => 1,
      ignore_constraint_names => 1,
      producer_args => {
         quote_table_names => 0,
         quote_field_names => 0,
      }
    });

eq_or_diff($out, <<'## END OF DIFF', "Diff as expected");
-- Convert schema 'create1.yml' to 'create2.yml':;

BEGIN;

CREATE TABLE added (
  id bigint
);

ALTER TABLE old_name RENAME TO new_name;

ALTER TABLE person DROP CONSTRAINT UC_age_name;

ALTER TABLE employee DROP COLUMN job_title;

ALTER TABLE new_name ADD COLUMN new_field integer;

ALTER TABLE person ADD COLUMN is_rock_star smallint DEFAULT 1;

ALTER TABLE person ALTER COLUMN person_id TYPE serial;

ALTER TABLE person ALTER COLUMN name SET NOT NULL;

ALTER TABLE person ALTER COLUMN age SET DEFAULT 18;

ALTER TABLE person ALTER COLUMN iq TYPE bigint;

ALTER TABLE person RENAME COLUMN description TO physical_description;

ALTER TABLE person ADD CONSTRAINT UC_person_id UNIQUE (person_id);

ALTER TABLE person ADD CONSTRAINT UC_age_name UNIQUE (age, name);

DROP TABLE deleted CASCADE;


COMMIT;

## END OF DIFF


# Test for sameness
$out = SQL::Translator::Diff::schema_diff(
    $source_schema, 'PostgreSQL', $source_schema, 'PostgreSQL'
);

eq_or_diff($out, <<'## END OF DIFF', "No differences found");
-- Convert schema 'create1.yml' to 'create1.yml':;

-- No differences found;

## END OF DIFF
