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
my $out = SQL::Translator::Diff::schema_diff( $source_schema, 'MySQL', $target_schema, 'MySQL', { no_batch_alters => 1} );
eq_or_diff($out, <<'## END OF DIFF', "Diff as expected");
-- Convert schema 'create1.yml' to 'create2.yml':

BEGIN TRANSACTION;

SET foreign_key_checks=0;


CREATE TABLE added (
  id integer(11)
);


SET foreign_key_checks=1;


ALTER TABLE employee DROP FOREIGN KEY FK5302D47D93FE702E;
ALTER TABLE person DROP UNIQUE UC_age_name;
ALTER TABLE person DROP INDEX u_name;
ALTER TABLE employee DROP COLUMN job_title;
ALTER TABLE person ADD COLUMN is_rock_star tinyint(4) DEFAULT '1';
ALTER TABLE person CHANGE COLUMN person_id person_id integer(11) NOT NULL auto_increment;
ALTER TABLE person CHANGE COLUMN name name varchar(20) NOT NULL;
ALTER TABLE person CHANGE COLUMN age age integer(11) DEFAULT '18';
ALTER TABLE person CHANGE COLUMN iq iq integer(11) DEFAULT '0';
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

#die $out;

$out = SQL::Translator::Diff::schema_diff($source_schema, 'MySQL', $target_schema, 'MySQL',
    { ignore_index_names => 1,
      ignore_constraint_names => 1
    });

eq_or_diff($out, <<'## END OF DIFF', "Diff as expected");
-- Convert schema 'create1.yml' to 'create2.yml':

BEGIN TRANSACTION;

SET foreign_key_checks=0;


CREATE TABLE added (
  id integer(11)
);


SET foreign_key_checks=1;


ALTER TABLE employee DROP COLUMN job_title;
ALTER TABLE person DROP UNIQUE UC_age_name,
                   ADD COLUMN is_rock_star tinyint(4) DEFAULT '1',
                   CHANGE COLUMN person_id person_id integer(11) NOT NULL auto_increment,
                   CHANGE COLUMN name name varchar(20) NOT NULL,
                   CHANGE COLUMN age age integer(11) DEFAULT '18',
                   CHANGE COLUMN iq iq integer(11) DEFAULT '0',
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
-- Convert schema 'create1.yml' to 'create1.yml':

-- No differences found

## END OF DIFF

=cut
