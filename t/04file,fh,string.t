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

# Our object; uses the default parser and producer
my $tr = SQL::Translator->new;

# The filename, holder for all the data, and the filehandle
my $datafile = "t/data/mysql/Apache-Session-MySQL.sql";
my $data;
my $fh = IO::File->new($datafile);

# Pass filename: simplest way
my $translated_datafile = $tr->translate($datafile);
warn "Data from filename method is\n$translated_datafile\n\n\n";

# Pass string reference
read($fh, $data, -s $datafile);
my $translated_data = $tr->translate(\$data);
warn "Data from string is\n$translated_data\n\n\n";


# Pass IO::File instance
$fh->setpos(0);
my $translated_fh = $tr->translate($fh);
warn "Data from filehandle method is\n$translated_fh\n\n\n";

# With all that setup out of the way, we can perform the actual tests.
# We need to test the equality of:
#
#   filename and string
#   filename and filehandle
#   filehandle and string
#
# And then we have all possibilities.  Note that the order in which
# the comparison is done is pretty arbitrary, and doesn't affect the
# outcomes.  Similarly, the order of the eq tests is also unimportant.
#
print "not " unless ($translated_datafile eq $translated_fh);
print "ok 1 # from file == from filehandle\n";
    
print "not " unless ($translated_datafile eq $translated_data);
print "ok 2 # from file == from string\n";

print "not " unless ($translated_data     eq $translated_fh);
print "ok 3 # from string == from filehandle\n";

# For this test, we should devise some other sort of output routine,
# that can take a data structure and output it in a reasonable -- and
# machine parsable! -- way. 
