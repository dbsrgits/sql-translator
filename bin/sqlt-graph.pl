#!/usr/bin/perl

# $Id: sqlt-graph.pl,v 1.1 2003-06-16 18:23:08 kycl4rk Exp $

=head1 NAME 

auto-graph.pl - Automatically create a graph from a database schema

=head1 SYNOPSIS

  ./auto-graph.pl -d|--db=db_parser [options] schema.sql

  Options:

    -l|--layout        Layout schema for GraphViz
                       ("dot," "neato," "twopi"; default "dot")
    -n|--node-shape    Shape of the nodes ("record," "plaintext," 
                       "ellipse," "circle," "egg," "triangle," "box," 
                       "diamond," "trapezium," "parallelogram," "house," 
                       "hexagon," "octagon," default "ellipse")
    -o|--output        Output file name (default STDOUT)
    -t|--output-type   Output file type ("canon", "text," "ps," "hpgl,"
                       "pcl," "mif," "pic," "gd," "gd2," "gif," "jpeg,"
                       "png," "wbmp," "cmap," "ismap," "imap," "vrml,"
                       "vtx," "mp," "fig," "svg," "plain," default "png")
    -c|--color         Add colors
    --no-fields        Don't show field names
    --height           Image height (in inches, default "11",
                       set to "0" to undefine)
    --width            Image width (in inches, default "8.5", 
                       set to "0" to undefine)
    --natural-join     Perform natural joins
    --natural-join-pk  Perform natural joins from primary keys only
    -s|--skip          Fields to skip in natural joins
    --debug            Print debugging information

=head1 DESCRIPTION

This script will create a graph of your schema.  Only the database
driver argument (for SQL::Translator) is required.  If no output file
name is given, then image will be printed to STDOUT, so you should
redirect the output into a file.

The default action is to assume the presence of foreign key
relationships defined via "REFERNCES" or "FOREIGN KEY" constraints on
the tables.  If you are parsing the schema of a file that does not
have these, you will find the natural join options helpful.  With
natural joins, like-named fields will be considered foreign keys.
This can prove too permissive, however, as you probably don't want a
field called "name" to be considered a foreign key, so you could
include it in the "skip" option, and all fields called "name" will be
excluded from natural joins.  A more efficient method, however, might
be to simply deduce the foriegn keys from primary keys to other fields
named the same in other tables.  Use the "natural-join-pk" option
to acheive this.

If the schema defines foreign keys, then the graph produced will be
directed showing the direction of the relationship.  If the foreign
keys are intuited via natural joins, the graph will be undirected.

=cut

use strict;
use Data::Dumper;
use Getopt::Long;
use GraphViz;
use Pod::Usage;
use SQL::Translator;

my $VERSION = (qw$Revision: 1.1 $)[-1];

#
# Get arguments.
#
my ( 
    $layout, $node_shape, $out_file, $output_type, $db_driver, $add_color, 
    $natural_join, $join_pk_only, $skip_fields, $debug, $help, $height, 
    $width, $no_fields
);

GetOptions(
    'd|db=s'           => \$db_driver,
    'o|output:s'       => \$out_file,
    'l|layout:s'       => \$layout,
    'n|node-shape:s'   => \$node_shape,
    't|output-type:s'  => \$output_type,
    'height:i'         => \$height,
    'width:i'          => \$width,
    'c|color'          => \$add_color,
    'no-fields'        => \$no_fields,
    'natural-join'     => \$natural_join,
    'natural-join-pk'  => \$join_pk_only,
    's|skip:s'         => \$skip_fields,
    'debug'            => \$debug,
    'h|help'           => \$help,
) or die pod2usage;
my @files = @ARGV; # the create script(s) for the original db

pod2usage(1) if $help;
pod2usage( -message => "No db driver specified" ) unless $db_driver;
pod2usage( -message => 'No input file'          ) unless @files;

my $translator          =  SQL::Translator->new( 
    from                => $db_driver,
    to                  => 'GraphViz',
    debug               => $debug || 0,
    producer_args       => {
        out_file        => $out_file,
        layout          => $layout,
        node_shape      => $node_shape,
        output_type     => $output_type,
        add_color       => $add_color,
        natural_join    => $natural_join,
        natural_join_pk => $join_pk_only,
        skip_fields     => $skip_fields,
        height          => $height || 0,
        width           => $width  || 0,
        show_fields     => $no_fields ? 0 : 1,
    },
) or die SQL::Translator->error;

for my $file (@files) {
    my $output = $translator->translate( $file ) or die
                 "Error: " . $translator->error;
    if ( $out_file ) {
        print "Image written to '$out_file'.  Done.\n";
    }
    else {
        print $output;
    }
}

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
