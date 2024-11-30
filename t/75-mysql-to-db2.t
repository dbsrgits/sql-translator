#!/usr/local/bin/perl
# vim: set ft=perl:

use strict;
use Test::More;
use SQL::Translator;
use Test::SQL::Translator qw(maybe_plan);

my $create = q|
CREATE TABLE random (
    id       INT auto_increment PRIMARY KEY,
    foo      VARCHAR(255) NOT NULL DEFAULT '',
    updated  TIMESTAMP             DEFAULT CURRENT_TIMESTAMP,
    ts2      TIMESTAMP    NOT NULL DEFAULT '1980-01-01 00:00:00',
    nullable CHAR(1)               DEFAULT NULL,
    comments TEXT
);
CREATE UNIQUE INDEX random_foo_update ON random(foo,updated);
CREATE INDEX random_foo ON random(foo);

|;

BEGIN {
  maybe_plan( 7, 'SQL::Translator::Parser::MySQL', 'SQL::Translator::Producer::DB2' );
}

my $tr = SQL::Translator->new( parser => "MySQL", producer => "DB2", quote_table_names => 0, quote_field_names => 0, );

my $output = $tr->translate( \$create );

ok( $output, 'Translate MySQL to DB2' );
ok( $output =~ /id\s+INTEGER\s+GENERATED\s+BY\s+DEFAULT\s+AS\s+IDENTITY\s+\(START\s+WITH\s+1,\s+INCREMENT BY 1\)\s+NOT\s+NULL/i, 'auto_increment translated.' );
ok( $output =~ /CREATE\s+UNIQUE\s+INDEX\s+random_foo_update /i,                                'Unique index definition translated.' );
ok( $output =~ /updated\s+TIMESTAMP\s+DEFAULT\s+CURRENT\s+TIMESTAMP/i,                         'DEFAULT CURRENT_TIMESTAMP is kept' );
ok( $output =~ /comments\s+CLOB/i,                                                             'TEXT is translated to CLOB' );
ok( $output =~ /ts2\s+TIMESTAMP\s+NOT\s+NULL\s+DEFAULT\s+TIMESTAMP\('1980-01-01 00:00:00'\)/i, 'DEFAULT TIMESTAMP is kept' );
ok( $output =~ /nullable\s+CHAR\(1\)\s+DEFAULT\s+NULL/i,                                       'Default NULL value is not quoted' );
