#!/usr/bin/perl
# vim: set ft=perl ts=4 et:
#

# $Source: /home/faga/work/sqlfairy_svn/sqlfairy-cvsbackup/sqlfairy/t/40oracle-parser-dbi.t,v $
# $Id: 40oracle-parser-dbi.t,v 1.1 2006-03-09 19:24:32 cahille Exp $

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
