#!/usr/bin/perl
# vim: set ft=perl:

use strict;
use Config;
use FindBin qw/$Bin/;
use Test::More;
use File::Temp 'tempfile';
use SQL::Translator;
use Test::SQL::Translator qw(maybe_plan);

BEGIN {
    maybe_plan(
        5, 
        'SQL::Translator::Parser::SQLite',
        'SQL::Translator::Producer::Dumper'
    );
}

my $db_user         = 'nomar';
my $db_pass         = 'gos0X!';
my $dsn             = 'dbi:SQLite:dbname=/tmp/foo';
my $file            = "$Bin/data/sqlite/create.sql";
my $t               = SQL::Translator->new(
    from            => 'SQLite',
    to              => 'Dumper',
    producer_args   => {
        skip        => 'pet',
        skiplike    => '',
        db_user     => $db_user,
        db_password => $db_pass,
        dsn         => $dsn,
    }
);

my $output = $t->translate( $file );

ok( $output, 'Got dumper script' );

my ( $fh, $filename ) = tempfile( 'XXXXXXXX' );

print $fh $output;

my $perl = $Config{'perlpath'};
my $cmd  = "$perl -cw $filename";
my $res  = `$cmd 2>&1`;
like( $res, qr/syntax OK/, 'Generated script syntax is OK' );

like( $output, qr{DBI->connect\(\s*'$dsn',\s*'$db_user',\s*'$db_pass',},
    'Script contains correct DSN, db user and password' );

like( $output, qr/table_name\s*=>\s*'person',/, 'Found "person" table' );
unlike( $output, qr/table_name\s*=>\s*'pet',/, 'Skipped "pet" table' );

unlink $filename;
