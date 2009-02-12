# $Source: /home/faga/work/sqlfairy_svn/sqlfairy-cvsbackup/sqlfairy/t/40oracle-parser-dbi.t,v $
# $Id$

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
