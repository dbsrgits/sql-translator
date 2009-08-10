#!/usr/bin/perl
# vim: set ft=perl:
#
# This tests that the same file can be passed in using a filename,
# a filehandle, and a string, and return identical results.  There's
# a lot of setup here, because we have to emulate the various ways
# that $tr->translate might be called:  with a string (filename),
# with a filehandle (IO::File, FileHandle, or \*FOO), and with a
# scalar reference (data in a string).
#

use strict;

use IO::File;
use SQL::Translator;
use Test::More tests => 3;

# The filename, holder for all the data, and the filehandle
my $datafile = "t/data/mysql/Apache-Session-MySQL.sql";
my $data;
my $fh = IO::File->new($datafile);

my ($v1, $v2);
{
    my $tr = SQL::Translator->new;
    # Pass filename: simplest way
    $tr->translate($datafile);
    $v1 = $tr->schema;
}

{
    my $tr = SQL::Translator->new;
    # Pass string reference
    read($fh, $data, -s $datafile);
    $tr->translate(\$data);
    $v2 = $tr->schema;
}

# XXX- Hack to remove Graph hack!
$_->translator (undef) for ($v1, $v2);

ok(length $v1, "passing string (filename) works");
ok(length $v2, "passing string as SCALAR reference");
is_deeply($v1, $v2, "from file == from string");
