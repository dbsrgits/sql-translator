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
use Test::More;

plan tests => 3;

# Our object; uses the default parser and producer
my $tr = SQL::Translator->new;

# The filename, holder for all the data, and the filehandle
my $datafile = "t/data/mysql/Apache-Session-MySQL.sql";
my $data;
my $fh = IO::File->new($datafile);

# Pass filename: simplest way
my $translated_datafile = $tr->translate($datafile);

# Pass string reference
read($fh, $data, -s $datafile);
my $translated_data = $tr->translate(\$data);

ok(length $translated_datafile, "passing string (filename) works");
ok(length $translated_data, "passing string as SCALAR reference");
is($translated_datafile, $translated_data, "from file == from string");
