package SQL::Translator::Producer::GraphViz;

# -------------------------------------------------------------------
# $Id: GraphViz.pm,v 1.2 2003-04-24 20:02:31 kycl4rk Exp $
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
use SQL::Translator::Utils qw(debug);

use vars qw[ $VERSION $DEBUG ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;
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
    my ($t, $data) = @_;
    my $args       = $t->producer_args;
    local $DEBUG   = $t->debug;
    debug("Data =\n", Dumper( $data ));
    debug("Producer args =\n", Dumper( $args ));

    my $out_file        = $args->{'out_file'}    || '';
    my $layout          = $args->{'layout'}      || 'neato';
    my $node_shape      = $args->{'node_shape'}  || 'ellipse';
    my $output_type     = $args->{'output_type'} || 'png';
    my $add_color       = $args->{'add_color'};
    my $natural_join    = $args->{'natural_join'};
    my $join_pk_only    = $args->{'join_pk_only'};
    my $skip_fields     = $args->{'skip_fields'};
    my %skip            = map { s/^\s+|\s+$//g; $_, 1 }
                          split ( /,/, $skip_fields );
    $natural_join     ||= $join_pk_only;

    die "Invalid layout '$layout'" unless VALID_LAYOUT->{ $layout };
    die "Invalid output type: '$output_type'"
        unless VALID_OUTPUT->{ $output_type };
    die "Invalid node shape'$node_shape'" 
        unless VALID_NODE_SHAPE->{ $node_shape };

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
                push @{ $common_keys{ $field->{'name'} } }, 
                    $table->{'table_name'};
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
    else {
        for my $table ( values %$data ) {
            for my $field ( values %{ $table->{'fields'} } ) {
                for my $constraint ( 
                    grep { $_->{'type'} eq 'foreign_key' }
                    @{ $field->{'constraints'} }
                ) {
                    my $ref_table  = $constraint->{'reference_table'} or next;
                    my @ref_fields = @{ $constraint->{'reference_fields'}||[] };

                    unless ( @ref_fields ) {
                        for my $field ( 
                            values %{ $data->{ $ref_table }{'fields'} } 
                        ) {
                            for my $pk (
                                grep { $_->{'type'} eq 'primary_key' }
                                @{ $field->{'constraints'} }
                            ) {
                                push @ref_fields, @{ $pk->{'fields'} };
                            }
                        }

                        $constraint->{'reference_fields'} = [ @ref_fields ];
                    }

                    for my $ref_field (@{$constraint->{'reference_fields'}}) {
                        $data->{$ref_table}{'fields'}{$ref_field}{'is_fk'} = 1;
                    }
                }
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

        debug("Processing table '$table_name'");

        my @fields = 
            map  { $_->[1] }
            sort { $a->[0] <=> $b->[0] }
            map  { [ $_->{'order'}, $_ ] }
            values %{ $table->{'fields'} };

        debug("Fields = ", join(', ', map { $_->{'name'} } @fields));

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

        debug("Primary keys = ", join(', ', sort keys %pk));
        debug("Unique = ", join(', ', sort keys %unique));

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
