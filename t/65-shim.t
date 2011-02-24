use strict;
use warnings;

use Test::More;

use SQL::Translator::Shim;

my $shim = SQL::Translator::Shim->new(
   quote_chars => ['[', ']'],
);

is $shim->quote('frew'), '[frew]', 'simple quote works';
is $shim->quote('people.frew'), '[people].[frew]', 'namespaced quote works';

my $single_shim = SQL::Translator::Shim->new(
   quote_chars => q(|),
);

is $single_shim->quote('frew'), '|frew|', 'simple single quote works';
is $single_shim->quote('people.frew'), '|people|.|frew|', 'namespaced single quote works';

my $no_shim = SQL::Translator::Shim->new();

is $no_shim->quote('frew'), 'frew', 'simple no quote works';
is $no_shim->quote('people.frew'), 'people.frew', 'namespaced no quote works';

done_testing;
