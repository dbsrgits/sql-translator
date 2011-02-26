use strict;
use warnings;

use Test::More;

use SQL::Translator::Generator::DDL::SQLServer;
use SQL::Translator::Schema::Field;

my $shim = SQL::Translator::Generator::DDL::SQLServer->new();

is $shim->field(SQL::Translator::Schema::Field->new(
   name => 'lol',
   data_type => 'int',
)), '[lol] int NULL', 'simple field is generated correctly';

is $shim->field(SQL::Translator::Schema::Field->new(
   name => 'nice',
   data_type => 'varchar',
   size => 10,
)), '[nice] varchar(10) NULL', 'sized field is generated correctly';

done_testing;

