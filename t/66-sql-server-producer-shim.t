use strict;
use warnings;

use Test::More;

use SQL::Translator::Shim::Producer::SQLServer;
use aliased 'SQL::Translator::Schema::Field';

my $shim = SQL::Translator::Shim::Producer::SQLServer->new();

is $shim->field(Field->new(
   name => 'lol',
   data_type => 'int',
)), '[lol] int NULL', 'simple field is generated correctly';

is $shim->field(Field->new(
   name => 'nice',
   data_type => 'varchar',
   size => 10,
)), '[nice] varchar(10) NULL', 'sized field is generated correctly';

done_testing;

