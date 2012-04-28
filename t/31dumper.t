#!/usr/bin/perl
# vim: set ft=perl:
# Test for Dumper producer

use strict;
use File::Temp 'tempfile';
use FindBin qw/$Bin/;
use IPC::Open3;
use SQL::Translator;
use Test::More;
use Test::SQL::Translator qw(maybe_plan);
use Symbol qw(gensym);

BEGIN {
    maybe_plan(
        5,
        'DBI',
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

like( $output, qr{DBI->connect\(\s*'$dsn',\s*'$db_user',\s*'$db_pass',},
    'Script contains correct DSN, db user and password' );

like( $output, qr/table_name\s*=>\s*'person',/, 'Found "person" table' );
unlike( $output, qr/table_name\s*=>\s*'pet',/, 'Skipped "pet" table' );

my ( $fh, $filename ) = tempfile( 'XXXXXXXX' );

print $fh $output;
close $fh or die "Can't close file '$filename': $!";

my $out;
my $pid = open3( undef, $out, undef, $^X, '-cw', $filename );
my $res = do { local $/; <$out> };
waitpid($pid, 0);

like( $res, qr/syntax OK/, 'Generated script syntax is OK' );

unlink $filename;
