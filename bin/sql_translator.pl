#!/usr/bin/perl -w

# -------------------------------------------------------------------
# $Id: sql_translator.pl,v 1.5 2002-11-22 03:03:40 kycl4rk Exp $
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
$VERSION = sprintf "%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/;

my $from;        # the original database
my $to;          # the destination database 
my $help;        # show POD and bail
my $stdin;       # whether to read STDIN for create script
my $no_comments; # whether to put comments in out file
my $xlate;       # user overrides for field translation
my $debug;       # whether to print debug info
my $trace;       # whether to print parser trace
my $list;        # list all parsers and producers

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
    'xlate=s'         => \$xlate,
) or pod2usage(2);

my @files = @ARGV; # the create script(s) for the original db

pod2usage(1) if $help;

if ( $xlate ) {
    my @fields = split /,/, $xlate;
    $xlate     = {}; 
    for my $field ( @fields ) {
        my ( $from, $to ) = split(/\//, $field);
        $xlate->{$from} = $to;
    }
}

#
# If everything is OK, translate file(s).
#
my $translator  =  SQL::Translator->new( 
    xlate       => $xlate || {},
    debug       => $debug,
    trace       => $trace,
    no_comments => $no_comments,
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
    my $output = $translator->translate( $file ) or die
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

    -d|--debug                Print debug info
    --trace                   Print parser trace info
    --no-comments             Don't include comments in SQL output
    --xlate=foo/bar,baz/blech Overrides for field translation

=head1 DESCRIPTION

This script is part of the SQL Fairy project
(http://sqlfairy.sourceforge.net/).  It will try to convert any
database syntax for which it has a grammar into some other format it
knows about.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=head1 SEE ALSO

SQL::Translator.

=cut
