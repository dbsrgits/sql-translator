#!/usr/bin/perl -w

# -------------------------------------------------------------------
# $Id: sql_translator.pl,v 1.12 2003-08-20 13:50:46 dlc Exp $
# -------------------------------------------------------------------
# Copyright (C) 2002 Ken Y. Clark <kycl4rk@users.sourceforge.net>,
#                    darren chamberlain <darren@cpan.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
# 02111-1307  USA
# -------------------------------------------------------------------

use strict;
use Getopt::Long;
use Pod::Usage;
use SQL::Translator;

use Data::Dumper;

use vars qw( $VERSION );
$VERSION = sprintf "%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/;

my $from;             # the original database
my $to;               # the destination database 
my $help;             # show POD and bail
my $stdin;            # whether to read STDIN for create script
my $no_comments;      # whether to put comments in out file
my $show_warnings;    # whether to show warnings from SQL::Translator
my $add_drop_table;   # whether to show warnings from SQL::Translator
my $debug;            # whether to print debug info
my $trace;            # whether to print parser trace
my $list;             # list all parsers and producers
my $no_trim;          # don't trim whitespace on xSV fields
my $no_scan;          # don't scan xSV fields for data types and sizes
my $field_separator;  # for xSV files
my $record_separator; # for xSV files
my $validate;         # whether to validate the parsed document
my $imap_file;        # filename where to place image map coords
my $imap_url;         # URL to use in making image map
my $pretty;           # use CGI::Pretty instead of CGI (HTML producer)

#
# Get options, explain how to use the script if necessary.
#
GetOptions(
    'f|from|parser:s' => \$from,
    't|to|producer:s' => \$to,
    'h|help'          => \$help,
    'l|list'          => \$list,
    'd|debug'         => \$debug,
    'trace'           => \$trace,
    'no-comments'     => \$no_comments,
    'show-warnings'   => \$show_warnings,
    'add-drop-table'  => \$add_drop_table,
    'v|validate'      => \$validate,
    'no-trim'         => \$no_trim,
    'no-scan'         => \$no_scan,
    'fs:s'            => \$field_separator,
    'rs:s'            => \$record_separator,
    'imap-file:s'     => \$imap_file,
    'imap-url:s'      => \$imap_url,
    'pretty!'         => \$pretty,
) or pod2usage(2);

my @files = @ARGV; # the create script(s) for the original db

pod2usage(1) if $help;

#
# If everything is OK, translate file(s).
#
my $translator      =  SQL::Translator->new( 
    debug           => $debug          ||  0,
    trace           => $trace          ||  0,
    no_comments     => $no_comments    ||  0,
    show_warnings   => $show_warnings  ||  0,
    add_drop_table  => $add_drop_table ||  0,
    validate        => $validate       ||  0,
    parser_args     => {
        trim_fields      => $no_trim ? 0 : 1,
        scan_fields      => $no_scan ? 0 : 1,
        field_separator  => $field_separator,
        record_separator => $record_separator,
    },
    producer_args   => {
        imap_file        => $imap_file,
        imap_url         => $imap_url,
        pretty           => $pretty,
    },
);

if ( $list ) {
    my @parsers   = $translator->list_parsers;
    my @producers = $translator->list_producers;

    for ( @parsers, @producers ) {
        if ( $_ =~ m/.+::(\w+)\.pm/ ) {
            $_ = $1;
        }
    }
    
    print "\nParsers:\n",   map { "\t$_\n" } sort @parsers;
    print "\nProducers:\n", map { "\t$_\n" } sort @producers;
    print "\n";
    exit(0);
}

pod2usage(2) unless $from && $to && @files;

$translator->parser($from);
$translator->producer($to);

for my $file (@files) {
    my $output = $translator->translate(file => $file) or die
        "Error: " . $translator->error;
    print $output;
}

# ----------------------------------------------------
# It is not all books that are as dull as their readers.
# Henry David Thoreau
# ----------------------------------------------------

=head1 NAME

sql_translator.pl - convert an SQL database schema

=head1 SYNOPSIS

For help:

  ./sql_translator.pl -h|--help

For a list of all parsers and producers: 

  ./sql_translator.pl -l|--list

To translate a schema:

  ./sql_translator.pl 
        -f|--from|--parser MySQL 
        -t|--to|--producer Oracle 
        [options] 
        file

  Options:

    -d|--debug            Print debug info
    -v|--validate         Validate the schema
    --trace               Print parser trace info
    --no-comments         Don't include comments in SQL output
    --show-warnings       Print to STDERR warnings of conflicts, etc.
    --add-drop-table      Add 'drop table' statements before creates

  xSV Options:

    --fs                  The field separator
    --rs                  The record separator
    --no-trim             Don't trim whitespace on fields 
    --no-scan             Don't scan fields for data types and sizes 

  Diagram Options:

    --imap-file           Filename to put image map data
    --imap-url            URL to use for image map

=head1 DESCRIPTION

This script is part of the SQL Fairy project
(http://sqlfairy.sourceforge.net/).  It will try to convert any
database syntax for which it has a grammar into some other format it
knows about.

If using "show-warnings," be sure to redirect STDERR to a separate file.  
In bash, you could do this:

    $ sql_translator.pl -f MySQL -t PostgreSQL --show-warnings file.sql \
       1>out 2>err

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=head1 SEE ALSO

SQL::Translator.

=cut
