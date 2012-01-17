use strict;
use Test::More;
use Test::SQL::Translator qw(maybe_plan);

BEGIN {
    maybe_plan(1,
        'SQL::Translator::Parser::DBI::Oracle',
    );
}

use_ok('SQL::Translator::Parser::DBI::Oracle');

1;
