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

# How many tests
BEGIN { print "1..3\n"; }

$SQL::Translator::DEBUG = 0;

# Our object; uses the default parser and producer
my $tr = SQL::Translator->new;

# The filename, holder for all the data, and the filehandle
my $datafile = "t/data/mysql/Apache-Session-MySQL.sql";
my $data;
my $fh = IO::File->new($datafile);

# Pass filename: simplest way
my $translated_datafile = $tr->translate($datafile);
#warn "Data from filename method is\n$translated_datafile\n\n\n";

# Pass string reference
read($fh, $data, -s $datafile);
my $translated_data = $tr->translate(\$data);
#warn "Data from string is\n$translated_data\n\n\n";

print "not " unless length $translated_datafile;
print "ok 1 # passing string (filename) works\n";

print "not " unless length $translated_data;
print "ok 2 # passing string as SCALAR reference\n";

print "not " unless ($translated_datafile eq $translated_data);
print "ok 3 # from file == from string\n";
