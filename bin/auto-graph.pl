#!/usr/bin/perl

# $Id: auto-graph.pl,v 1.1 2003-04-03 19:30:48 kycl4rk Exp $

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
    --color            Add colors
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

use constant VALID_LAYOUT => {
    dot   => 1, 
    neato => 1, 
    twopi => 1,
};

use constant VALID_NODE_SHAPE => {
    record        => 1, 
    plaintext     => 1, 
    ellipse       => 1, 
    circle        => 1, 
    egg           => 1, 
    triangle      => 1, 
    box           => 1, 
    diamond       => 1, 
    trapezium     => 1, 
    parallelogram => 1, 
    house         => 1, 
    hexagon       => 1, 
    octagon       => 1, 
};

use constant VALID_OUTPUT => {
    canon => 1, 
    text  => 1, 
    ps    => 1, 
    hpgl  => 1,
    pcl   => 1, 
    mif   => 1, 
    pic   => 1, 
    gd    => 1, 
    gd2   => 1, 
    gif   => 1, 
    jpeg  => 1,
    png   => 1, 
    wbmp  => 1, 
    cmap  => 1, 
    ismap => 1, 
    imap  => 1, 
    vrml  => 1,
    vtx   => 1, 
    mp    => 1, 
    fig   => 1, 
    svg   => 1, 
    plain => 1,
};

#
# Get arguments.
#
my ( 
    $layout, $node_shape, $out_file, $output_type, $db_driver, $add_color, 
    $natural_join, $join_pk_only, $skip_fields, $debug
);

GetOptions(
    'd|db=s'           => \$db_driver,
    'o|output:s'       => \$out_file,
    'l|layout:s'       => \$layout,
    'n|node-shape:s'   => \$node_shape,
    't|output-type:s'  => \$output_type,
    'color'            => \$add_color,
    'natural-join'     => \$natural_join,
    'natural-join-pk'  => \$join_pk_only,
    's|skip:s'         => \$skip_fields,
    'debug'            => \$debug,
) or die pod2usage;
my $file = shift @ARGV or pod2usage( -message => 'No input file' );

pod2usage( -message => "No db driver specified" ) unless $db_driver;

my %skip        = map { $_, 1 } split ( /,/, $skip_fields );
$natural_join ||= $join_pk_only;
$layout         = 'dot'     unless VALID_LAYOUT->{ $layout };
$node_shape     = 'ellipse' unless VALID_NODE_SHAPE->{ $node_shape };
$output_type    = 'png'     unless VALID_OUTPUT->{ $output_type };

#
# Create GraphViz and see if we can produce the output type.
#
my $gv            =  GraphViz->new(
    directed      => $natural_join ? 0 : 1,
    layout        => $layout,
    no_overlap    => 1,
    bgcolor       => $add_color ? 'lightgoldenrodyellow' : 'white',
    node          => { 
        shape     => $node_shape, 
        style     => 'filled', 
        fillcolor => 'white' 
    },
) or die "Can't create GraphViz object\n";

#die "GraphViz cannot produce files of type '$output_type'\n" unless
#    $gv->can( "as_$output_type" );

#
# Parse file.
#
warn "Parsing file '$file' with driver '$db_driver'\n" if $debug;

my $t    = SQL::Translator->new( parser => $db_driver, producer => 'Raw' );
my $data = $t->translate( $file ) or die $t->error;

warn "Data =\n", Dumper( $data ), "\n" if $debug;

my %nj_registry; # for locations of fields for natural joins
my @fk_registry; # for locations of fields for foreign keys

#
# If necessary, pre-process fields to find foreign keys.
#
if ( $natural_join ) {
    my ( %common_keys, %pk );
    for my $table ( values %$data ) {
        for my $index ( 
            @{ $table->{'indices'}     || [] },
            @{ $table->{'constraints'} || [] },
        ) {
            my @fields = @{ $index->{'fields'} || [] } or next;
            if ( $index->{'type'} eq 'primary_key' ) {
                $pk{ $_ } = 1 for @fields;
            }
        }

        for my $field ( values %{ $table->{'fields'} } ) {
            push @{ $common_keys{ $field->{'name'} } }, $table->{'table_name'};
        }
    }

    for my $field ( keys %common_keys ) {
        my @tables = @{ $common_keys{ $field } };
        next unless scalar @tables > 1;
        for my $table ( @tables ) {
            next if $join_pk_only and !defined $pk{ $field };
            $data->{ $table }{'fields'}{ $field }{'is_fk'} = 1;
        }
    }
}

for my $table (
    map  { $_->[1] }
    sort { $a->[0] <=> $b->[0] }
    map  { [ $_->{'order'}, $_ ] }
    values %$data 
) {
    my $table_name = $table->{'table_name'};
    $gv->add_node( $table_name );

    warn "Processing table '$table_name'\n" if $debug;

    my @fields = 
        map  { $_->[1] }
        sort { $a->[0] <=> $b->[0] }
        map  { [ $_->{'order'}, $_ ] }
        values %{ $table->{'fields'} };

    warn "Fields = ", join(', ', map { $_->{'name'} } @fields), "\n" if $debug;

    my ( %pk, %unique );
    for my $index ( 
        @{ $table->{'indices'}     || [] },
        @{ $table->{'constraints'} || [] },
    ) {
        my @fields = @{ $index->{'fields'} || [] } or next;
        if ( $index->{'type'} eq 'primary_key' ) {
            $pk{ $_ } = 1 for @fields;
        }
        elsif ( $index->{'type'} eq 'unique' ) {
            $unique{ $_ } = 1 for @fields;
        }
    }

    warn "Primary keys = ", join(', ', sort keys %pk), "\n" if $debug;
    warn "Unique = ", join(', ', sort keys %unique), "\n" if $debug;

    for my $f ( @fields ) {
        my $name      = $f->{'name'} or next;
        my $is_pk     = $pk{ $name };
        my $is_unique = $unique{ $name };

        #
        # Decide if we should skip this field.
        #
        if ( $natural_join ) {
            next unless $is_pk || $f->{'is_fk'};
        }
        else {
            next unless $is_pk ||
                grep { $_->{'type'} eq 'foreign_key' }
                @{ $f->{'constraints'} }
            ;
        }

        my $constraints = $f->{'constraints'};

        if ( $natural_join && !$skip{ $name } ) {
            push @{ $nj_registry{ $name } }, $table_name;
        }
        elsif ( @{ $constraints || [] } ) {
            for my $constraint ( @$constraints ) {
                next unless $constraint->{'type'} eq 'foreign_key';
                for my $fk_field ( 
                    @{ $constraint->{'reference_fields'} || [] }
                ) {
                    my $fk_table = $constraint->{'reference_table'};
                    next unless defined $data->{ $fk_table };
                    push @fk_registry, [ $table_name, $fk_table ];
                }
            }
        }
    }
}

#
# Make the connections.
#
my @table_bunches;
if ( $natural_join ) {
    for my $field_name ( keys %nj_registry ) {
        my @table_names = @{ $nj_registry{ $field_name } || [] } or next;
        next if scalar @table_names == 1;
        push @table_bunches, [ @table_names ];
    }
}
else {
    @table_bunches = @fk_registry;
}

my %done;
for my $bunch ( @table_bunches ) {
    my @tables = @$bunch;

    for my $i ( 0 .. $#tables ) {
        my $table1 = $tables[ $i ];
        for my $j ( 0 .. $#tables ) {
            my $table2 = $tables[ $j ];
            next if $table1 eq $table2;
            next if $done{ $table1 }{ $table2 };
            $gv->add_edge( $table1, $table2 );
            $done{ $table1 }{ $table2 } = 1;
            $done{ $table2 }{ $table1 } = 1;
        }
    }
}

#
# Print the image.
#
my $output_method = "as_$output_type";
if ( $out_file ) {
    open my $fh, ">$out_file" or die "Can't write '$out_file': $!\n";
    print $fh $gv->$output_method;
    close $fh;
    print "Image written to '$out_file'.  Done.\n";
}
else {
    print $gv->$output_method;
}

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
