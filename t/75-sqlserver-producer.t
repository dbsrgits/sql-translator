#!/usr/bin/perl -w
# vim:filetype=perl

use strict;
use Test::More;
use Test::SQL::Translator qw(maybe_plan);

use FindBin qw/$Bin/;

BEGIN {
  maybe_plan(2, 'YAML', 'SQL::Translator::Producer::SQLServer', 'Test::Differences',);
}
use Test::Differences;
use SQL::Translator;

# Simple table in YAML format to test basic functionality
my $yaml_in = <<EOSCHEMA;
---
schema:
  tables:
    thing2:
      name: some.thing2
      extra:
      order: 2
      fields:
        id:
          name: id
          data_type: int
          is_primary_key: 0
          order: 1
          is_foreign_key: 1
        foo:
          name: foo
          data_type: int
          order: 2
          is_not_null: 1
        foo2:
          name: foo2
          data_type: int
          order: 3
          is_not_null: 1
        bar_set:
          name: bar_set
          data_type: set
          order: 4
          is_not_null: 1
          extra:
            list:
              - foo
              - bar
              - ba'z
      indices:
        - type: NORMAL
          fields:
            - name: id
              prefix_length: 10
          name: index_1
        - type: NORMAL
          fields:
            - id
          name: really_long_name_bigger_than_64_chars_aaaaaaaaaaaaaaaaaaaaaaaaaaa
      constraints:
        - type: PRIMARY_KEY
          fields:
            - id
            - foo
        - reference_table: thing
          type: FOREIGN_KEY
          fields: foo
          name: fk_thing
        - reference_table: thing
          type: FOREIGN_KEY
          fields: foo2
          name: fk_thing

EOSCHEMA

my @stmts = (
  "CREATE TABLE [some].[thing2] (
  [id] int NOT NULL,
  [foo] int NOT NULL,
  [foo2] int NULL,
  [bar_set] set NULL,
  CONSTRAINT [some].[thing2_pk] PRIMARY KEY ([id], [foo])
);\n",    # New line to match generator

  "CREATE INDEX [index_1] ON [some].[thing2] ([id]);\n",    # Where does the new line come from?

  "CREATE INDEX [really_long_name_bigger_than_64_chars_aaaaaaaaaaaaaaaaaaaaaaaaaaa] ON [some].[thing2] ([id]);",
  "ALTER TABLE [some].[thing2] ADD CONSTRAINT [fk_thing] FOREIGN KEY ([foo]) REFERENCES [thing] ();",
  "ALTER TABLE [some].[thing2] ADD CONSTRAINT [fk_thing] FOREIGN KEY ([foo2]) REFERENCES [thing] ();",
);

my $sqlt = SQL::Translator->new(
  show_warnings     => 1,
  no_comments       => 1,
  from              => "YAML",
  to                => "SQLServer",
  quote_table_names => 1,
  quote_field_names => 1
);

my $generator = $sqlt->translate(\$yaml_in)
    or die "Translate error:" . $sqlt->error;
ok $generator ne "", "Produced something!";

my $correct = join("\n", @stmts);
eq_or_diff $correct, $generator, "Scalar output looks correct";
