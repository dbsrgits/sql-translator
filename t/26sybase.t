#!/usr/bin/perl
# vim: set ft=perl ts=4 et:
#

# $Source: /home/faga/work/sqlfairy_svn/sqlfairy-cvsbackup/sqlfairy/t/26sybase.t,v $
# $Id: 26sybase.t,v 1.2 2004-09-13 18:16:48 kycl4rk Exp $

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

