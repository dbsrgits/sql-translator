package SQL::Translator::Producer::GraphViz;

# -------------------------------------------------------------------
# $Id: GraphViz.pm,v 1.6 2003-08-04 18:41:45 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>
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
use GraphViz;
use Data::Dumper;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(debug);

use vars qw[ $VERSION $DEBUG ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

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

sub produce {
    my $t          = shift;
    my $schema     = $t->schema;
    my $args       = $t->producer_args;
    local $DEBUG   = $t->debug;

    my $out_file        = $args->{'out_file'}    || '';
    my $layout          = $args->{'layout'}      || 'neato';
    my $node_shape      = $args->{'node_shape'}  || 'record';
    my $output_type     = $args->{'output_type'} || 'png';
    my $width           = defined $args->{'width'} 
                          ? $args->{'width'} : 8.5;
    my $height          = defined $args->{'height'}
                          ? $args->{'height'} : 11;
    my $show_fields     = defined $args->{'show_fields'} 
                          ? $args->{'show_fields'} : 1;
    my $add_color       = $args->{'add_color'};
    my $natural_join    = $args->{'natural_join'};
    my $show_fk_only    = $args->{'show_fk_only'};
    my $join_pk_only    = $args->{'join_pk_only'};
    my $skip_fields     = $args->{'skip_fields'};
    my %skip            = map { s/^\s+|\s+$//g; $_, 1 }
                          split ( /,/, $skip_fields );
    $natural_join     ||= $join_pk_only;

    $schema->make_natural_joins(
        join_pk_only => $join_pk_only,
        skip_fields  => $args->{'skip_fields'},
    ) if $natural_join;

    die "Invalid layout '$layout'" unless VALID_LAYOUT->{ $layout };
    die "Invalid output type: '$output_type'"
        unless VALID_OUTPUT->{ $output_type };
    die "Invalid node shape'$node_shape'" 
        unless VALID_NODE_SHAPE->{ $node_shape };

    for ( $height, $width ) {
        $_ = 0 unless $_ =~ /^\d+(.\d)?$/;
        $_ = 0 if $_ < 0;
    }

    #
    # Create GraphViz and see if we can produce the output type.
    #
    my %args = (
        directed      => $natural_join ? 0 : 1,
        layout        => $layout,
        no_overlap    => 1,
        bgcolor       => $add_color ? 'lightgoldenrodyellow' : 'white',
        node          => { 
            shape     => $node_shape, 
            style     => 'filled', 
            fillcolor => 'white' 
        }
    );
    $args{'width'}  = $width  if $width;
    $args{'height'} = $height if $height;

    my $gv =  GraphViz->new( %args ) or die "Can't create GraphViz object\n";

    my %nj_registry; # for locations of fields for natural joins
    my @fk_registry; # for locations of fields for foreign keys

    for my $table ( $schema->get_tables ) {
        my $table_name = $table->name;
        my @fields     = $table->get_fields;
        if ( $show_fk_only ) {
            @fields = grep { $_->is_foreign_key } @fields;
        }

        my $field_str = join('\l', map { $_->name } @fields);
        my $label = $show_fields ? "{$table_name|$field_str}" : $table_name;
        $gv->add_node( $table_name, label => $label );

        debug("Processing table '$table_name'");

        debug("Fields = ", join(', ', map { $_->name } @fields));

        for my $f ( @fields ) {
            my $name      = $f->name or next;
            my $is_pk     = $f->is_primary_key;
            my $is_unique = $f->is_unique;

            #
            # Decide if we should skip this field.
            #
            if ( $natural_join ) {
                next unless $is_pk || $f->is_foreign_key;
            }

            my $constraints = $f->{'constraints'};

            if ( $natural_join && !$skip{ $name } ) {
                push @{ $nj_registry{ $name } }, $table_name;
            }
        }

        unless ( $natural_join ) {
            for my $c ( $table->get_constraints ) {
                next unless $c->type eq FOREIGN_KEY;
                my $fk_table = $c->reference_table or next;

                for my $field_name ( $c->fields ) {
                    for my $fk_field ( $c->reference_fields ) {
                        next unless defined $schema->get_table( $fk_table );
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
                $gv->add_edge( $table2, $table1 );
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
    }
    else {
        return $gv->$output_method;
    }
}

1;

=pod

=head1 NAME

SQL::Translator::Producer::GraphViz - GraphViz producer for SQL::Translator

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
