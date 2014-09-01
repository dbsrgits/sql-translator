#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::SQL::Translator;
use SQL::Translator;
use SQL::Translator::Diff;

maybe_plan(10, 'DBD::Pg', 'Test::PostgreSQL');

my ( $pgsql, $dbh , $ddl, $ret );

no warnings "once";
$pgsql = Test::PostgreSQL->new() or die $Test::PostgreSQL::errstr;
$dbh = DBI->connect($pgsql->dsn,'','', { RaiseError => 1 }) or die $DBI::errstr;
use warnings "once";

my $source_ddl = <<DDL;
CREATE TABLE foo (
    pk  SERIAL PRIMARY KEY,
    bar VARCHAR(10)
);
DDL

ok( $ret = $dbh->do($source_ddl), "create table" );

ok( $ret = $dbh->do(q| INSERT INTO foo (bar) VALUES ('buzz') |), "insert data" );

cmp_ok( $ret, '==', 1, "one row inserted" );

my $target_ddl = <<DDL;
CREATE TABLE fluff (
    pk   SERIAL PRIMARY KEY,
    biff VARCHAR(10)
);
DDL

my $source_sqlt = SQL::Translator->new(
    no_comments => 1,
    parser   => 'SQL::Translator::Parser::PostgreSQL',
)->translate(\$source_ddl);

my $target_sqlt = SQL::Translator->new(
    no_comments => 1,
    parser   => 'SQL::Translator::Parser::PostgreSQL',
)->translate(\$target_ddl);

my $table = $target_sqlt->get_table('fluff');
$table->extra( renamed_from => 'foo' );
my $field = $table->get_field('biff');
$field->extra( renamed_from => 'bar' );

my @diff = SQL::Translator::Diff->new({
    output_db => 'PostgreSQL',
    source_schema => $source_sqlt,
    target_schema => $target_sqlt,
})->compute_differences->produce_diff_sql;

foreach my $line (@diff) {
    $line =~ s/\n//g;
    next if $line =~ /^--/;
    ok( $dbh->do($line), "$line" );
}

ok ( $ret = $dbh->selectall_arrayref(q(SELECT biff FROM fluff), { Slice => {} }), "query DB for data" );

cmp_ok( scalar(@$ret), '==', 1, "Got 1 row");

cmp_ok( $ret->[0]->{biff}, 'eq', 'buzz', "col biff has value buzz" );
