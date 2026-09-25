#!/usr/bin/perl
use warnings;
use strict;

use Test::More;
use Test::Differences;
use Test::Warn;
use YAML qw(Load);

use_ok("SQL::Translator");
use_ok("SQL::Translator::Parser::SQLite");
use_ok("SQL::Translator::Producer::PostgreSQL");

# Test conversion of case-insensitive fields where possible. Although
# case-sensitivity generally depends on the collation of a databases character
# set, there are some case-specific options that are included here.

# SQLite specifically has the field option COLLATE NOCASE
my $sqlite_original = 'BEGIN TRANSACTION;

CREATE TABLE "my_text_table" (
  "mytext" TEXT NOT NULL COLLATE NOCASE,
  "myvarchar" VARCHAR(16) NOT NULL COLLATE NOCASE,
  "mychar" CHAR(16) NOT NULL COLLATE NOCASE
);

COMMIT;
';

# For this test, the standard text field is converted (into citext). However,
# the other 2 text-like fields (CHAR and VARCHAR) do not have a direct
# equivalent. These 2 therefore remain the same, although because the SQLite
# parser will have flagged them as case-insensitive, the PostgreSQL generator
# will warn as such.
my $expected_warning = { carped => 'Only text fields can be used with is_case_insensitive option' };
my $postgresql;
warnings_are sub {
    $postgresql = SQL::Translator->new(data => $sqlite_original, no_comments => 1, quote_identifiers => 1)
        ->translate(from => 'SQLite', to => 'PostgreSQL')
}, [$expected_warning, $expected_warning], "Expected warning for incompatible fields";

# PostgreSQL has the plugin citext
eq_or_diff($postgresql, <<'DDL', 'Conversion from SQLite to PostgreSQL');
CREATE TABLE "my_text_table" (
  "mytext" citext NOT NULL,
  "myvarchar" character varying(16) NOT NULL,
  "mychar" character(16) NOT NULL
);

DDL

# Test the option stored in YAML
my $yaml = SQL::Translator->new(data => $sqlite_original, no_comments => 1, quote_identifiers => 1)
    ->translate(from => 'SQLite', to => 'YAML');

my $yaml_parsed = Load($yaml);
my $fields = $yaml_parsed->{schema}->{tables}->{my_text_table}->{fields};
ok($fields->{mytext}, "YAML: normal text is case-insensitive");
ok($fields->{myvarchar}, "YAML: variable char is case-insensitive");
ok($fields->{mychar}, "YAML: fixed char is case-insensitive");

# Convert back from YAML to SQLite
my $sqlite_converted = SQL::Translator->new(data => $yaml, no_comments => 1, quote_identifiers => 1)
    ->translate(from => 'YAML', to => 'SQLite');

eq_or_diff($sqlite_converted, $sqlite_original);

# Convert back from PostgreSQL, although only text is applicable
$postgresql = 'CREATE TABLE "my_text_table" (
  "mytext" citext NOT NULL
);';

$sqlite_converted = SQL::Translator->new(data => $postgresql, no_comments   => 1, quote_identifiers => 1)
    ->translate(from => 'PostgreSQL', to => 'SQLite');

eq_or_diff($sqlite_converted, <<'DDL', 'DDL with default quoting');
BEGIN TRANSACTION;

CREATE TABLE "my_text_table" (
  "mytext" text NOT NULL COLLATE NOCASE
);

COMMIT;
DDL

done_testing;

