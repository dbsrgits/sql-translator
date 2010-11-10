#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::SQL::Translator qw(maybe_plan);

use Data::Dumper;
use FindBin qw/$Bin/;

# Testing 1,2,3,4...
#=============================================================================

BEGIN {
    maybe_plan(10,
        'SQL::Translator::Producer::PostgreSQL',
        'Test::Differences',
    )
}
use Test::Differences;
use SQL::Translator;

my $PRODUCER = \&SQL::Translator::Producer::PostgreSQL::create_field;

my $schema = SQL::Translator::Schema->new( name => 'myschema' );

my $table = SQL::Translator::Schema::Table->new( name => 'mytable', schema => $schema );

my $field1 = SQL::Translator::Schema::Field->new( name      => 'myfield',
                                                  table     => $table,
                                                  data_type => 'geometry',
                                                  extra     => {
												      dimensions    => 2,
												      geometry_type => 'POINT',
												      srid          => -1
													},
                                                  default_value     => undef,
                                                  is_auto_increment => 0,
                                                  is_nullable       => 1,
                                                  is_foreign_key    => 0,
                                                  is_unique         => 0 );

my $field1_sql = SQL::Translator::Producer::PostgreSQL::create_field($field1);

is($field1_sql, 'myfield geometry', 'Create geometry field works');

my $field1_geocol = SQL::Translator::Producer::PostgreSQL::add_geometry_column($field1);

is($field1_geocol, "INSERT INTO geometry_columns VALUES ('','myschema','mytable','myfield','2','-1','POINT')", 'Add geometry column works');

my $field1_geocon = SQL::Translator::Producer::PostgreSQL::add_geometry_constraints($field1);

is($field1_geocon, qq[ALTER TABLE mytable ADD CONSTRAINT "enforce_dims_myfield" CHECK ((st_ndims(myfield) = 2))
ALTER TABLE mytable ADD CONSTRAINT "enforce_srid_myfield" CHECK ((st_srid(myfield) = -1))
ALTER TABLE mytable ADD CONSTRAINT "enforce_geotype_myfield" CHECK ((geometrytype(myfield) = 'POINT'::text OR myfield IS NULL))],
 'Add geometry constraints works');

my $field2 = SQL::Translator::Schema::Field->new( name      => 'myfield',
                                                  table => $table,
                                                  data_type => 'VARCHAR',
                                                  size      => 25,
                                                  default_value => undef,
                                                  is_auto_increment => 0,
                                                  is_nullable => 0,
                                                  is_foreign_key => 0,
                                                  is_unique => 0 );

my $alter_field = SQL::Translator::Producer::PostgreSQL::alter_field($field1,
                                                                $field2);
is($alter_field, qq[DELETE FROM geometry_columns WHERE f_table_schema = 'myschema' AND f_table_name = 'mytable' AND f_geometry_column = 'myfield'
ALTER TABLE mytable DROP CONSTRAINT enforce_dims_myfield
ALTER TABLE mytable DROP CONSTRAINT enforce_srid_myfield
ALTER TABLE mytable DROP CONSTRAINT enforce_geotype_myfield
ALTER TABLE mytable ALTER COLUMN myfield SET NOT NULL
ALTER TABLE mytable ALTER COLUMN myfield TYPE character varying(25)],
 'Alter field geometry to non geometry works');

my $alter_field2 = SQL::Translator::Producer::PostgreSQL::alter_field($field2,
                                                                $field1);
is($alter_field2, qq[ALTER TABLE mytable ALTER COLUMN myfield DROP NOT NULL
ALTER TABLE mytable ALTER COLUMN myfield TYPE geometry
INSERT INTO geometry_columns VALUES ('','myschema','mytable','myfield','2','-1','POINT')
ALTER TABLE mytable ADD CONSTRAINT "enforce_dims_myfield" CHECK ((st_ndims(myfield) = 2))
ALTER TABLE mytable ADD CONSTRAINT "enforce_srid_myfield" CHECK ((st_srid(myfield) = -1))
ALTER TABLE mytable ADD CONSTRAINT "enforce_geotype_myfield" CHECK ((geometrytype(myfield) = 'POINT'::text OR myfield IS NULL))],
 'Alter field non geometry to geometry works');

$field1->name('field3');
my $add_field = SQL::Translator::Producer::PostgreSQL::add_field($field1);

is($add_field, qq[ALTER TABLE mytable ADD COLUMN field3 geometry
INSERT INTO geometry_columns VALUES ('','myschema','mytable','field3','2','-1','POINT')
ALTER TABLE mytable ADD CONSTRAINT "enforce_dims_field3" CHECK ((st_ndims(field3) = 2))
ALTER TABLE mytable ADD CONSTRAINT "enforce_srid_field3" CHECK ((st_srid(field3) = -1))
ALTER TABLE mytable ADD CONSTRAINT "enforce_geotype_field3" CHECK ((geometrytype(field3) = 'POINT'::text OR field3 IS NULL))],
 'Add geometry field works');

my $drop_field = SQL::Translator::Producer::PostgreSQL::drop_field($field1);
is($drop_field, qq[ALTER TABLE mytable DROP COLUMN field3
DELETE FROM geometry_columns WHERE f_table_schema = 'myschema' AND f_table_name = 'mytable' AND f_geometry_column = 'field3'], 'Drop geometry field works');

$table->add_field($field1);
my ($create_table,$fks) = SQL::Translator::Producer::PostgreSQL::create_table($table);
is($create_table,qq[--
-- Table: mytable
--
CREATE TABLE mytable (
  field3 geometry,
  CONSTRAINT "enforce_dims_field3" CHECK ((st_ndims(field3) = 2)),
  CONSTRAINT "enforce_srid_field3" CHECK ((st_srid(field3) = -1)),
  CONSTRAINT "enforce_geotype_field3" CHECK ((geometrytype(field3) = 'POINT'::text OR field3 IS NULL))
);
INSERT INTO geometry_columns VALUES ('','myschema','mytable','field3','2','-1','POINT')],'Create table with geometry works.');

my $rename_table = SQL::Translator::Producer::PostgreSQL::rename_table($table, "table2");
is($rename_table,qq[ALTER TABLE mytable RENAME TO table2
DELETE FROM geometry_columns WHERE f_table_schema = 'myschema' AND f_table_name = 'mytable' AND f_geometry_column = 'field3'
INSERT INTO geometry_columns VALUES ('','myschema','table2','field3','2','-1','POINT')],'Rename table with geometry works.');

$table->name("table2");
my $drop_table = SQL::Translator::Producer::PostgreSQL::drop_table($table);
is($drop_table, qq[DROP TABLE table2 CASCADE
DELETE FROM geometry_columns WHERE f_table_schema = 'myschema' AND f_table_name = 'table2' AND f_geometry_column = 'field3'], 'Drop table with geometry works.');
