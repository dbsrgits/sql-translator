#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use DBI;
use SQL::Translator;
use SQL::Translator::Parser::SQLite;
use SQL::Translator::Diff;

eval "use DBD::SQLite";
plan skip_all => "DBD::SQLite required" if $@;

my ( $dbh , $ddl, $ret );

lives_ok { $dbh = DBI->connect("dbi:SQLite:dbname=:memory:")} "dbi connect";

my $source_ddl = <<DDL;
CREATE TABLE "Foo" (
    "foo" INTEGER PRIMARY KEY AUTOINCREMENT,
    "bar" VARCHAR(10)
);
DDL

lives_ok { $ret = $dbh->do($source_ddl) } "create table";

lives_ok { $ret = $dbh->do(q| INSERT INTO Foo (bar) VALUES ('buzz') |) } "insert data";

cmp_ok( $ret, '==', 1, "one row inserted" );

my $target_ddl = <<DDL;
CREATE TABLE "Foo" (
    "foo" INTEGER PRIMARY KEY AUTOINCREMENT,
    "biff" VARCHAR(10)
);
DDL

my $source_sqlt = SQL::Translator->new(
    no_comments => 1,
    parser   => 'SQL::Translator::Parser::SQLite',
)->translate(\$source_ddl);

my $target_sqlt = SQL::Translator->new(
    no_comments => 1,
    parser   => 'SQL::Translator::Parser::SQLite',
)->translate(\$target_ddl);

my $table = $target_sqlt->get_table('Foo');
my $field = $table->get_field('biff');
$field->extra( renamed_from => 'bar' );

my @diff = SQL::Translator::Diff->new({
    output_db => 'SQLite',
    source_schema => $source_sqlt,
    target_schema => $target_sqlt,
})->compute_differences->produce_diff_sql;

foreach my $line (@diff) {
    $line =~ s/\n//g;
    lives_ok { $dbh->do($line) || die } "$line";
}

lives_ok { $ret = $dbh->selectall_arrayref(q(SELECT biff FROM Foo), { Slice => {} }) } "query DB for data";

cmp_ok( scalar(@$ret), '==', 1, "Got 1 row");

cmp_ok( $ret->[0]->{biff}, 'eq', 'buzz', "col biff has value buzz" );

done_testing;
