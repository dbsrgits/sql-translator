#!/usr/bin/perl -w

# -------------------------------------------------------------------
# $Id: sql_translator.pl,v 1.4 2002-11-20 04:03:02 kycl4rk Exp $
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
$VERSION = sprintf "%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/;

my $from;        # the original database
my $to;          # the destination database 
my $help;        # show POD and bail
my $stdin;       # whether to read STDIN for create script
my $no_comments; # whether to put comments in out file
my $verbose;     # whether to print progress/debug

#
# Get options, explain how to use the script if necessary.
#
GetOptions(
    'f|from|parser=s' => \$from,
    't|to|producer=s' => \$to,
    'h|help'          => \$help,
    'v|verbose'       => \$verbose,
    'no_comments'     => \$no_comments,
) or pod2usage(2);

my @files = @ARGV; # the create script for the original db

pod2usage(1) if $help;
pod2usage(2) unless $from && $to && @files;

#
# If everything is OK, translate file(s).
#
my $translator = SQL::Translator->new( debug => $verbose );
$translator->parser($from);
$translator->producer($to);

for my $file (@files) {
    my $output = $translator->translate( $file ) or die
        "Error: " . $translator->error;
    print $output;
    warn "parser = ", Dumper( $translator->parser );
}

# ----------------------------------------------------
# It is not all books that are as dull as their readers.
# Henry David Thoreau
# ----------------------------------------------------

=head1 NAME

sql_translator.pl - convert an SQL database schema

=head1 SYNOPSIS

  ./sql_translator.pl -h|--help

  ./sql_translator.pl -f|--from MySQL -t|--to Oracle [options] file

  Options:

    -v|--verbose   Print debug info to STDERR
    --no-comments  Don't include comments in SQL output

=head1 DESCRIPTION

Part of the SQL Fairy project (sqlfairy.sourceforge.net), this script
will try to convert any database syntax for which it has a grammar
into some other format it knows about.

=head1 AUTHOR

Ken Y. Clark, E<lt>kclark@logsoft.comE<gt>

=head1 SEE ALSO

perl(1), SQL::Translator.

=cut
