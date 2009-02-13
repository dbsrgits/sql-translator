package SQL::Translator::Producer::GraphViz;

# -------------------------------------------------------------------
# Copyright (C) 2002-2009 SQLFairy Authors
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

=pod

=head1 NAME

SQL::Translator::Producer::GraphViz - GraphViz producer for SQL::Translator

=head1 SYNOPSIS

  use SQL::Translator;

  my $trans = new SQL::Translator(
      from => 'MySQL',            # or your db of choice
      to => 'GraphViz',
      producer_args => {
          out_file => 'schema.png',
          add_color => 1,
          show_constraints => 1,
          show_datatypes => 1,
          show_sizes => 1
      }
  ) or die SQL::Translator->error;

  $trans->translate or die $trans->error;

=head1 DESCRIPTION

Creates a graph of a schema using the amazing graphviz
(see http://www.graphviz.org/) application (via
the GraphViz module).  It's nifty--you should try it!

=head1 PRODUCER ARGS

=over 4

=item * out_file

The name of the file where the resulting GraphViz output will be
written. Alternatively an open filehandle can be supplied. If
undefined (the default) - the result is returned as a string.

=item * layout (DEFAULT: 'dot')

determines which layout algorithm GraphViz will use; possible
values are 'dot' (the default GraphViz layout for directed graph
layouts), 'neato' (for undirected graph layouts - spring model)
or 'twopi' (for undirected graph layouts - circular)

=item * node_shape (DEFAULT: 'record')

sets the node shape of each table in the graph; this can be
one of 'record', 'plaintext', 'ellipse', 'circle', 'egg',
'triangle', 'box', 'diamond', 'trapezium', 'parallelogram',
'house', 'hexagon', or 'octagon'

=item * output_type (DEFAULT: 'png')

sets the file type of the output graphic; possible values are
'ps', 'hpgl', 'pcl', 'mif', 'pic', 'gd', 'gd2', 'gif', 'jpeg',
'png', 'wbmp', 'cmap', 'ismap', 'imap', 'vrml', 'vtx', 'mp',
'fig', 'svg', 'canon', 'plain' or 'text' (see GraphViz for
details on each of these)

=item * width (DEFAULT: 8.5)

width (in inches) of the output graphic

=item * height (DEFAULT: 11)

height (in inches) of the output grahic

=item * fontsize

custom font size for node and edge labels (note that arbitrarily large
sizes may be ignored due to page size or graph size constraints)

=item * fontname

custom font name (or full path to font file) for node, edge, and graph
labels

=item * nodeattrs

reference to a hash of node attribute names and their values; these
may override general fontname or fontsize parameter

=item * edgeattrs

reference to a hash of edge attribute names and their values; these
may override general fontname or fontsize parameter

=item * graphattrs

reference to a hash of graph attribute names and their values; these
may override the general fontname parameter

=item * show_fields (DEFAULT: true)

if set to a true value, the names of the colums in a table will
be displayed in each table's node

=item * show_fk_only

if set to a true value, only columns which are foreign keys
will be displayed in each table's node

=item * show_datatypes

if set to a true value, the datatype of each column will be
displayed next to each column's name; this option will have no
effect if the value of show_fields is set to false

=item * show_sizes

if set to a true value, the size (in bytes) of each CHAR and
VARCHAR column will be displayed in parentheses next to the
column's name; this option will have no effect if the value of
show_fields is set to false

=item * show_constraints

if set to a true value, a field's constraints (i.e., its
primary-key-ness, its foreign-key-ness and/or its uniqueness)
will appear as a comma-separated list in brackets next to the
field's name; this option will have no effect if the value of
show_fields is set to false

=item * add_color

if set to a true value, the graphic will have a background
color of 'lightgoldenrodyellow'; otherwise the background
color will be white

=item * natural_join

if set to a true value, the make_natural_join method of
SQL::Translator::Schema will be called before generating the
graph; a true value for join_pk_only (see below) implies a
true value for this option

=item * join_pk_only

the value of this option will be passed as the value of the
like-named argument in the make_natural_join method (see
natural_join above) of SQL::Translator::Schema, if either the
value of this option or the natural_join option is set to true

=item * skip_fields

the value of this option will be passed as the value of the
like-named argument in the make_natural_join method (see
natural_join above) of SQL::Translator::Schema, if either
the natural_join or join_pk_only options has a true value

=item * show_indexes

if set to a true value, each record will also show the indexes
set on each table. it describes the index types along with
which columns are included in the index. this option requires
that show_fields is a true value as well

=item * show_index_names

if show_indexes is set to a true value, then the value of this
parameter determines whether or not to print names of indexes.
if show_index_names is false, then a list of indexed columns
will appear below the field list. otherwise, it will be a list
prefixed with the name of each index. it defaults to true.

=item * friendly_ints

if set to a true value, each integer type field will be displayed
as a smallint, integer or bigint depending on the field's
associated size parameter. this only applies for the 'integer'
type (and not the lowercase 'int' type, which is assumed to be a
32-bit integer).

=item * friendly_ints_extended

if set to a true value, the friendly ints displayed will take into
account the non-standard types, 'tinyint' and 'mediumint' (which,
as far as I am aware, is only implemented in MySQL)

=back

=cut

use strict;
use GraphViz;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(debug);
use Scalar::Util qw/openhandle/;

use vars qw[ $VERSION $DEBUG ];
$VERSION = '1.59';
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

sub produce {
    my $t          = shift;
    my $schema     = $t->schema;
    my $args       = $t->producer_args;
    local $DEBUG   = $t->debug;

    my $out_file         = $args->{'out_file'}    || '';
    my $layout           = $args->{'layout'}      || 'dot';
    my $node_shape       = $args->{'node_shape'}  || 'record';
    my $output_type      = $args->{'output_type'} || 'png';
    my $width            = defined $args->{'width'} 
                           ? $args->{'width'} : 8.5;
    my $height           = defined $args->{'height'}
                           ? $args->{'height'} : 11;
    my $fontsize         = $args->{'fontsize'};
    my $fontname         = $args->{'fontname'};
    my $edgeattrs        = $args->{'edgeattrs'} || {};
    my $graphattrs       = $args->{'graphattrs'} || {};
    my $nodeattrs        = $args->{'nodeattrs'} || {};
    my $show_fields      = defined $args->{'show_fields'} 
                           ? $args->{'show_fields'} : 1;
    my $add_color        = $args->{'add_color'};
    my $natural_join     = $args->{'natural_join'};
    my $show_fk_only     = $args->{'show_fk_only'};
    my $show_datatypes   = $args->{'show_datatypes'};
    my $show_sizes       = $args->{'show_sizes'};
    my $show_indexes     = $args->{'show_indexes'};
    my $show_index_names = defined $args->{'show_index_names'} ? $args->{'show_index_names'} : 1;
    my $friendly_ints    = $args->{'friendly_ints'};
    my $friendly_ints_ex = $args->{'friendly_ints_extended'};
    my $show_constraints = $args->{'show_constraints'};
    my $join_pk_only     = $args->{'join_pk_only'};
    my $skip_fields      = $args->{'skip_fields'} || '';
    my %skip             = map { s/^\s+|\s+$//g; length $_ ? ($_, 1) : () }
                           split ( /,/, $skip_fields );
    $natural_join      ||= $join_pk_only;

    $schema->make_natural_joins(
        join_pk_only => $join_pk_only,
        skip_fields  => $args->{'skip_fields'},
    ) if $natural_join;

    die "Invalid layout '$layout'" unless VALID_LAYOUT->{ $layout };
    die "Invalid node shape'$node_shape'" 
        unless VALID_NODE_SHAPE->{ $node_shape };

    for ( $height, $width ) {
        $_ = 0 unless $_ =~ /^\d+(.\d)?$/;
        $_ = 0 if $_ < 0;
    }

    my %args = (
        directed      => $natural_join ? 0 : 1,
        layout        => $layout,
        no_overlap    => 1,
        bgcolor       => $add_color ? 'lightgoldenrodyellow' : 'white',
        node          => { 
            shape     => $node_shape, 
            style     => 'filled', 
            fillcolor => 'white',
        },
    );
    $args{'width'}  = $width  if $width;
    $args{'height'} = $height if $height;
    # set fontsize for edge and node labels if specified
    if ($fontsize) {
        $args{'node'}->{'fontsize'} = $fontsize;
        $args{'edge'} = {} unless $args{'edge'};
        $args{'edge'}->{'fontsize'} = $fontsize;        
    }
    # set the font name globally for node, edge, and graph labels if
    # specified (use node, edge, or graph attributes for individual
    # font specification)
    if ($fontname) {
        $args{'node'}->{'fontname'} = $fontname;
        $args{'edge'} = {} unless $args{'edge'};
        $args{'edge'}->{'fontname'} = $fontname;        
        $args{'graph'} = {} unless $args{'graph'};
        $args{'graph'}->{'fontname'} = $fontname;        
    }
    # set additional node, edge, and graph attributes; these may
    # possibly override ones set before
    while (my ($key,$val) = each %$nodeattrs) {
        $args{'node'}->{$key} = $val;
    }
    $args{'edge'} = {} if %$edgeattrs && !$args{'edge'};
    while (my ($key,$val) = each %$edgeattrs) {
        $args{'edge'}->{$key} = $val;
    }
    $args{'graph'} = {} if %$edgeattrs && !$args{'graph'};
    while (my ($key,$val) = each %$graphattrs) {
        $args{'graph'}->{$key} = $val;
    }

    #
    # Create a blank GraphViz object and see if we can produce the output type.
    #
    my $gv = GraphViz->new( %args ) or die "Can't create GraphViz object\n";
    my $output_method = "as_$output_type";

    # the generators are AUTOLOADed so can't use ->can ($output_method) 
    eval { $gv->$output_method };
    die "Invalid output type: '$output_type'" if $@;


    my %nj_registry; # for locations of fields for natural joins
    my @fk_registry; # for locations of fields for foreign keys

    for my $table ( $schema->get_tables ) {
        my @fields     = $table->get_fields;
        if ( $show_fk_only ) {
            @fields = grep { $_->is_foreign_key } @fields;
        }

        my $field_str = '';
        if ($show_fields) {

          my @fmt_fields;
          foreach my $field (@fields) {

            my $field_type;
            if ($show_datatypes) {

              $field_type = $field->data_type;

              # For the integer type, transform into different types based on
              # requested size, if a size is given.
              if ($field->size and $friendly_ints and (lc $field_type) eq 'integer') {
                # Automatically translate to int2, int4, int8
                # Type (Bits)     Max. Signed/Unsigned    Length
                # tinyint* (8)    128                     3
                #                 255                     3
                # smallint (16)   32767                   5
                #                 65535                   5
                # mediumint* (24) 8388607                 7
                #                 16777215                8
                # int (32)        2147483647              10
                #                 4294967295              11
                # bigint (64)     9223372036854775807     19
                #                 18446744073709551615    20
                #
                # * tinyint and mediumint are nonstandard extensions which are
                #   only available under MySQL (to my knowledge)
                my $size = $field->size;
                if ($size <= 3 and $friendly_ints_ex) {
                  $field_type = 'tinyint',
                }
                elsif ($size <= 5) {
                  $field_type = 'smallint';
                }
                elsif ($size <= 8 and $friendly_ints_ex) {
                  $field_type = 'mediumint';
                }
                elsif ($size <= 11) {
                  $field_type = 'integer';
                }
                else {
                  $field_type = 'bigint';
                }
              }

              if (
                $show_sizes
                  and
                $field->size
                  and
                ($field_type =~ /^(var)?char2?$/ or $field_type eq 'numeric' or $field_type eq 'decimal')
              ) {
                $field_type .= '(' . $field->size . ')';
              }
            }

            my $constraints;
            if ($show_constraints) {
              my @constraints;
              push(@constraints, 'PK') if $field->is_primary_key;
              push(@constraints, 'FK') if $field->is_foreign_key;
              push(@constraints, 'U')  if $field->is_unique;

              $constraints = join (',', @constraints);
            }

            # construct the field line from all info gathered so far
            push @fmt_fields, join (' ',
              '-',
              $field->name,
              $field_type || (),
              $constraints ? "[$constraints]" : (),
            );

          }

          # join field lines with graphviz formatting
          $field_str = join ('\l', @fmt_fields) . '\l';
        }

        my $index_str = '';
        if ($show_indexes) {

          my @fmt_indexes;
          foreach my $index ($table->get_indices) {
            next unless $index->is_valid;

            push @fmt_indexes, join (' ',
              '*',
              $show_index_names ? $index->name . ':' : (),
              join (', ', $index->fields),
              ($index->type eq 'UNIQUE') ? '[U]' : (),
            );
          }

          # join index lines with graphviz formatting (if any indexes at all)
          $index_str = join ('\l', @fmt_indexes) . '\l' if @fmt_indexes;
        }

        my $table_name = $table->name;
        my $name_str = $table_name . '\n';

        # escape spaces
        for ($name_str, $field_str, $index_str) {
          $_ =~ s/ /\\ /g;
        }


        # only the 'record' type supports nice formatting
        if ($node_shape eq 'record') {

            # the necessity to supply shape => 'record' is a graphviz bug 
            $gv->add_node( $table_name,
              shape => 'record',
              label => sprintf ('{%s}',
                join ('|',
                  $name_str,
                  $field_str || (),
                  $index_str || (),
                ),
              ),
            );
        }
        else {
            my $sep = sprintf ('%s\n',
                '-' x ( (length $table_name) + 2)
            );

            $gv->add_node( $table_name,
                label => join ($sep,
                    $name_str,
                    $field_str || (),
                    $index_str || (),
                ),
            );
        }


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
                next if $i == $j;
                my $table2 = $tables[ $j ];
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
    if ( $out_file ) {
      if (openhandle ($out_file)) {
        print $out_file $gv->$output_method;
      }
      else {
        open my $fh, ">$out_file" or die "Can't write '$out_file': $!\n";
        binmode $fh;
        print $fh $gv->$output_method;
        close $fh;
      }
    }
    else {
      return $gv->$output_method;
    }
}

1;

# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=head2 CONTRIBUTORS

Jonathan Yu E<lt>frequency@cpan.orgE<gt>

=head1 SEE ALSO

SQL::Translator, GraphViz

=cut
