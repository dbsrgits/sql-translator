use utf8;
use strict;
use warnings;

use Test::More;
use SQL::Translator;


# Create a new translator object
my $translator = SQL::Translator->new(
    from => 'PostgreSQL',
    to   => 'PostgreSQL',
    quote_identifiers => 0,
);

# Input PostgreSQL schema as a string (you can also use a file)
my $ddl = <<DDL;
  CREATE TABLE test (ID integer);
  CREATE TRIGGER test_utf before insert ON test FOR EACH row
  EXECUTE PROCEDURE foo('перевірка ЮТФ/check UTF');
DDL
my $out = $translator->translate( \$ddl )
   or die "Translation failed: " . $translator->error;

$ddl =~ s/\s//sg;
$out =~ s/^--.*|\s//mg;

is $out, $ddl, "UTF is not broken";

done_testing();
