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

plan tests => 9;

use_ok('SQL::Translator::Diff') or die "Cannot continue\n";

my $tr = SQL::Translator->new;

my ( $source_schema, $target_schema, $parsed_sql_schema ) = map {
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
} (qw( create1.yml create2.yml ));

# Test for differences
my @out = SQL::Translator::Diff::schema_diff(
    $source_schema, 'MySQL',
    $target_schema, 'MySQL',
    {
        no_batch_alters  => 1,
        producer_args => { quote_table_names => 0 }
    }
);

ok( @out, 'Got a list' );

my $out = join('', @out);

eq_or_diff($out, <<'## END OF DIFF', "Diff as expected");
-- Convert schema 'create1.yml' to 'create2.yml':;

BEGIN;

SET foreign_key_checks=0;

CREATE TABLE added (
  id integer(11)
);

SET foreign_key_checks=1;

ALTER TABLE old_name RENAME TO new_name;

ALTER TABLE employee DROP FOREIGN KEY FK5302D47D93FE702E;

ALTER TABLE person DROP INDEX UC_age_name;

ALTER TABLE person DROP INDEX u_name;

ALTER TABLE employee DROP COLUMN job_title;

ALTER TABLE new_name ADD COLUMN new_field integer;

ALTER TABLE person ADD COLUMN is_rock_star tinyint(4) DEFAULT 1;

ALTER TABLE person CHANGE COLUMN person_id person_id integer(11) NOT NULL auto_increment;

ALTER TABLE person CHANGE COLUMN name name varchar(20) NOT NULL;

ALTER TABLE person CHANGE COLUMN age age integer(11) DEFAULT 18;

ALTER TABLE person CHANGE COLUMN iq iq integer(11) DEFAULT 0;

ALTER TABLE person CHANGE COLUMN description physical_description text;

ALTER TABLE person ADD UNIQUE INDEX unique_name (name);

ALTER TABLE employee ADD CONSTRAINT FK5302D47D93FE702E_diff FOREIGN KEY (employee_id) REFERENCES person (person_id);

ALTER TABLE person ADD UNIQUE UC_person_id (person_id);

ALTER TABLE person ADD UNIQUE UC_age_name (age, name);

ALTER TABLE person ENGINE=InnoDB;

ALTER TABLE deleted DROP FOREIGN KEY fk_fake;

DROP TABLE deleted;


COMMIT;

## END OF DIFF

$out = SQL::Translator::Diff::schema_diff($source_schema, 'MySQL', $target_schema, 'MySQL',
    { ignore_index_names => 1,
      ignore_constraint_names => 1,
      producer_args => { quote_table_names => 0 },
    });

eq_or_diff($out, <<'## END OF DIFF', "Diff as expected");
-- Convert schema 'create1.yml' to 'create2.yml':;

BEGIN;

SET foreign_key_checks=0;

CREATE TABLE added (
  id integer(11)
);

SET foreign_key_checks=1;

ALTER TABLE employee DROP COLUMN job_title;

ALTER TABLE old_name RENAME TO new_name,
                     ADD COLUMN new_field integer;

ALTER TABLE person DROP INDEX UC_age_name,
                   ADD COLUMN is_rock_star tinyint(4) DEFAULT 1,
                   CHANGE COLUMN person_id person_id integer(11) NOT NULL auto_increment,
                   CHANGE COLUMN name name varchar(20) NOT NULL,
                   CHANGE COLUMN age age integer(11) DEFAULT 18,
                   CHANGE COLUMN iq iq integer(11) DEFAULT 0,
                   CHANGE COLUMN description physical_description text,
                   ADD UNIQUE UC_person_id (person_id),
                   ADD UNIQUE UC_age_name (age, name),
                   ENGINE=InnoDB;

ALTER TABLE deleted DROP FOREIGN KEY fk_fake;

DROP TABLE deleted;


COMMIT;

## END OF DIFF


# Test for sameness
$out = SQL::Translator::Diff::schema_diff($source_schema, 'MySQL', $source_schema, 'MySQL' );

eq_or_diff($out, <<'## END OF DIFF', "No differences found");
-- Convert schema 'create1.yml' to 'create1.yml':;

-- No differences found;

## END OF DIFF

{
  my $t = SQL::Translator->new;
  $t->parser( 'MySQL' )
    or die $tr->error;
  my $out = $t->translate( catfile($Bin, qw/data mysql create.sql/ ) )
    or die $tr->error;

  # Lets remove the renamed table so we dont have to change the SQL or other tests
  $target_schema->drop_table('new_name');

  my $schema = $t->schema;
  unless ( $schema->name ) {
      $schema->name( 'create.sql' );
  }

  # Now lets change the type of one of the 'integer' columns so that it
  # matches what the mysql parser sees for '<col> interger'.
  my $field = $target_schema->get_table('employee')->get_field('employee_id');
  $field->data_type('integer');
  $field->size(0);
  $out = SQL::Translator::Diff::schema_diff($schema, 'MySQL', $target_schema, 'MySQL', { producer_args => { quote_table_names => 0 } } );
  eq_or_diff($out, <<'## END OF DIFF', "No differences found");
-- Convert schema 'create.sql' to 'create2.yml':;

BEGIN;

SET foreign_key_checks=0;

CREATE TABLE added (
  id integer(11)
);

SET foreign_key_checks=1;

ALTER TABLE employee DROP FOREIGN KEY FK5302D47D93FE702E,
                     DROP COLUMN job_title,
                     ADD CONSTRAINT FK5302D47D93FE702E_diff FOREIGN KEY (employee_id) REFERENCES person (person_id);

ALTER TABLE person DROP INDEX UC_age_name,
                   DROP INDEX u_name,
                   ADD COLUMN is_rock_star tinyint(4) DEFAULT 1,
                   CHANGE COLUMN person_id person_id integer(11) NOT NULL auto_increment,
                   CHANGE COLUMN name name varchar(20) NOT NULL,
                   CHANGE COLUMN age age integer(11) DEFAULT 18,
                   CHANGE COLUMN iq iq integer(11) DEFAULT 0,
                   CHANGE COLUMN description physical_description text,
                   ADD UNIQUE INDEX unique_name (name),
                   ADD UNIQUE UC_person_id (person_id),
                   ADD UNIQUE UC_age_name (age, name),
                   ENGINE=InnoDB;

DROP TABLE deleted;


COMMIT;

## END OF DIFF
}

# Test InnoDB stupidness. Have to drop constraints before re-adding them if
# they are just alters.


{
  my $s1 = SQL::Translator::Schema->new;
  my $s2 = SQL::Translator::Schema->new;

  $s1->name('Schema 1');
  $s2->name('Schema 2');

  my $t1 = $s1->add_table($target_schema->get_table('employee'));
  my $t2 = $s2->add_table(dclone($target_schema->get_table('employee')));


  my ($c) = grep { $_->name eq 'FK5302D47D93FE702E_diff' } $t2->get_constraints;
  $c->on_delete('CASCADE');

  $t2->add_constraint(
    name => 'new_constraint',
    type => 'FOREIGN KEY',
    fields => ['employee_id'],
    reference_fields => ['fake'],
    reference_table => 'patty',
  );

  $t2->add_field(
    name => 'new',
    data_type => 'int'
  );

  my $out = SQL::Translator::Diff::schema_diff($s1, 'MySQL', $s2, 'MySQL' );

  eq_or_diff($out, <<'## END OF DIFF', "Batch alter of constraints work for InnoDB");
-- Convert schema 'Schema 1' to 'Schema 2':;

BEGIN;

ALTER TABLE employee DROP FOREIGN KEY FK5302D47D93FE702E_diff;

ALTER TABLE employee ADD COLUMN new integer,
                     ADD CONSTRAINT FK5302D47D93FE702E_diff FOREIGN KEY (employee_id) REFERENCES person (person_id) ON DELETE CASCADE,
                     ADD CONSTRAINT new_constraint FOREIGN KEY (employee_id) REFERENCES patty (fake);


COMMIT;

## END OF DIFF
}

{
  # Test other things about renaming tables to - namely that renames
  # constraints are still formated right.

  my $s1 = SQL::Translator::Schema->new;
  my $s2 = SQL::Translator::Schema->new;

  $s1->name('Schema 3');
  $s2->name('Schema 4');

  my $t1 = $s1->add_table(dclone($target_schema->get_table('employee')));
  my $t2 = dclone($target_schema->get_table('employee'));
  $t2->name('fnord');
  $t2->extra(renamed_from => 'employee');
  $s2->add_table($t2);


  $t1->add_constraint(
    name => 'bar_fk',
    type => 'FOREIGN KEY',
    fields => ['employee_id'],
    reference_fields => ['id'],
    reference_table => 'bar',
  );
  $t2->add_constraint(
    name => 'foo_fk',
    type => 'FOREIGN KEY',
    fields => ['employee_id'],
    reference_fields => ['id'],
    reference_table => 'foo',
  );

  my $out = SQL::Translator::Diff::schema_diff($s1, 'MySQL', $s2, 'MySQL' );
  eq_or_diff($out, <<'## END OF DIFF', "Alter/drop constraints works with rename table");
-- Convert schema 'Schema 3' to 'Schema 4':;

BEGIN;

ALTER TABLE employee RENAME TO fnord,
                     DROP FOREIGN KEY bar_fk,
                     ADD CONSTRAINT foo_fk FOREIGN KEY (employee_id) REFERENCES foo (id);


COMMIT;

## END OF DIFF

  # Test quoting works too.
  $out = SQL::Translator::Diff::schema_diff($s1, 'MySQL', $s2, 'MySQL',
    { producer_args => { quote_table_names => '`' } }
  );
  eq_or_diff($out, <<'## END OF DIFF', "Quoting can be turned on");
-- Convert schema 'Schema 3' to 'Schema 4':;

BEGIN;

ALTER TABLE `employee` RENAME TO `fnord`,
                       DROP FOREIGN KEY bar_fk,
                       ADD CONSTRAINT foo_fk FOREIGN KEY (employee_id) REFERENCES `foo` (id);


COMMIT;

## END OF DIFF
}
