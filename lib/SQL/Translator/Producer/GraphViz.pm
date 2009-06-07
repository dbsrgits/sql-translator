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
          bgcolor => 'lightgoldenrodyellow',
          show_constraints => 1,
          show_datatypes => 1,
          show_sizes => 1
      }
  ) or die SQL::Translator->error;

  $trans->translate or die $trans->error;

=head1 DESCRIPTION

Creates a graph of a schema using the amazing graphviz
(see http://www.graphviz.org/) application (via
the L<GraphViz> module).  It's nifty--you should try it!

=head1 PRODUCER ARGS

All L<GraphViz> constructor attributes are accepted and passed
through to L<GraphViz/new>. The following defaults are assumed
for some attributes:

  layout => 'dot',
  overlap => 'false',

  node => {
    shape => 'record',
    style => 'filled',
    fillcolor => 'white',
  },

  # in inches
  width => 8.5,
  height => 11,

See the documentation of L<GraphViz/new> for more info on these
and other attributes.

In addition this producer accepts the following arguments:

=over 4

=item * skip_tables

An arrayref or a comma-separated list of table names that should be
skipped. Note that a skipped table node may still appear if another
table has foreign key constraints pointing to the skipped table. If
this happens no table field/index information will be included.

=item * skip_tables_like

An arrayref or a comma-separated list of regular expressions matching
table names that should be skipped.

=item * cluster

POD PENDING

=item * out_file

The name of the file where the resulting GraphViz output will be
written. Alternatively an open filehandle can be supplied. If
undefined (the default) - the result is returned as a string.

=item * output_type (DEFAULT: 'png')

This determines which 
L<output method|GraphViz/as_canon,_as_text,_as_gif_etc._methods>
will be invoked to generate the graph: C<png> translates to
C<as_png>, C<ps> to C<as_ps> and so on.

=item * fontname

This sets the global font name (or full path to font file) for 
node, edge, and graph labels

=item * fontsize

This sets the global font size for node and edge labels (note that
arbitrarily large sizes may be ignored due to page size or graph size
constraints)

=item * show_fields (DEFAULT: true)

If set to a true value, the names of the colums in a table will
be displayed in each table's node

=item * show_fk_only

If set to a true value, only columns which are foreign keys
will be displayed in each table's node

=item * show_datatypes

If set to a true value, the datatype of each column will be
displayed next to each column's name; this option will have no
effect if the value of C<show_fields> is set to false

=item * friendly_ints

If set to a true value, each integer type field will be displayed
as a tinyint, smallint, integer or bigint depending on the field's
associated size parameter. This only applies for the C<integer>
type (and not the C<int> type, which is always assumed to be a
32-bit integer); this option will have no effect if the value of
C<show_fields> is set to false

=item * friendly_ints_extended

If set to a true value, the friendly ints displayed will take into
account the non-standard types, 'tinyint' and 'mediumint' (which,
as far as I am aware, is only implemented in MySQL)

=item * show_sizes

If set to a true value, the size (in bytes) of each CHAR and
VARCHAR column will be displayed in parentheses next to the
column's name; this option will have no effect if the value of
C<show_fields> is set to false

=item * show_constraints

If set to a true value, a field's constraints (i.e., its
primary-key-ness, its foreign-key-ness and/or its uniqueness)
will appear as a comma-separated list in brackets next to the
field's name; this option will have no effect if the value of
C<show_fields> is set to false

=item * show_indexes

If set to a true value, each record will also show the indexes
set on each table. It describes the index types along with
which columns are included in the index.

=item * show_index_names (DEFAULT: true)

If C<show_indexes> is set to a true value, then the value of this
parameter determines whether or not to print names of indexes.
if C<show_index_names> is false, then a list of indexed columns
will appear below the field list. Otherwise, it will be a list
prefixed with the name of each index.

=item * natural_join

If set to a true value, L<SQL::Translator::Schema/make_natural_joins>
will be called before generating the graph.

=item * join_pk_only

The value of this option will be passed as the value of the
like-named argument to L<SQL::Translator::Schema/make_natural_joins>;
implies C<< natural_join => 1 >>

=item * skip_fields

The value of this option will be passed as the value of the
like-named argument to L<SQL::Translator::Schema/make_natural_joins>;
implies C<< natural_join => 1 >>

=back

=head2 DEPRECATED ARGS

=over 4

=item * node_shape

Deprecated, use node => { shape => ... } instead

=item * add_color

Deprecated, use bgcolor => 'lightgoldenrodyellow' instead

If set to a true value, the graphic will have a background
color of 'lightgoldenrodyellow'; otherwise the default
white background will be used

=item * nodeattrs

Deprecated, use node => { ... } instead

=item * edgeattrs

Deprecated, use edge => { ... } instead

=item * graphattrs

Deprecated, use graph => { ... } instead

=back

=cut

use warnings;
use strict;
use GraphViz;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(debug);
use Scalar::Util qw/openhandle/;

use vars qw[ $VERSION $DEBUG ];
$VERSION = '1.59';
$DEBUG   = 0 unless defined $DEBUG;

sub produce {
    my $t          = shift;
    my $schema     = $t->schema;
    my $args       = $t->producer_args;
    local $DEBUG   = $t->debug;

    # translate legacy {node|edge|graph}attrs to just {node|edge|graph}
    for my $argtype (qw/node edge graph/) {
        my $old_arg = $argtype . 'attrs';

        my %arglist = (map
          { %{ $_ || {} } }
          ( delete $args->{$old_arg}, delete $args->{$argtype} )
        );

        $args->{$argtype} = \%arglist if keys %arglist;
    }

    # explode font settings
    for (qw/fontsize fontname/) {
        if (defined $args->{$_}) {
            $args->{node}{$_} ||= $args->{$_};
            $args->{edge}{$_} ||= $args->{$_};
            $args->{graph}{$_} ||= $args->{$_};
        }
    }

    # legacy add_color setting, trumped by bgcolor if set
    $args->{bgcolor} ||= 'lightgoldenrodyellow' if $args->{add_color};

    # legacy node_shape setting, defaults to 'record', trumped by {node}{shape}
    $args->{node}{shape} ||= ( $args->{node_shape} || 'record' );

    # maintain defaults
    $args->{layout}          ||= 'dot';
    $args->{output_type}     ||= 'png';
    $args->{overlap}         ||= 'false';
    $args->{node}{style}     ||= 'filled';
    $args->{node}{fillcolor} ||= 'white';

    $args->{show_fields}    = 1 if not exists $args->{show_fields};
    $args->{show_index_names} = 1 if not exists $args->{show_index_names};
    $args->{width}          = 8.5 if not defined $args->{width};
    $args->{height}         = 11 if not defined $args->{height};
    for ( $args->{height}, $args->{width} ) {
        $_ = 0 unless $_ =~ /^\d+(?:.\d+)?$/;
        $_ = 0 if $_ < 0;
    }

    # so split won't warn
    $args->{$_} ||= '' for qw/skip_fields skip_tables skip_tables_like cluster/;

    my %skip_fields = map { s/^\s+|\s+$//g; length $_ ? ($_, 1) : () }
                        split ( /,/, $args->{skip_fields} );

    my %skip_tables      = map { $_, 1 } (
      ref $args->{skip_tables} eq 'ARRAY'
        ? @{$args->{skip_tables}}
        : split (/\s*,\s*/, $args->{skip_tables})
      );

    my @skip_tables_like = map { qr/$_/ } (
      ref $args->{skip_tables_like} eq 'ARRAY'
        ? @{$args->{skip_tables_like}}
        : split (/\s*,\s*/, $args->{skip_tables_like})
      );

    # join_pk_only/skip_fields implies natural_join
    $args->{natural_join} = 1 
      if ($args->{join_pk_only} or scalar keys %skip_fields);

    # usually we do not want direction when using natural join
    $args->{directed} = ($args->{natural_join} ? 0 : 1)
      if not exists $args->{directed};

    $schema->make_natural_joins(
        join_pk_only => $args->{join_pk_only},
        skip_fields  => $args->{skip_fields},
    ) if $args->{natural_join};

    my %cluster;
    if ( defined $args->{'cluster'} ) {
        my @clusters;
        if ( ref $args->{'cluster'} eq 'ARRAY' ) {
            @clusters = @{ $args->{'cluster'} };
        }
        else {
            @clusters = split /\s*;\s*/, $args->{'cluster'};
        }

        for my $c ( @clusters ) {
            my ( $cluster_name, @cluster_tables );
            if ( ref $c eq 'HASH' ) {
                $cluster_name   = $c->{'name'} || $c->{'cluster_name'};
                @cluster_tables = @{ $c->{'tables'} || [] };
            }
            else {
                my ( $name, $tables ) = split /\s*=\s*/, $c;
                $cluster_name   = $name;
                @cluster_tables = split /\s*,\s*/, $tables;
            }

            for my $table ( @cluster_tables ) {
                $cluster{ $table } = $cluster_name;
            }
        }
    }

    #
    # Create a blank GraphViz object and see if we can produce the output type.
    #
    my $gv = GraphViz->new( %$args )
      or die sprintf ("Can't create GraphViz object: %s\n",
        $@ || 'reason unknown'
      );

    my $output_method = "as_$args->{output_type}";

    # the generators are AUTOLOADed so can't use ->can ($output_method)
    eval { $gv->$output_method };
    die "Invalid output type: '$args->{output_type}'" if $@;

    #
    # Process tables definitions, create nodes
    #
    my %nj_registry; # for locations of fields for natural joins
    my @fk_registry; # for locations of fields for foreign keys

    TABLE:
    for my $table ( $schema->get_tables ) {

        my $table_name = $table->name;
        if ( @skip_tables_like or keys %skip_tables ) {
          next TABLE if $skip_tables{ $table_name };
          for my $regex ( @skip_tables_like ) {
            next TABLE if $table_name =~ $regex;
          }
        }

        my @fields     = $table->get_fields;
        if ( $args->{show_fk_only} ) {
            @fields = grep { $_->is_foreign_key } @fields;
        }

        my $field_str = '';
        if ($args->{show_fields}) {
            my @fmt_fields;
            for my $field (@fields) {

              my $field_info;
              if ($args->{show_datatypes}) {

                my $field_type = $field->data_type;
                my $size = $field->size;

                if ( $args->{friendly_ints} && $size && (lc ($field_type) eq 'integer') ) {
                  # Automatically translate to int2, int4, int8
                  # Type (Bits)     Max. Signed/Unsigned  Length
                  # tinyint* (8)    128                   3
                  #                 255                   3
                  # smallint (16)   32767                 5
                  #                 65535                 5
                  # mediumint* (24) 8388607               7
                  #                 16777215              8
                  # int (32)        2147483647            10
                  #                 4294967295            11
                  # bigint (64)     9223372036854775807   19
                  #                 18446744073709551615  20
                  #
                  # * tinyint and mediumint are nonstandard extensions which are
                  #   only available under MySQL (to my knowledge)
                  if ($size <= 3 and $args->{friendly_ints_extended}) {
                    $field_type = 'tinyint';
                  }
                  elsif ($size <= 5) {
                    $field_type = 'smallint';
                  }
                  elsif ($size <= 8 and $args->{friendly_ints_extended}) {
                    $field_type = 'mediumint';
                  }
                  elsif ($size <= 11) {
                    $field_type = 'integer';
                  }
                  else {
                    $field_type = 'bigint';
                  }
                }

                $field_info = $field_type;
                if ($args->{show_sizes} && $size && ($field_type =~ /^ (?: NUMERIC | DECIMAL | (VAR)?CHAR2? ) $/ix ) ) {
                  $field_info .= '(' . $size . ')';
                }
              }

              my $constraints;
              if ($args->{show_constraints}) {
                my @constraints;
                push(@constraints, 'PK') if $field->is_primary_key;
                push(@constraints, 'FK') if $field->is_foreign_key;
                push(@constraints, 'U')  if $field->is_unique;
                push(@constraints, 'N')  if $field->is_nullable;

                $constraints = join (',', @constraints);
              }

              # construct the field line from all info gathered so far
              push @fmt_fields, join (' ',
                '-',
                $field->name,
                $field_info || (),
                $constraints ? "[$constraints]" : (),
              );
            }

            # join field lines with graphviz formatting
            $field_str = join ('\l', @fmt_fields) . '\l';

        }

        my $index_str = '';
        if ($args->{show_indexes}) {

          my @fmt_indexes;
          for my $index ($table->get_indices) {
            next unless $index->is_valid;

            push @fmt_indexes, join (' ',
              '*',
              $args->{show_index_names}
                ? $index->name . ':' 
                : ()
              ,
              join (', ', $index->fields),
              ($index->type eq 'UNIQUE') ? '[U]' : (),
            );
           }

          # join index lines with graphviz formatting (if any indexes at all)
          $index_str = join ('\l', @fmt_indexes) . '\l' if @fmt_indexes;
        }

        my $name_str = $table_name . '\n';

        # escape spaces
        for ($name_str, $field_str, $index_str) {
          $_ =~ s/ /\\ /g;
        }

        my $node_args;

        # only the 'record' type supports nice formatting
        if ($args->{node}{shape} eq 'record') {

            # the necessity to supply shape => 'record' is a graphviz bug
            $node_args = {
              shape => 'record',
              label => sprintf ('{%s}',
                join ('|',
                  $name_str,
                  $field_str || (),
                  $index_str || (),
                ),
              ),
            };
        }
        else {
            my $sep = sprintf ('%s\n',
              '-' x ( (length $table_name) + 2)
            );

            $node_args = {
              label => join ($sep,
                $name_str,
                $field_str || (),
                $index_str || (),
              ),
            };
        }

        if (my $cluster_name = $cluster{$table_name} ) {
          $node_args->{cluster} = $cluster_name;
        }

        $gv->add_node ($table_name, %$node_args);

        debug("Processing table '$table_name'");

        debug("Fields = ", join(', ', map { $_->name } @fields));

        for my $f ( @fields ) {
            my $name      = $f->name or next;
            my $is_pk     = $f->is_primary_key;
            my $is_unique = $f->is_unique;

            #
            # Decide if we should skip this field.
            #
            if ( $args->{natural_join} ) {
                next unless $is_pk || $f->is_foreign_key;
            }

            my $constraints = $f->{'constraints'};

            if ( $args->{natural_join} && !$skip_fields{ $name } ) {
                push @{ $nj_registry{ $name } }, $table_name;
            }
        }

        unless ( $args->{natural_join} ) {
            for my $c ( $table->get_constraints ) {
                next unless $c->type eq FOREIGN_KEY;
                my $fk_table = $c->reference_table or next;

                for my $field_name ( $c->fields ) {
                    for my $fk_field ( $c->reference_fields ) {
                        next unless defined $schema->get_table( $fk_table );

                        # a condition is optional if at least one fk is nullable
                        push @fk_registry, [
                            $table_name,
                            $fk_table,
                            scalar (grep { $_->is_nullable } ($c->fields))
                        ];
                    }
                }
            }
        }
    }

    #
    # Process relationships, create edges
    #
    my (@table_bunches, %optional_constraints);
    if ( $args->{natural_join} ) {
        for my $field_name ( keys %nj_registry ) {
            my @table_names = @{ $nj_registry{ $field_name } || [] } or next;
            next if scalar @table_names == 1;
            push @table_bunches, [ @table_names ];
        }
    }
    else {
        for my $i (0 .. $#fk_registry) {
            my $fk = $fk_registry[$i];
            push @table_bunches, [$fk->[0], $fk->[1]];
            $optional_constraints{$i} = $fk->[2];
        }
    }

    my %done;
    for my $bi (0 .. $#table_bunches) {
        my @tables = @{$table_bunches[$bi]};

        for my $i ( 0 .. $#tables ) {
            my $table1 = $tables[ $i ];
            for my $j ( 1 .. $#tables ) {
                next if $i == $j;
                my $table2 = $tables[ $j ];
                next if $done{ $table1 }{ $table2 };
                $gv->add_edge(
                    $table2,
                    $table1,
                    arrowhead => $optional_constraints{$bi} ? 'empty' : 'normal',
                );
                $done{ $table1 }{ $table2 } = 1;
            }
        }
    }

    #
    # Print the image
    #
    if ( my $out = $args->{out_file} ) {
        if (openhandle ($out)) {
            print $out $gv->$output_method;
        }
        else {
            open my $fh, '>', $out or die "Can't write '$out': $!\n";
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

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>

Jonathan Yu E<lt>frequency@cpan.orgE<gt>

=head1 SEE ALSO

SQL::Translator, GraphViz

=cut
