package SQL::Translator::Producer::PostgreSQL;

# -------------------------------------------------------------------
# $Id: PostgreSQL.pm,v 1.11 2003-06-23 21:47:30 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>,
#                    darren chamberlain <darren@cpan.org>,
#                    Chris Mungall <cjm@fruitfly.org>
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

=head1 NAME

SQL::Translator::Producer::PostgreSQL - PostgreSQL producer for SQL::Translator

=cut

use strict;
use vars qw[ $DEBUG $WARN $VERSION ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/;
$DEBUG = 1 unless defined $DEBUG;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(header_comment);
use Data::Dumper;

my %translate  = (
    #
    # MySQL types
    #
    bigint     => 'bigint',
    double     => 'double precision',
    decimal    => 'decimal',
    float      => 'double precision',
    int        => 'integer',
    mediumint  => 'integer',
    smallint   => 'smallint',
    tinyint    => 'smallint',
    char       => 'char',
    varchar    => 'character varying',
    longtext   => 'text',
    mediumtext => 'text',
    text       => 'text',
    tinytext   => 'text',
    tinyblob   => 'bytea',
    blob       => 'bytea',
    mediumblob => 'bytea',
    longblob   => 'bytea',
    enum       => 'character varying',
    set        => 'character varying',
    date       => 'date',
    datetime   => 'timestamp',
    time       => 'date',
    timestamp  => 'timestamp',
    year       => 'date',

    #
    # Oracle types
    #
    number     => 'integer',
    char       => 'char',
    varchar2   => 'character varying',
    long       => 'text',
    CLOB       => 'bytea',
    date       => 'date',

    #
    # Sybase types
    #
    int        => 'integer',
    money      => 'money',
    varchar    => 'character varying',
    datetime   => 'timestamp',
    text       => 'text',
    real       => 'double precision',
    comment    => 'text',
    bit        => 'bit',
    tinyint    => 'smallint',
    float      => 'double precision',
);

my %reserved = map { $_, 1 } qw[
    ALL ANALYSE ANALYZE AND ANY AS ASC 
    BETWEEN BINARY BOTH
    CASE CAST CHECK COLLATE COLUMN CONSTRAINT CROSS
    CURRENT_DATE CURRENT_TIME CURRENT_TIMESTAMP CURRENT_USER 
    DEFAULT DEFERRABLE DESC DISTINCT DO
    ELSE END EXCEPT
    FALSE FOR FOREIGN FREEZE FROM FULL 
    GROUP HAVING 
    ILIKE IN INITIALLY INNER INTERSECT INTO IS ISNULL 
    JOIN LEADING LEFT LIKE LIMIT 
    NATURAL NEW NOT NOTNULL NULL
    OFF OFFSET OLD ON ONLY OR ORDER OUTER OVERLAPS
    PRIMARY PUBLIC REFERENCES RIGHT 
    SELECT SESSION_USER SOME TABLE THEN TO TRAILING TRUE 
    UNION UNIQUE USER USING VERBOSE WHEN WHERE
];

my $max_id_length    = 30;
my %used_identifiers = ();
my %global_names;
my %unreserve;
my %truncated;

=pod

=head1 PostgreSQL Create Table Syntax

  CREATE [ [ LOCAL ] { TEMPORARY | TEMP } ] TABLE table_name (
      { column_name data_type [ DEFAULT default_expr ] [ column_constraint [, ... ] ]
      | table_constraint }  [, ... ]
  )
  [ INHERITS ( parent_table [, ... ] ) ]
  [ WITH OIDS | WITHOUT OIDS ]

where column_constraint is:

  [ CONSTRAINT constraint_name ]
  { NOT NULL | NULL | UNIQUE | PRIMARY KEY |
    CHECK (expression) |
    REFERENCES reftable [ ( refcolumn ) ] [ MATCH FULL | MATCH PARTIAL ]
      [ ON DELETE action ] [ ON UPDATE action ] }
  [ DEFERRABLE | NOT DEFERRABLE ] [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]

and table_constraint is:

  [ CONSTRAINT constraint_name ]
  { UNIQUE ( column_name [, ... ] ) |
    PRIMARY KEY ( column_name [, ... ] ) |
    CHECK ( expression ) |
    FOREIGN KEY ( column_name [, ... ] ) REFERENCES reftable [ ( refcolumn [, ... ] ) ]
      [ MATCH FULL | MATCH PARTIAL ] [ ON DELETE action ] [ ON UPDATE action ] }
  [ DEFERRABLE | NOT DEFERRABLE ] [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]

=head1 Create Index Syntax

  CREATE [ UNIQUE ] INDEX index_name ON table
      [ USING acc_method ] ( column [ ops_name ] [, ...] )
      [ WHERE predicate ]
  CREATE [ UNIQUE ] INDEX index_name ON table
      [ USING acc_method ] ( func_name( column [, ... ]) [ ops_name ] )
      [ WHERE predicate ]

=cut

# -------------------------------------------------------------------
sub produce {
    my $translator     = shift;
    $DEBUG             = $translator->debug;
    $WARN              = $translator->show_warnings;
    my $no_comments    = $translator->no_comments;
    my $add_drop_table = $translator->add_drop_table;
    my $schema         = $translator->schema;

    my $output;
    $output .= header_comment unless ($no_comments);

    for my $table ( $schema->get_tables ) {
        my $table_name    = $table->name or next;
        $table_name       = mk_name( $table_name, '', undef, 1 );
        my $table_name_ur = unreserve($table_name);

        my ( @comments, @field_defs, @sequence_defs, @constraint_defs );

        push @comments, "--\n-- Table: $table_name_ur\n--" unless $no_comments;

        #
        # Fields
        #
        my %field_name_scope;
        for my $field ( $table->get_fields ) {
            my $field_name    = mk_name(
                $field->name, '', \%field_name_scope, 1 
            );
            my $field_name_ur = unreserve( $field_name, $table_name );
            my $field_def     = qq["$field_name_ur"];

            #
            # Datatype
            #
            my @size      = $field->size;
            my $data_type = lc $field->data_type;
            my %extra     = $field->extra;
            my $list      = $extra{'list'} || [];
            my $commalist = join ",", @$list;
            my $seq_name;

            if ( $data_type eq 'enum' ) {
                my $len = 0;
                $len = ($len < length($_)) ? length($_) : $len for (@$list);
                my $check_name = mk_name( $table_name.'_'.$field_name, 'chk' );
                push @constraint_defs, 
                "CONSTRAINT $check_name CHECK ($field_name IN ($commalist))";
                $data_type = 'character varying';
            }
            elsif ( $data_type eq 'set' ) {
                # XXX add a CHECK constraint maybe 
                # (trickier and slower, than enum :)
#                my $len     = length $commalist;
#                $field_def .= " character varying($len) /* set $commalist */";
                $data_type = 'character varying';
            }
            elsif ( $field->is_auto_increment ) {
                $field_def .= ' serial';
#                $seq_name   = mk_name( $table_name.'_'.$field_name, 'sq' );
#                push @sequence_defs, qq[DROP SEQUENCE "$seq_name";];
#                push @sequence_defs, qq[CREATE SEQUENCE "$seq_name";];
            }
            else {
                $data_type  = defined $translate{ $data_type } ?
                              $translate{ $data_type } :
                              $data_type;
            }

            $field_def .= " $data_type";

            if ( defined $size[0] && $size[0] > 0 ) {
                $field_def .= '(' . join( ', ', @size ) . ')';
            }

            #
            # Default value
            #
            my $default = $field->default_value;
            if ( defined $default ) {
                $field_def .= sprintf( ' DEFAULT %s',
                    ( $field->is_auto_increment && $seq_name )
                    ? qq[nextval('"$seq_name"'::text)] :
                    ( $default =~ m/null/i ) ? 'NULL' : "'$default'"
                );
            }

            #
            # Not null constraint
            #
            $field_def .= ' NOT NULL' unless $field->is_nullable;

            push @field_defs, $field_def;
        }

        #
        # Index Declarations
        #
        my @index_defs = ();
        my $idx_name_default;
        for my $index ( $table->get_indices ) {
            my $name = $index->name || '';
            my $type = $index->type || NORMAL;
            my @fields     = 
                map { $_ =~ s/\(.+\)//; $_ }
                map { unreserve( $_, $table_name ) }
                $index->fields;
            next unless @fields;

            if ( $type eq PRIMARY_KEY ) {
                $name ||= mk_name( $table_name, 'pk' );
                push @constraint_defs, 'CONSTRAINT '.$name.' PRIMARY KEY '.
                    '(' . join( ', ', @fields ) . ')';
            }
            elsif ( $type eq UNIQUE ) {
                $name ||= mk_name( 
                    $table_name, $name || ++$idx_name_default
                );
                push @constraint_defs, 'CONSTRAINT ' . $name . ' UNIQUE ' .
                    '(' . join( ', ', @fields ) . ')';
            }
            elsif ( $type eq NORMAL ) {
                $name ||= mk_name( 
                    $table_name, $name || ++$idx_name_default
                );
                push @index_defs, 
                    qq[CREATE INDEX "$name" on $table_name_ur (].
                        join( ', ', @fields ).  
                    ');'; 
            }
            else {
                warn "Unknown index type ($type) on table $table_name.\n"
                    if $WARN;
            }
        }

        #
        # Table constraints
        #
        my $c_name_default;
        for my $c ( $table->get_constraints ) {
            my $name = $c->name || '';
            my @fields     = 
                map { $_ =~ s/\(.+\)//; $_ }
                map { unreserve( $_, $table_name ) }
                $c->fields;
            my @rfields     = 
                map { $_ =~ s/\(.+\)//; $_ }
                map { unreserve( $_, $table_name ) }
                $c->reference_fields;
            next unless @fields;

            if ( $c->type eq PRIMARY_KEY ) {
                $name ||= mk_name( $table_name, 'pk' );
                push @constraint_defs, "CONSTRAINT $name PRIMARY KEY ".
                    '(' . join( ', ', @fields ) . ')';
            }
            elsif ( $c->type eq UNIQUE ) {
                $name ||= mk_name( 
                    $table_name, $name || ++$c_name_default
                );
                push @constraint_defs, "CONSTRAINT $name UNIQUE " .
                    '(' . join( ', ', @fields ) . ')';
            }
            elsif ( $c->type eq FOREIGN_KEY ) {
                my $def = join(' ', 
                    map { $_ || () } 'FOREIGN KEY', $c->name 
                );

                $def .= ' (' . join( ', ', @fields ) . ')';

                $def .= ' REFERENCES ' . $c->reference_table;

                if ( @rfields ) {
                    $def .= ' (' . join( ', ', @rfields ) . ')';
                }

                if ( $c->match_type ) {
                    $def .= ' MATCH ' . 
                        ( $c->match_type =~ /full/i ) ? 'FULL' : 'PARTIAL';
                }

                if ( $c->on_delete ) {
                    $def .= ' ON DELETE '.join( ' ', $c->on_delete );
                }

                if ( $c->on_update ) {
                    $def .= ' ON UPDATE '.join( ' ', $c->on_update );
                }

                push @constraint_defs, $def;
            }
        }

        my $create_statement;
        $create_statement  = qq[DROP TABLE "$table_name_ur";\n] 
            if $add_drop_table;
        $create_statement .= qq[CREATE TABLE "$table_name_ur" (\n].
            join( ",\n", map { "  $_" } @field_defs, @constraint_defs ).
            "\n);"
        ;

        $output .= join( "\n\n", 
            @comments,
            @sequence_defs, 
            $create_statement, 
            @index_defs, 
            '' 
        );
    }

    if ( $WARN ) {
        if ( %truncated ) {
            warn "Truncated " . keys( %truncated ) . " names:\n";
            warn "\t" . join( "\n\t", sort keys %truncated ) . "\n";
        }

        if ( %unreserve ) {
            warn "Encounted " . keys( %unreserve ) .
                " unsafe names in schema (reserved or invalid):\n";
            warn "\t" . join( "\n\t", sort keys %unreserve ) . "\n";
        }
    }

    return $output;
}

# -------------------------------------------------------------------
sub mk_name {
    my $basename      = shift || ''; 
    my $type          = shift || ''; 
    my $scope         = shift || ''; 
    my $critical      = shift || '';
    my $basename_orig = $basename;
    my $max_name      = $type 
                        ? $max_id_length - (length($type) + 1) 
                        : $max_id_length;
    $basename         = substr( $basename, 0, $max_name ) 
                        if length( $basename ) > $max_name;
    my $name          = $type ? "${type}_$basename" : $basename;

    if ( $basename ne $basename_orig and $critical ) {
        my $show_type = $type ? "+'$type'" : "";
        warn "Truncating '$basename_orig'$show_type to $max_id_length ",
            "character limit to make '$name'\n" if $WARN;
        $truncated{ $basename_orig } = $name;
    }

    $scope ||= \%global_names;
    if ( my $prev = $scope->{ $name } ) {
        my $name_orig = $name;
        $name        .= sprintf( "%02d", ++$prev );
        substr($name, $max_id_length - 3) = "00" 
            if length( $name ) > $max_id_length;

        warn "The name '$name_orig' has been changed to ",
             "'$name' to make it unique.\n" if $WARN;

        $scope->{ $name_orig }++;
    }

    $scope->{ $name }++;
    return $name;
}

# -------------------------------------------------------------------
sub unreserve {
    my $name            = shift || '';
    my $schema_obj_name = shift || '';

    my ( $suffix ) = ( $name =~ s/(\W.*)$// ) ? $1 : '';

    # also trap fields that don't begin with a letter
    return $name if !$reserved{ uc $name } && $name =~ /^[a-z]/i; 

    if ( $schema_obj_name ) {
        ++$unreserve{"$schema_obj_name.$name"};
    }
    else {
        ++$unreserve{"$name (table name)"};
    }

    my $unreserve = sprintf '%s_', $name;
    return $unreserve.$suffix;
}

1;

# -------------------------------------------------------------------
# Life is full of misery, loneliness, and suffering --
# and it's all over much too soon.
# Woody Allen
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
