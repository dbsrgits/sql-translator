#!/usr/bin/perl
# vim: set ft=perl ts=4 et:
#

# $Source: /home/faga/work/sqlfairy_svn/sqlfairy-cvsbackup/sqlfairy/t/26sybase.t,v $
# $Id: 26sybase.t,v 1.1 2003-10-08 18:28:36 phrrngtn Exp $

use strict;

use Test::More tests => 3;

use_ok('SQL::Translator::Parser::DBI::Sybase');
use_ok('SQL::Translator::Parser::Storable');
use_ok('SQL::Translator::Producer::Storable');

1;

