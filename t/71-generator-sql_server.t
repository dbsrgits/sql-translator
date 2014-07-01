use strict;
use warnings;

use Test::More;

use SQL::Translator::Generator::DDL::SQLServer;
use SQL::Translator::Schema::Field;
use SQL::Translator::Schema::Table;

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

my $table = SQL::Translator::Schema::Table->new(
    name => 'mytable',
);

$table->add_field(
    name => 'myenum',
    data_type => 'enum',
    extra => { list => [qw(foo ba'r)] },
);

like $shim->table($table),
     qr/\b\QCONSTRAINT [myenum_chk] CHECK ([myenum] IN ('foo','ba''r'))\E/,
     'enum constraint is generated and escaped correctly';

done_testing;

