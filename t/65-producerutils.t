use strict;
use warnings;

use Test::More;

use SQL::Translator::ProducerUtils;

my $util = SQL::Translator::ProducerUtils->new(
   quote_chars => ['[', ']'],
);

is $util->quote('frew'), '[frew]', 'simple quote works';
is $util->quote('people.frew'), '[people].[frew]', 'namespaced quote works';

my $single_util = SQL::Translator::ProducerUtils->new(
   quote_chars => q(|),
);

is $single_util->quote('frew'), '|frew|', 'simple single quote works';
is $single_util->quote('people.frew'), '|people|.|frew|', 'namespaced single quote works';

my $no_util = SQL::Translator::ProducerUtils->new();

is $no_util->quote('frew'), 'frew', 'simple no quote works';
is $no_util->quote('people.frew'), 'people.frew', 'namespaced no quote works';

done_testing;
