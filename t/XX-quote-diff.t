use v5.24.0;
use warnings;

use SQL::Translator;
use SQL::Translator::Diff;

use Test::More;

sub schema_pair {
  my $y1 = <<'Y1';
---
schema:
  tables:
    foo:
      name: foo
      fields:
        foo: { order: 1, name: foo, data_type: varchar, size: 36 }
Y1

  my $y2 = <<'Y2';
---
schema:
  tables:
    foo:
      name: foo
      fields:
        foo: { order: 1, name: foo, data_type: varchar, size: 36 }
        bar: { order: 2, name: bar, data_type: varchar, size: 36 }
Y2

  my $t1 = SQL::Translator->new(parser => "YAML", quote_identifiers => 1);
  $t1->translate(\$y1);

  my $t2 = SQL::Translator->new(parser => "YAML", quote_identifiers => 1);
  $t2->translate(\$y2);

  return ($t1->schema, $t2->schema);
}

for my $test (
  [ MySQL       => sub { "`$_[0]`" }   ],
  [ PostgreSQL  => sub { qq{"$_[0]"} } ],
  [ SQLite      => sub { qq{"$_[0]"} } ],
) {
  my ($producer, $q) = @$test;

  my ($s1, $s2) = schema_pair;

  my $sql = SQL::Translator::Diff::schema_diff(
    $s1, $producer,
    $s2, $producer,
    { producer_args => { quote_identifiers => 1 } },
  );

  my $quoted = $q->('bar');
  like(
    $sql,
    qr{ADD COLUMN \Q$quoted\E},
    "$producer: new column name is quoted",
  );
}

done_testing;
