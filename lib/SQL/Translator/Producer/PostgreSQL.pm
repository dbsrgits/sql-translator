package SQL::Translator::Producer::PostgreSQL;

# -------------------------------------------------------------------
# $Id: PostgreSQL.pm,v 1.20 2003-10-15 19:07:13 kycl4rk Exp $
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

=head1 SYNOPSIS

  my $t = SQL::Translator->new( parser => '...', producer => 'PostgreSQL' );
  $t->translate;

=head1 DESCRIPTION

Creates a DDL suitable for PostgreSQL.  Very heavily based on the Oracle
producer.

=cut

use strict;
use vars qw[ $DEBUG $WARN $VERSION ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.20 $ =~ /(\d+)\.(\d+)/;
$DEBUG = 1 unless defined $DEBUG;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(header_comment);
use Data::Dumper;

my %translate  = (
    #
    # MySQL types
    #
    bigint     => 'bigint',
    double     => 'numeric',
    decimal    => 'numeric',
    float      => 'numeric',
    int        => 'integer',
    mediumint  => 'integer',
    smallint   => 'smallint',
    tinyint    => 'smallint',
    char       => 'character',
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
    char       => 'character',
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
    real       => 'numeric',
    comment    => 'text',
    bit        => 'bit',
    tinyint    => 'smallint',
    float      => 'numeric',
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
    my %used_index_names;

    my @fks;
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
            # todo deal with embedded quotes
            my $commalist = join( ', ', map { qq['$_'] } @$list );
            my $seq_name;

            if ( $data_type eq 'enum' ) {
                my $len = 0;
                $len = ($len < length($_)) ? length($_) : $len for (@$list);
                my $chk_name = mk_name( $table_name.'_'.$field_name, 'chk' );
                push @constraint_defs, 
                    qq[Constraint "$chk_name" CHECK ("$field_name" ].
                    qq[IN ($commalist))];
                $data_type = 'character varying';
            }
            elsif ( $data_type eq 'set' ) {
                $data_type = 'character varying';
            }
            elsif ( $field->is_auto_increment ) {
                if ( defined $size[0] && $size[0] > 11 ) {
                    $data_type = 'bigserial';
                }
                else {
                    $data_type = 'serial';
                }
                undef @size;
            }
            else {
                $data_type  = defined $translate{ $data_type } ?
                              $translate{ $data_type } :
                              $data_type;
            }

            if ( $data_type =~ /timestamp/i ) {
                if ( defined $size[0] && $size[0] > 6 ) {
                    $size[0] = 6;
                }
            }

            if ( $data_type eq 'integer' ) {
                if ( defined $size[0] ) {
                    if ( $size[0] > 10 ) {
                        $data_type = 'bigint';
                    }
                    elsif ( $size[0] < 5 ) {
                        $data_type = 'smallint';
                    }
                    else {
                        $data_type = 'integer';
                    }
                }
                else {
                    $data_type = 'integer';
                }
            }

            #
            # PG doesn't need a size for integers or text
            #
            undef @size if $data_type =~ m/(integer|smallint|bigint|text)/;
            
            $field_def .= " $data_type";

            if ( defined $size[0] && $size[0] > 0 ) {
                $field_def .= '(' . join( ',', @size ) . ')';
            }

            #
            # Default value -- disallow for timestamps
            #
            my $default = $data_type =~ /(timestamp|date)/i
                ? undef : $field->default_value;
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
            if ( $name ) {
                $name = next_unused_name($name, \%used_index_names);
                $used_index_names{$name} = $name;
            }

            my $type = $index->type || NORMAL;
            my @fields     = 
                map { $_ =~ s/\(.+\)//; $_ }
                map { unreserve( $_, $table_name ) }
                $index->fields;
            next unless @fields;

            my $def_start = qq[Constraint "$name" ];
            if ( $type eq PRIMARY_KEY ) {
                push @constraint_defs, "${def_start}PRIMARY KEY ".
                    '("' . join( '", "', @fields ) . '")';
            }
            elsif ( $type eq UNIQUE ) {
                push @constraint_defs, "${def_start}UNIQUE " .
                    '("' . join( '", "', @fields ) . '")';
            }
            elsif ( $type eq NORMAL ) {
                push @index_defs, 
                    'CREATE INDEX "' . $name . "\" on $table_name_ur (".
                        join( ', ', map { qq["$_"] } @fields ).  
                    ');'
                ; 
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
            if ( $name ) {
                $name = next_unused_name($name, \%used_index_names);
                $used_index_names{$name} = $name;
            }

            my @fields     = 
                map { $_ =~ s/\(.+\)//; $_ }
                map { unreserve( $_, $table_name ) }
                $c->fields;

            my @rfields     = 
                map { $_ =~ s/\(.+\)//; $_ }
                map { unreserve( $_, $table_name ) }
                $c->reference_fields;

            next if !@fields && $c->type ne CHECK_C;

            my $def_start = $name ? qq[Constraint "$name" ] : '';
            if ( $c->type eq PRIMARY_KEY ) {
                push @constraint_defs, "${def_start}PRIMARY KEY ".
                    '("' . join( '", "', @fields ) . '")';
            }
            elsif ( $c->type eq UNIQUE ) {
                $name = next_unused_name($name, \%used_index_names);
                $used_index_names{$name} = $name;
                push @constraint_defs, "${def_start}UNIQUE " .
                    '("' . join( '", "', @fields ) . '")';
            }
            elsif ( $c->type eq CHECK_C ) {
                my $expression = $c->expression;
                push @constraint_defs, "${def_start}CHECK ($expression)";
            }
            elsif ( $c->type eq FOREIGN_KEY ) {
                my $def .= "ALTER TABLE $table_name ADD FOREIGN KEY (" . 
                    join( ', ', map { qq["$_"] } @fields ) . ')' .
                    "\n  REFERENCES " . $c->reference_table;

                if ( @rfields ) {
                    $def .= ' ("' . join( '", "', @rfields ) . '")';
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

                push @fks, "$def;";
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

    if ( @fks ) {
        $output .= "--\n-- Foreign Key Definitions\n--\n\n" unless $no_comments;
        $output .= join( "\n\n", @fks );
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

# -------------------------------------------------------------------
sub next_unused_name {
    my $name       = shift || '';
    my $used_names = shift || '';

    my %used_names = %$used_names;

    if ( !defined($used_names{$name}) ) {
        $used_names{$name} = $name;
        return $name;
    }
    
    my $i = 2;
    while ( defined($used_names{$name . $i}) ) {
        ++$i;
    }
    $name .= $i;
    $used_names{$name} = $name;
    return $name;
}

1;

# -------------------------------------------------------------------
# Life is full of misery, loneliness, and suffering --
# and it's all over much too soon.
# Woody Allen
# -------------------------------------------------------------------

=pod

=head1 SEE ALSO

SQL::Translator, SQL::Translator::Producer::Oracle.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=cut
