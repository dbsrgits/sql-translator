#!/usr/bin/perl
# vim: set ft=perl:

use strict;

use SQL::Translator;
use Test::More tests => 25;

my ($tr, $ret);

my %format_X_name = (
    format_table_name   => sub { "table_$_[0]"   },
    format_package_name => sub { "package_$_[0]" },
    format_fk_name      => sub { "fk_$_[0]"      },
    format_pk_name      => sub { "pk_$_[0]"      },
);

ok($tr = SQL::Translator->new);

is(($ret = $tr->format_table_name("foo")), "foo",
    '$tr->format_table_name("foo") == "foo"');
is(($ret = $tr->format_package_name("foo")), "foo",
    '$tr->format_package_name("foo") == "foo"');
is(($ret = $tr->format_fk_name("foo")), "foo",
    '$tr->format_fk_name("foo") == "foo"');
is(($ret = $tr->format_pk_name("foo")), "foo",
    '$tr->format_pk_name("foo") == "foo"');

ok($tr->format_table_name($format_X_name{format_table_name}),
    '$tr->format_table_name(sub { "table_$_[0]" })');
is(($ret = $tr->format_table_name("foo")), "table_foo",
    '$tr->format_table_name("foo") == "table_foo"');

ok($tr->format_package_name($format_X_name{format_package_name}),
    '$tr->format_package_name(sub { "package_$_[0]" })');
is(($ret = $tr->format_package_name("foo")), "package_foo",
    '$tr->format_package_name("foo") == "package_foo"');

ok($tr->format_fk_name($format_X_name{format_fk_name}),
    '$tr->format_fk_name(sub { "fk_$_[0]" })');
is(($ret = $tr->format_fk_name("foo")), "fk_foo",
    '$tr->format_fk_name("foo") == "fk_foo"');

ok($tr->format_pk_name($format_X_name{format_pk_name}),
    '$tr->format_pk_name(sub { "pk_$_[0]" })');
is(($ret = $tr->format_pk_name("foo")), "pk_foo",
    '$tr->format_pk_name("foo") == "pk_foo"');


ok($tr->format_table_name($format_X_name{format_table_name}),
    '$tr->format_table_name(sub { "table_$_[0]" })');
is(($ret = $tr->format_table_name("foo")), "table_foo",
    '$tr->format_table_name("foo") == "table_foo"');

ok($tr->format_package_name($format_X_name{format_package_name}),
    '$tr->format_package_name(sub { "package_$_[0]" })');
is(($ret = $tr->format_package_name("foo")), "package_foo",
    '$tr->format_package_name("foo") == "package_foo"');

ok($tr->format_fk_name($format_X_name{format_fk_name}),
    '$tr->format_fk_name(sub { "fk_$_[0]" })');
is(($ret = $tr->format_fk_name("foo")), "fk_foo",
    '$tr->format_fk_name("foo") == "fk_foo"');

ok($tr->format_pk_name($format_X_name{format_pk_name}),
    '$tr->format_pk_name(sub { "pk_$_[0]" })');
is(($ret = $tr->format_pk_name("foo")), "pk_foo",
    '$tr->format_pk_name("foo") == "pk_foo"');

is(($ret = $tr->format_table_name($format_X_name{format_table_name}, "foo")), "table_foo",
    '$tr->format_table_name(sub { "table_$_[0]" }, "foo") == "table_foo"');

is(($ret = $tr->format_package_name($format_X_name{format_package_name}, "foo")), "package_foo",
    '$tr->format_package_name(sub { "package_$_[0]" }, "foo") == "package_foo"');

is(($ret = $tr->format_fk_name($format_X_name{format_fk_name}, "foo")), "fk_foo",
    '$tr->format_fk_name(sub { "fk_$_[0]" }, "foo") == "fk_foo"');

is(($ret = $tr->format_pk_name($format_X_name{format_pk_name}, "foo")), "pk_foo",
    '$tr->format_pk_name(sub { "pk_$_[0]" }, "foo") == "pk_foo"');
