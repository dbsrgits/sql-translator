package SQL::Translator::Producer::Oracle;

# -------------------------------------------------------------------
# $Id: Oracle.pm,v 1.8 2002-12-11 01:44:54 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2002 Ken Y. Clark <kclark@cpan.org>,
#                    darren chamberlain <darren@cpan.org>
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
use vars qw[ $VERSION $DEBUG $WARN ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

my %translate  = (
    #
    # MySQL types
    #
    bigint     => 'number',
    double     => 'number',
    decimal    => 'number',
    float      => 'number',
    int        => 'number',
    mediumint  => 'number',
    smallint   => 'number',
    tinyint    => 'number',
    char       => 'char',
    varchar    => 'varchar2',
    tinyblob   => 'CLOB',
    blob       => 'CLOB',
    mediumblob => 'CLOB',
    longblob   => 'CLOB',
    longtext   => 'long',
    mediumtext => 'long',
    text       => 'long',
    tinytext   => 'long',
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
    smallint            => '',
    integer             => '',
    bigint              => '',
    decimal             => '',
    numeric             => '',
    real                => '',
    'double precision'  => '',
    serial              => '',
    bigserial           => '',
    money               => '',
    character           => '',
    'character varying' => '',
    bytea               => '',
    interval            => '',
    boolean             => '',
    point               => '',
    line                => '',
    lseg                => '',
    box                 => '',
    path                => '',
    polygon             => '',
    circle              => '',
    cidr                => '',
    inet                => '',
    macaddr             => '',
    bit                 => '',
    'bit varying'       => '',
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
    my ( $translator, $data ) = @_;
    $DEBUG                    = $translator->debug;
    $WARN                     = $translator->show_warnings;
    my $no_comments           = $translator->no_comments;
    my $add_drop_table        = $translator->add_drop_table;
    my $output;

    unless ( $no_comments ) {
        $output .=  sprintf 
            "--\n-- Created by %s\n-- Created on %s\n--\n\n",
            __PACKAGE__, scalar localtime;
    }

    if ( $translator->parser_type =~ /mysql/i ) {
        $output .= 
        "-- We assume that default NLS_DATE_FORMAT has been changed\n".
        "-- but we set it here anyway to be self-consistent.\n".
        "ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';\n\n";
    }

    #
    # Print create for each table
    #
    for my $table ( 
        map  { $_->[1] }
        sort { $a->[0] <=> $b->[0] }
        map  { [ $_->{'order'}, $_ ] }
        values %{ $data }
    ) { 
        my $table_name    = $table->{'table_name'};
        $table_name       = mk_name( $table_name, '', undef, 1 );
        my $table_name_ur = unreserve($table_name);

        my ( @comments, @field_decs, @trigger_decs );

        push @comments, "--\n-- Table: $table_name_ur\n--" unless $no_comments;

        my %field_name_scope;
        for my $field ( 
            map  { $_->[1] }
            sort { $a->[0] <=> $b->[0] }
            map  { [ $_->{'order'}, $_ ] }
            values %{ $table->{'fields'} }
        ) {
            #
            # Field name
            #
            my $field_name    = mk_name(
                $field->{'name'}, '', \%field_name_scope, 1 
            );
            my $field_name_ur = unreserve( $field_name, $table_name );
            my $field_str     = $field_name_ur;

            #
            # Datatype
            #
            my $check;
            my $data_type = lc $field->{'data_type'};
            my $list      = $field->{'list'} || [];
            my $commalist = join ",", @$list;

            if ( $data_type eq 'enum' ) {
                my $len = 0;
                $len = ($len < length($_)) ? length($_) : $len for (@$list);
                $check = "CHECK ($field_name IN ($commalist))";
                $field_str .= " varchar2($len)";
            }
            elsif ( $data_type eq 'set' ) {
                # XXX add a CHECK constraint maybe 
                # (trickier and slower, than enum :)
                my $len     = length $commalist;
                $field_str .= " varchar2($len) /* set $commalist */ ";
            }
            else {
                $data_type  = defined $translate{ $data_type } ?
                              $translate{ $data_type } :
                              die "Unknown datatype: $data_type\n";
                $field_str .= ' '.$data_type;
                $field_str .= '('.join(',', @{ $field->{'size'} }).')' 
                    if @{ $field->{'size'} || [] };
            }

            #
            # Default value
            #
            if ( defined $field->{'default'} ) {
                $field_str .= sprintf(
                    ' DEFAULT %s',
                    $field->{'default'} =~ m/null/i ? 'NULL' : 
                    "'".$field->{'default'}."'"
                );
            }

            #
            # Not null constraint
            #
            unless ( $field->{'null'} ) {
                my $constraint_name = mk_name($field_name_ur, 'nn');
                $field_str .= ' CONSTRAINT ' . $constraint_name . ' NOT NULL';
            }

            $field_str .= " $check" if $check;

            #
            # Auto_increment
            #
            if ( $field->{'is_auto_inc'} ) {
                my $base_name    = $table_name . "_". $field_name;
                my $seq_name     = mk_name( $base_name, 'sq' );
                my $trigger_name = mk_name( $base_name, 'ai' );

                push @trigger_decs, 
                    "CREATE SEQUENCE $seq_name;\n" .
                    "CREATE OR REPLACE TRIGGER $trigger_name\n" .
                    "BEFORE INSERT ON $table_name\n" .
                    "FOR EACH ROW WHEN (\n" .
                        " new.$field_name_ur IS NULL".
                        " OR new.$field_name_ur = 0\n".
                    ")\n".
                    "BEGIN\n" .
                        " SELECT $seq_name.nextval\n" .
                        " INTO :new." . $field->{'name'}."\n" .
                        " FROM dual;\n" .
                    "END;\n/";
                ;
            }

            if ( uc $field->{'data_type'} eq 'TIMESTAMP' ) {
                my $base_name = $table_name . "_". $field_name_ur;
                my $trig_name = mk_name( $base_name, 'ts' );
                push @trigger_decs, 
                    "CREATE OR REPLACE TRIGGER $trig_name\n".
                    "BEFORE INSERT OR UPDATE ON $table_name_ur\n".
                    "FOR EACH ROW WHEN (new.$field_name_ur} IS NULL)\n".
                    "BEGIN \n".
                    " SELECT sysdate INTO :new.$field_name_ur} FROM dual;\n".
                    "END;\n/";
            }

            push @field_decs, $field_str;
        }

        #
        # Index Declarations
        #
        my @index_decs = ();
        my $idx_name_default;
        for my $index ( @{ $table->{'indices'} } ) {
            my $index_name = $index->{'name'} || '';
            my $index_type = $index->{'type'} || 'normal';
            my @fields     = map { unreserve( $_, $table_name ) }
                             @{ $index->{'fields'} };
            next unless @fields;

            if ( $index_type eq 'primary_key' ) {
                $index_name = mk_name( $table_name, 'pk' );
                push @field_decs, 'CONSTRAINT '.$index_name.' PRIMARY KEY '.
                    '(' . join( ', ', @fields ) . ')';
            }
            elsif ( $index_type eq 'unique' ) {
                $index_name = mk_name( 
                    $table_name, $index_name || ++$idx_name_default
                );
                push @field_decs, 'CONSTRAINT ' . $index_name . ' UNIQUE ' .
                    '(' . join( ', ', @fields ) . ')';
            }

            elsif ( $index_type eq 'normal' ) {
                $index_name = mk_name( 
                    $table_name, $index_name || ++$idx_name_default
                );
                push @index_decs, 
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
        $create_statement .= "CREATE TABLE $table_name_ur (\n".
            join( ",\n", map { "  $_" } @field_decs ).
            "\n);"
        ;

        $output .= join( "\n\n", 
            @comments,
            $create_statement, 
            @trigger_decs, 
            @index_decs, 
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
    my ($basename, $type, $scope, $critical) = @_;
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
    my ( $name, $schema_obj_name ) = @_;
    my ( $suffix ) = ( $name =~ s/(\W.*)$// ) ? $1 : '';

    # also trap fields that don't begin with a letter
    return $_[0] if !$ora_reserved{ uc $name } && $name =~ /^[a-z]/i; 

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

=head1 NAME

SQL::Translator::Producer::Oracle - Oracle SQL producer

=head1 SYNOPSIS

  use SQL::Translator::Parser::MySQL;
  use SQL::Translator::Producer::Oracle;

  my $original_create = ""; # get this from somewhere...
  my $translator = SQL::Translator->new;

  $translator->parser("SQL::Translator::Parser::MySQL");
  $translator->producer("SQL::Translator::Producer::Oracle");

  my $new_create = $translator->translate($original_create);

=head1 DESCRIPTION

SQL::Translator::Producer::Oracle takes a parsed data structure,
created by a SQL::Translator::Parser subclass, and turns it into a
create string suitable for use with an Oracle database.

=head1 CREDITS

A hearty "thank-you" to Tim Bunce for much of the logic stolen from 
his "mysql2ora" script.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=head1 SEE ALSO

perl(1).

=cut
