use strict;
use warnings;

use Test::More;
use SQL::Translator;
use SQL::Translator::Diff;
use Test::Differences;

my ($s1, $s2);

subtest 'schema 1' => sub {
   my $translator = SQL::Translator->new(
      no_comments => 1,
   );
   my $output     = $translator->translate(
       from       => 'YAML',
       to         => 'SQLServer',
       filename   => 't/data/diff/pgsql/create1.yml',
   ) ."\n";
   $s1 = $translator->schema;

   my $expected = <<'SQL';
CREATE TABLE [person] (
  [person_id] int NOT NULL,
  [name] varchar(20) NULL,
  [age] int NULL,
  [weight] numeric(11,2) NULL,
  [iq] smallint NULL DEFAULT '0',
  [description] text NULL,
  CONSTRAINT [person_pk] PRIMARY KEY ([person_id])
);

CREATE UNIQUE NONCLUSTERED INDEX [UC_age_name] ON [person] (age) WHERE [age] IS NOT NULL;

CREATE INDEX [u_name] ON [person] ([name]);

CREATE TABLE [employee] (
  [position] varchar(50) NOT NULL,
  [employee_id] int NOT NULL,
  [job_title] varchar(255) NULL,
  CONSTRAINT [employee_pk] PRIMARY KEY ([position], [employee_id])
);

CREATE TABLE [deleted] (
  [id] int NULL
);

CREATE UNIQUE NONCLUSTERED INDEX [pk_id] ON [deleted] (id) WHERE [id] IS NOT NULL;

CREATE TABLE [old_name] (
  [pk] int IDENTITY NOT NULL,
  CONSTRAINT [old_name_pk] PRIMARY KEY ([pk])
);
ALTER TABLE [employee] ADD CONSTRAINT [FK5302D47D93FE702E] FOREIGN KEY ([employee_id]) REFERENCES [person] ([person_id]);
ALTER TABLE [deleted] ADD CONSTRAINT [fk_fake] FOREIGN KEY ([id]) REFERENCES [fake] ([fk_id]);
SQL

   eq_or_diff($output, $expected, 'initial "DDL" converted correctly');
};

subtest 'schema 2' => sub {
   my $translator = SQL::Translator->new(
      no_comments => 1,
   );
   my $output     = $translator->translate(
       from       => 'YAML',
       to         => 'SQLServer',
       filename   => 't/data/diff/pgsql/create2.yml',
   ) ."\n";
   $s2 = $translator->schema;

   my $expected = <<'SQL';
CREATE TABLE [person] (
  [person_id] int IDENTITY NOT NULL,
  [name] varchar(20) NOT NULL,
  [age] int NULL DEFAULT 18,
  [weight] numeric(11,2) NULL,
  [iq] int NULL DEFAULT 0,
  [is_rock_star] smallint NULL DEFAULT '1',
  [physical_description] text NULL,
  CONSTRAINT [person_pk] PRIMARY KEY ([person_id]),
  CONSTRAINT [UC_person_id] UNIQUE ([person_id])
);

CREATE UNIQUE NONCLUSTERED INDEX [UC_age_name] ON [person] (age, name) WHERE [age] IS NOT NULL;

CREATE INDEX [unique_name] ON [person] ([name]);

CREATE TABLE [employee] (
  [position] varchar(50) NOT NULL,
  [employee_id] int NOT NULL,
  CONSTRAINT [employee_pk] PRIMARY KEY ([position], [employee_id])
);

CREATE TABLE [added] (
  [id] int NULL
);

CREATE TABLE [new_name] (
  [pk] int IDENTITY NOT NULL,
  [new_field] int NULL,
  CONSTRAINT [new_name_pk] PRIMARY KEY ([pk])
);
ALTER TABLE [employee] ADD CONSTRAINT [FK5302D47D93FE702E_diff] FOREIGN KEY ([employee_id]) REFERENCES [person] ([person_id]);
SQL

   eq_or_diff($output, $expected, 'initial "DDL" converted correctly');
};

subtest 'sql server diff' => sub {
   my @out = SQL::Translator::Diff::schema_diff(
      $s1, 'SQLServer',
      $s2, 'SQLServer',
   );

   use Devel::Dwarn;
   Dwarn \@out;
};


done_testing;
