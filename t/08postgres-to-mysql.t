#!/usr/local/bin/perl
# vim: set ft=perl:

use strict;
use Test::More;
use SQL::Translator;
use Data::Dumper;
use Test::SQL::Translator qw(maybe_plan);

BEGIN {
    maybe_plan(1, 
        'SQL::Translator::Parser::MySQL',
        'SQL::Translator::Producer::PostgreSQL');
}

my $create = q|

-- The cvterm module design is based on the ontology 

-- ================================================
-- TABLE: cv
-- ================================================

create table cv (
       cv_id serial not null,
       primary key (cv_id),
       cvname varchar not null,
       cvdefinition text,

       unique(cvname)
);

-- ================================================
-- TABLE: cvterm
-- ================================================

create table cvterm (
       cvterm_id serial not null,
       primary key (cvterm_id),
       cv_id int not null,
       foreign key (cv_id) references cv (cv_id),
       name varchar(255) not null,
       termdefinition text,
       dbxref_id int,
       foreign key (dbxref_id) references dbxref (dbxref_id),

       unique(termname, cv_id)
);
create index cvterm_idx1 on cvterm (cv_id);
-- the primary dbxref for this term.  Other dbxrefs may be cvterm_dbxref
-- The unique key on termname, termtype_id ensures that all terms are 
-- unique within a given cv


COMMENT ON TABLE cvterm IS
 'A term, class or concept within an ontology
  or controlled vocabulary';
COMMENT ON COLUMN cvterm.cv_id IS
 'The cv/ontology/namespace to which this cvterm belongs';
COMMENT ON COLUMN cvterm.name IS
 'A concise human-readable name describing the meaning of the cvterm';
COMMENT ON COLUMN cvterm.termdefinition IS
 'A human-readable text definition';
COMMENT ON COLUMN cvterm.dbxref_id IS
 'A human-readable text definition';
COMMENT ON INDEX cvterm_c1 IS 
 'the OBO identifier is globally unique';


-- ================================================
-- TABLE: cvrelationship
-- ================================================

create table cvrelationship (
       cvrelationship_id serial not null,
       primary key (cvrelationship_id),
       reltype_id int not null,
       foreign key (reltype_id) references cvterm (cvterm_id),
       subjterm_id int not null,
       foreign key (subjterm_id) references cvterm (cvterm_id),
       objterm_id int not null,
       foreign key (objterm_id) references cvterm (cvterm_id),

       unique(reltype_id, subjterm_id, objterm_id)
);
create index cvrelationship_idx1 on cvrelationship (reltype_id);
create index cvrelationship_idx2 on cvrelationship (subjterm_id);
create index cvrelationship_idx3 on cvrelationship (objterm_id);


-- ================================================
-- TABLE: cvpath
-- ================================================

create table cvpath (
       cvpath_id serial not null,
       primary key (cvpath_id),
       reltype_id int,
       foreign key (reltype_id) references cvterm (cvterm_id),
       subjterm_id int not null,
       foreign key (subjterm_id) references cvterm (cvterm_id),
       objterm_id int not null,
       foreign key (objterm_id) references cvterm (cvterm_id),
       cv_id int not null,
       foreign key (cv_id) references cv (cv_id),
       pathdistance int,

       unique (subjterm_id, objterm_id)
);
create index cvpath_idx1 on cvpath (reltype_id);
create index cvpath_idx2 on cvpath (subjterm_id);
create index cvpath_idx3 on cvpath (objterm_id);
create index cvpath_idx4 on cvpath (cv_id);


-- ================================================
-- TABLE: cvtermsynonym
-- ================================================

create table cvtermsynonym (
       cvterm_id int not null,
       foreign key (cvterm_id) references cvterm (cvterm_id),
       termsynonym varchar(255) not null,

       unique(cvterm_id, termsynonym)
);

-- The table "cvterm_synonym" doesn't exist, so 
-- creating an index on it screws things up!
-- create index cvterm_synonym_idx1 on cvterm_synonym (cvterm_id);

-- ================================================
-- TABLE: cvterm_dbxref
-- ================================================

create table cvterm_dbxref (
       cvterm_dbxref_id serial not null,
       primary key (cvterm_dbxref_id),
       cvterm_id int not null,
       foreign key (cvterm_id) references cvterm (cvterm_id),
       dbxref_id int not null,
       foreign key (dbxref_id) references dbxref (dbxref_id),

       unique(cvterm_id, dbxref_id)
);
create index cvterm_dbxref_idx1 on cvterm_dbxref (cvterm_id);
create index cvterm_dbxref_idx2 on cvterm_dbxref (dbxref_id);

-- ================================================
-- TABLE: cvterm_geom
-- ================================================

create table cvterm_geom (
       cvterm_geom_id serial not null,
       primary key (cvterm_geom_id),
       cvterm_id int not null,
       foreign key (cvterm_id) references cvterm (cvterm_id),
       cvterm_geom geometry,
	   constraint "enforce_dims_cvterm_geom" CHECK ((st_ndims(cvterm_geom) = 2)),
	   constraint "enforce_srid_cvterm_geom" CHECK ((st_srid(cvterm_geom) = -1)),
	   constraint "enforce_geotype_cvterm_geom" CHECK ((geometrytype(cvterm_geom) = 'POINT'::text OR cvterm_geom IS NULL)),
       unique(cvterm_id)
);


|;

my $tr = SQL::Translator->new(
    parser   => "PostgreSQL",
    producer => "MySQL"
);

ok( $tr->translate(\$create), 'Translate PG2My' ) or diag($tr->error);
