#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::SQL::Translator;
use SQL::Translator;
use SQL::Translator::Diff;

maybe_plan(undef, 'DBD::Pg');

my ( $pg_tst, $ddl, $ret, $dsn, $user, $pass );
if ($ENV{DBICTEST_PG_DSN}) {
    ($dsn, $user, $pass) = map { $ENV{"DBICTEST_PG_$_"} } qw(DSN USER PASS);
}
else {
    no warnings 'once';
    maybe_plan(undef, 'Test::PostgreSQL');
    $pg_tst = eval { Test::PostgreSQL->new }
        or plan skip_all => "Can't create test database: $Test::PostgreSQL::errstr";
    $dsn = $pg_tst->dsn;
};

my $dbh = DBI->connect($dsn, $user, $pass, { RaiseError => 1, AutoCommit => 1 });
$dbh->do('SET client_min_messages=warning');

my $source_ddl = <<DDL;
CREATE TABLE sqlt_test_foo (
    pk  SERIAL PRIMARY KEY,
    bar VARCHAR(10)
);
DDL

ok( $ret = $dbh->do($source_ddl), "create table" );

ok( $ret = $dbh->do(q| INSERT INTO sqlt_test_foo (bar) VALUES ('buzz') |), "insert data" );

cmp_ok( $ret, '==', 1, "one row inserted" );

my $target_ddl = <<DDL;
CREATE TABLE sqlt_test_fluff (
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

my $table = $target_sqlt->get_table('sqlt_test_fluff');
$table->extra( renamed_from => 'sqlt_test_foo' );
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
    lives_ok { $dbh->do($line) } "$line";
}

ok ( $ret = $dbh->selectall_arrayref(q(SELECT biff FROM sqlt_test_fluff), { Slice => {} }), "query DB for data" );

cmp_ok( scalar(@$ret), '==', 1, "Got 1 row");

cmp_ok( $ret->[0]->{biff}, 'eq', 'buzz', "col biff has value buzz" );

# Make sure Test::PostgreSQL can kill Pg
undef $dbh if $pg_tst;

END {
    if ($dbh && !$pg_tst) {
        $dbh->do("drop table if exists sqlt_test_$_") foreach qw(foo fluff);
    }
    elsif( $pg_tst ) {
        # do the teardown ourselves, work around RT#108460
        local $?;
        $pg_tst->stop;
        1;
    }
}

done_testing;
