#!/usr/bin/perl
# vim: set ft=perl ts=4 et:
#

# $Source: /home/faga/work/sqlfairy_svn/sqlfairy-cvsbackup/sqlfairy/t/26sybase.t,v $
# $Id: 26sybase.t 1433 2009-01-17 15:10:56Z jawnsy $

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

