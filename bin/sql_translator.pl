#!/usr/bin/perl -w

#-----------------------------------------------------
# $Id: sql_translator.pl,v 1.1.1.1 2002-03-01 02:26:25 kycl4rk Exp $
#
# File       : sql_translator.pl
# Programmer : Ken Y. Clark, kclark@logsoft.com
# Created    : 2002/02/27
# Purpose    : invoke SQL::Translator
#-----------------------------------------------------

use strict;
use Getopt::Long;
use Pod::Usage;
use SQL::Translator;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1.1.1 $)[-1];

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
    'f|from=s'    => \$from,
    't|to=s'      => \$to,
    'h|help'      => \$help,
    'v|verbose'   => \$verbose,
    'no_comments' => \$no_comments,
) or pod2usage(2);

my @files = @ARGV; # the create script for the original db

pod2usage(1) if $help;
pod2usage(2) unless $from && $to && @files;

#
# If everything is OK, translate file(s).
#
my $translator  =  SQL::Translator->new;
my $output      =  $translator->translate(
    from        => $from,
    to          => $to,
    input       => \@files,
    verbose     => $verbose,
    no_comments => $no_comments,
) or die "Error: " . $translator->error;
print "Output:\n", $output;

#-----------------------------------------------------
# It is not all books that are as dull as their readers.
# Henry David Thoreau
#-----------------------------------------------------

=head1 NAME

sql_translator.pl - convert schema to Oracle syntax

=head1 SYNOPSIS

  ./sql_translator.pl -h|--help

  ./sql_translator.pl -f|--from mysql -t|--to oracle [options] file

  Options:

    -v|--verbose   Print debug info to STDERR
    --no-comments  Don't include comments in SQL output

=head1 DESCRIPTION

Part of the SQL Fairy project (sqlfairy.sourceforge.net), this script
will try to convert any database syntax for which it has a grammar
into some other format will accept.

=head1 AUTHOR

Ken Y. Clark, kclark@logsoft.com

=head1 SEE ALSO

perl(1), SQL::Transport.

=cut
