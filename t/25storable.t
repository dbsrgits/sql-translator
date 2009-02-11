#!/usr/local/bin/perl
# vim: set ft=perl:

# $Source: /home/faga/work/sqlfairy_svn/sqlfairy-cvsbackup/sqlfairy/t/25storable.t,v $
# $Id: 25storable.t 1433 2009-01-17 15:10:56Z jawnsy $

use Test::More tests => 2;

use_ok('SQL::Translator::Parser::Storable');
use_ok('SQL::Translator::Producer::Storable');

1;

