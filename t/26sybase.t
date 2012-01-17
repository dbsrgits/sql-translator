use strict;
use Test::More;
use Test::SQL::Translator qw(maybe_plan);

BEGIN {
    maybe_plan(3,
        'SQL::Translator::Parser::DBI::Sybase',
    );
}

use_ok('SQL::Translator::Parser::DBI::Sybase');
use_ok('SQL::Translator::Parser::Storable');
use_ok('SQL::Translator::Producer::Storable');

1;

