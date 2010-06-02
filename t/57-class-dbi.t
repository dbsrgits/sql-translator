#!/usr/bin/perl
# vim: set ft=perl:

use strict;
use Test::More tests => 2;
use Test::SQL::Translator qw(maybe_plan);
use FindBin qw/$Bin/;

use SQL::Translator::Schema::View;
use SQL::Translator::Producer::SQLite;

{
    my $view1 = SQL::Translator::Schema::View->new(
        name   => 'view_foo',
        fields => [qw/id name/],
        sql    => 'SELECT id, name FROM thing',
        extra  => {
            temporary     => 1,
            if_not_exists => 1,
        }
    );
    my $create_opts = { no_comments => 1 };
    my $view1_sql1 =
      [ SQL::Translator::Producer::SQLite::create_view( $view1, $create_opts ) ];

    my $view_sql_replace = [ "CREATE TEMPORARY VIEW IF NOT EXISTS view_foo AS
    SELECT id, name FROM thing" ];
    is_deeply( $view1_sql1, $view_sql_replace, 'correct "CREATE TEMPORARY VIEW" SQL' );

    my $view2 = SQL::Translator::Schema::View->new(
        name   => 'view_foo',
        fields => [qw/id name/],
        sql    => 'SELECT id, name FROM thing',
    );

    my $view1_sql2 =
      [ SQL::Translator::Producer::SQLite::create_view( $view2, $create_opts ) ];
    my $view_sql_noreplace = [ "CREATE VIEW view_foo AS
    SELECT id, name FROM thing" ];
    is_deeply( $view1_sql2, $view_sql_noreplace, 'correct "CREATE VIEW" SQL' );
}
