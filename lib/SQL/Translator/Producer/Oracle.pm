package SQL::Translator::Producer::Oracle;

# -------------------------------------------------------------------
# $Id: Oracle.pm,v 1.31 2004-06-04 19:39:48 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2002-4 SQLFairy Authors
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

SQL::Translator::Producer::Oracle - Oracle SQL producer

=head1 SYNOPSIS

  use SQL::Translator;

  my $t = SQL::Translator->new( parser => '...', producer => 'Oracle' );
  print $translator->translate( $file );

=head1 DESCRIPTION

Creates an SQL DDL suitable for Oracle.

=cut

use strict;
use vars qw[ $VERSION $DEBUG $WARN ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.31 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(header_comment);

my %translate  = (
    #
    # MySQL types
    #
    bigint     => 'number',
    double     => 'number',
    decimal    => 'number',
    float      => 'number',
    int        => 'number',
    integer    => 'number',
    mediumint  => 'number',
    smallint   => 'number',
    tinyint    => 'number',
    char       => 'char',
    varchar    => 'varchar2',
    tinyblob   => 'blob',
    blob       => 'blob',
    mediumblob => 'blob',
    longblob   => 'blob',
    tinytext   => 'varchar2',
    text       => 'clob',
    longtext   => 'clob',
    mediumtext => 'clob',
    enum       => 'varchar2',
    set        => 'varchar2',
    date       => 'date',
    datetime   => 'date',
    time       => 'date',
    timestamp  => 'date',
    year       => 'date',

    #
    # PostgreSQL types
    #
    numeric             => 'number',
    'double precision'  => 'number',
    serial              => 'number',
    bigserial           => 'number',
    money               => 'number',
    character           => 'char',
    'character varying' => 'varchar2',
    bytea               => 'BLOB',
    interval            => 'number',
    boolean             => 'number',
    point               => 'number',
    line                => 'number',
    lseg                => 'number',
    box                 => 'number',
    path                => 'number',
    polygon             => 'number',
    circle              => 'number',
    cidr                => 'number',
    inet                => 'varchar2',
    macaddr             => 'varchar2',
    bit                 => 'number',
    'bit varying'       => 'number',

    #
    # Oracle types
    #
    number              => 'number',
    varchar2            => 'varchar2',
    long                => 'clob',
);

#
# Oracle reserved words from:
# http://technet.oracle.com/docs/products/oracle8i/doc_library/\
# 817_doc/server.817/a85397/ap_keywd.htm
#
my %ora_reserved = map { $_, 1 } qw(
    ACCESS ADD ALL ALTER AND ANY AS ASC AUDIT 
    BETWEEN BY
    CHAR CHECK CLUSTER COLUMN COMMENT COMPRESS CONNECT CREATE CURRENT
    DATE DECIMAL DEFAULT DELETE DESC DISTINCT DROP
    ELSE EXCLUSIVE EXISTS 
    FILE FLOAT FOR FROM
    GRANT GROUP 
    HAVING
    IDENTIFIED IMMEDIATE IN INCREMENT INDEX INITIAL INSERT
    INTEGER INTERSECT INTO IS
    LEVEL LIKE LOCK LONG 
    MAXEXTENTS MINUS MLSLABEL MODE MODIFY 
    NOAUDIT NOCOMPRESS NOT NOWAIT NULL NUMBER 
    OF OFFLINE ON ONLINE OPTION OR ORDER
    PCTFREE PRIOR PRIVILEGES PUBLIC
    RAW RENAME RESOURCE REVOKE ROW ROWID ROWNUM ROWS
    SELECT SESSION SET SHARE SIZE SMALLINT START 
    SUCCESSFUL SYNONYM SYSDATE 
    TABLE THEN TO TRIGGER 
    UID UNION UNIQUE UPDATE USER
    VALIDATE VALUES VARCHAR VARCHAR2 VIEW
    WHENEVER WHERE WITH
);

my $max_id_length    = 30;
my %used_identifiers = ();
my %global_names;
my %unreserve;
my %truncated;

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

    if ( $translator->parser_type =~ /mysql/i ) {
        $output .= 
            "-- We assume that default NLS_DATE_FORMAT has been changed\n".
            "-- but we set it here anyway to be self-consistent.\n"
            unless $no_comments;

        $output .= 
        "ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';\n\n";
    }

    #
    # Print create for each table
    #
    for my $table ( $schema->get_tables ) { 
        my $table_name    = $table->name or next;
        $table_name       = mk_name( $table_name, '', undef, 1 );
        my $table_name_ur = unreserve($table_name) or next;

        my ( @comments, @field_defs, @trigger_defs, @constraint_defs );

        push @comments, "--\n-- Table: $table_name_ur\n--" unless $no_comments;

        my ( %field_name_scope, @field_comments );
        for my $field ( $table->get_fields ) {
            #
            # Field name
            #
            my $field_name    = mk_name(
                $field->name, '', \%field_name_scope, 1 
            );
            my $field_name_ur = unreserve( $field_name, $table_name );
            my $field_def     = $field_name_ur;

            #
            # Datatype
            #
            my $check;
            my $data_type = lc $field->data_type;
            my @size      = $field->size;
            my %extra     = $field->extra;
            my $list      = $extra{'list'} || [];
            # \todo deal with embedded quotes
            my $commalist = join( ', ', map { qq['$_'] } @$list );

            if ( $data_type eq 'enum' ) {
                $check = "CHECK ($field_name_ur IN ($commalist))";
                $data_type = 'varchar2';
            }
            elsif ( $data_type eq 'set' ) {
                # XXX add a CHECK constraint maybe 
                # (trickier and slower, than enum :)
                $data_type = 'varchar2';
            }
            else {
                $data_type  = defined $translate{ $data_type } ?
                              $translate{ $data_type } :
                              $data_type;
                $data_type ||= 'varchar2';
            }
            
            #
            # Fixes ORA-02329: column of datatype LOB cannot be 
            # unique or a primary key
            #
            if ( $data_type eq 'clob' && $field->is_primary_key ) {
                $data_type = 'varchar2';
                $size[0]   = 4000;
                warn "CLOB cannot be a primary key, changing to VARCHAR2\n"
                    if $WARN;
            }

            #
            # Fixes ORA-00907: missing right parenthesis
            #
            if ( $data_type =~ /(date|clob)/i ) {
                undef @size;
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
                #
                # Wherein we try to catch a string being used as 
                # a default value for a numerical field.  If "true/false,"
                # then sub "1/0," otherwise just test the truthity of the
                # argument and use that (naive?).
                #
                if ( 
                    $data_type =~ /^number$/i && 
                    $default   !~ /^\d+$/     &&
                    $default   !~ m/null/i
                ) {
                    if ( $default =~ /^true$/i ) {
                        $default = "'1'";
                    }
                    elsif ( $default =~ /^false$/i ) {
                        $default = "'0'";
                    }
                    else {
                        $default = $default ? "'1'" : "'0'";
                    }
                }
                elsif ( 
                    $data_type =~ /date/ && (
                        $default eq 'current_timestamp' 
                        ||
                        $default eq 'now()' 
                    )
                ) {
                    $default = 'SYSDATE';
                }
                else {
                    $default = $default =~ m/null/i ? 'NULL' : "'$default'"
                } 

                $field_def .= " DEFAULT $default",
            }

            #
            # Not null constraint
            #
            unless ( $field->is_nullable ) {
                $field_def .= ' NOT NULL';
            }

            $field_def .= " $check" if $check;

            #
            # Auto_increment
            #
            if ( $field->is_auto_increment ) {
                my $base_name    = $table_name . "_". $field_name;
                my $seq_name     = mk_name( $base_name, 'sq' );
                my $trigger_name = mk_name( $base_name, 'ai' );

                push @trigger_defs, 
                    "CREATE SEQUENCE $seq_name;\n" .
                    "CREATE OR REPLACE TRIGGER $trigger_name\n" .
                    "BEFORE INSERT ON $table_name_ur\n" .
                    "FOR EACH ROW WHEN (\n" .
                        " new.$field_name_ur IS NULL".
                        " OR new.$field_name_ur = 0\n".
                    ")\n".
                    "BEGIN\n" .
                        " SELECT $seq_name.nextval\n" .
                        " INTO :new." . $field->name."\n" .
                        " FROM dual;\n" .
                    "END;\n/";
                ;
            }

            if ( lc $field->data_type eq 'timestamp' ) {
                my $base_name = $table_name . "_". $field_name_ur;
                my $trig_name = mk_name( $base_name, 'ts' );
                push @trigger_defs, 
                    "CREATE OR REPLACE TRIGGER $trig_name\n".
                    "BEFORE INSERT OR UPDATE ON $table_name_ur\n".
                    "FOR EACH ROW WHEN (new.$field_name_ur IS NULL)\n".
                    "BEGIN \n".
                    " SELECT sysdate INTO :new.$field_name_ur FROM dual;\n".
                    "END;\n/";
            }

            push @field_defs, $field_def;

            if ( my $comment = $field->comments ) {
                push @field_comments, 
                    "COMMENT ON COLUMN $table_name.$field_name_ur is\n  '".
                    $comment."';" unless $no_comments;
            }
        }

        #
        # Table options
        #
        my @table_options;
        for my $opt ( $table->options ) {
            if ( ref $opt eq 'HASH' ) {
                my ( $key, $value ) = each %$opt;
                if ( ref $value eq 'ARRAY' ) {
                    push @table_options, "$key\n(\n".  join ("\n",
                        map { "  $_->[0]\t$_->[1]" } 
                        map { [ each %$_ ] }
                        @$value
                    )."\n)";
                }
                elsif ( !defined $value ) {
                    push @table_options, $key;
                }
                else {
                    push @table_options, "$key    $value";
                }
            }
        }

        #
        # Table constraints
        #
        for my $c ( $table->get_constraints ) {
            my $name    = $c->name || '';
            my @fields  = map { unreserve( $_, $table_name ) } $c->fields;
            my @rfields = map { unreserve( $_, $table_name ) } 
                $c->reference_fields;
            next if !@fields && $c->type ne CHECK_C;

            if ( $c->type eq PRIMARY_KEY ) {
                $name ||= mk_name( $table_name, 'pk' );
                push @constraint_defs, "CONSTRAINT $name PRIMARY KEY ".
                    '(' . join( ', ', @fields ) . ')';
            }
            elsif ( $c->type eq UNIQUE ) {
                $name = mk_name( $name || $table_name, 'u' );

                for my $f ( $c->fields ) {
                    my $field_def = $table->get_field( $f ) or next;
                    my $dtype     = $translate{ $field_def->data_type } or next;
                    if ( $WARN && $dtype =~ /clob/i ) {
                        warn "Oracle will not allow UNIQUE constraints on " .
                             "CLOB field '" . $field_def->table->name . '.' .
                             $field_def->name . ".'\n"
                    }
                }

                push @constraint_defs, "CONSTRAINT $name UNIQUE " .
                    '(' . join( ', ', @fields ) . ')';
            }
            elsif ( $c->type eq CHECK_C ) {
                $name = mk_name( $name || $table_name, 'ck' );
                my $expression = $c->expression || '';
                push @constraint_defs, "CONSTRAINT $name CHECK ($expression)";
            }
            elsif ( $c->type eq FOREIGN_KEY ) {
                $name = mk_name( join('_', $table_name, $c->fields), 'fk' );
                my $def = "CONSTRAINT $name FOREIGN KEY ";

                if ( @fields ) {
                    $def .= '(' . join( ', ', @fields ) . ')';
                }

                my $ref_table = unreserve($c->reference_table);

                $def .= " REFERENCES $ref_table";

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

        #
        # Index Declarations
        #
        my @index_defs = ();
        for my $index ( $table->get_indices ) {
            my $index_name = $index->name || '';
            my $index_type = $index->type || NORMAL;
            my @fields     = map { unreserve( $_, $table_name ) }
                             $index->fields;
            next unless @fields;

            if ( $index_type eq PRIMARY_KEY ) {
                $index_name = $index_name ? mk_name( $index_name ) 
                    : mk_name( $table_name, 'pk' );
                push @field_defs, 'CONSTRAINT '.$index_name.' PRIMARY KEY '.
                    '(' . join( ', ', @fields ) . ')';
            }
            elsif ( $index_type eq NORMAL ) {
                $index_name = $index_name ? mk_name( $index_name ) 
                    : mk_name( $table_name, $index_name || 'i' );
                push @index_defs, 
                    "CREATE INDEX $index_name on $table_name_ur (".
                        join( ', ', @fields ).  
                    ");"; 
            }
            else {
                warn "Unknown index type ($index_type) on table $table_name.\n"
                    if $WARN;
            }
        }

        my $create_statement;
        $create_statement  = "DROP TABLE $table_name_ur;\n" if $add_drop_table;

        if ( my @table_comments = $table->comments ) {
            for my $comment ( @table_comments ) {
                next unless $comment;
                push @field_comments, "COMMENT ON TABLE $table_name is\n  '".
                    $comment."';" unless $no_comments
                ;
            }
        }

        my $table_options = @table_options 
            ? "\n".join("\n", @table_options) : '';
        $create_statement .= "CREATE TABLE $table_name_ur (\n" .
            join( ",\n", map { "  $_" } @field_defs, @constraint_defs ) .
            "\n)$table_options;"
        ;

        $output .= join( "\n\n", 
            @comments,
            $create_statement, 
            @trigger_defs, 
            @index_defs, 
            @field_comments, 
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
       $type          = '' if $type =~ /^\d/;
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
    return $name if !$ora_reserved{ uc $name } && $name =~ /^[a-z]/i; 

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
# All bad art is the result of good intentions.
# Oscar Wilde
# -------------------------------------------------------------------

=pod

=head1 CREDITS

Mad props to Tim Bunce for much of the logic stolen from his "mysql2ora"
script.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

SQL::Translator, DDL::Oracle, mysql2ora.

=cut
