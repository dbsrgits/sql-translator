package SQL::Translator::Producer::PostgreSQL;

# -------------------------------------------------------------------
# $Id: PostgreSQL.pm,v 1.3 2002-11-26 03:59:58 kycl4rk Exp $
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

=head1 NAME

SQL::Translator::Producer::PostgreSQL - PostgreSQL producer for SQL::Translator

=cut

use strict;
use vars qw[ $DEBUG $WARN $VERSION ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/;
$DEBUG = 1 unless defined $DEBUG;

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
    varchar    => 'varchar',
    longtext   => 'text',
    mediumtext => 'text',
    text       => 'text',
    tinytext   => 'text',
    tinyblob   => 'bytea',
    blob       => 'bytea',
    mediumblob => 'bytea',
    longblob   => 'bytea',
    enum       => 'varchar',
    set        => 'varchar',
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
    varchar2   => 'varchar',
    long       => 'text',
    CLOB       => 'bytea',
    date       => 'date',

    #
    # Sybase types
    #
    int        => 'integer',
    money      => 'money',
    varchar    => 'varchar',
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

=cut

# -------------------------------------------------------------------
sub produce {
    my ( $translator, $data ) = @_;
    $DEBUG                    = $translator->debug;
    $WARN                     = $translator->show_warnings;
    my $no_comments           = $translator->no_comments;
    my $add_drop_table        = $translator->add_drop_table;

    my $create;
    unless ( $no_comments ) {
        $create .=  sprintf 
            "--\n-- Created by %s\n-- Created on %s\n--\n\n",
            __PACKAGE__, scalar localtime;
    }

    for my $table ( 
        map  { $_->[1] }
        sort { $a->[0] <=> $b->[0] }
        map  { [ $_->{'order'}, $_ ] }
        values %$data
   ) {
        my $table_name = $table->{'table_name'};
        my @fields     = 
            map  { $_->[1] }
            sort { $a->[0] <=> $b->[0] }
            map  { [ $_->{'order'}, $_ ] }
            values %{ $table->{'fields'} };

        $create .= "--\n-- Table: $table_name\n--\n" unless $no_comments;
        $create  = "DROP TABLE $table_name;\n" if $add_drop_table;
        $create .= "CREATE TABLE $table_name (\n";

        #
        # Fields
        #
        my %field_name_scope;
        my @field_statements;
        for my $field ( @fields ) {
            my @fdata = ("", $field);

            my $field_name    = mk_name(
                $field->{'name'}, '', \%field_name_scope, 1 
            );
            my $field_name_ur = unreserve( $field_name, $table_name );
            my $field_str     = $field_name_ur;

            # data type and size
            push @fdata, sprintf "%s%s", 
                $field->{'data_type'},
                ( defined $field->{'size'} ) 
                    ? "($field->{'size'})" : '';

            # Null?
            push @fdata, "NOT NULL" unless $field->{'null'};

            # Default?  XXX Need better quoting!
            my $default = $field->{'default'};
            if ( defined $default ) {
                push @fdata, "DEFAULT '$default'";
#                if (int $default eq "$default") {
#                    push @fdata, "DEFAULT $default";
#                } else {
#                    push @fdata, "DEFAULT '$default'";
#                }
            }

            # auto_increment?
            push @fdata, "auto_increment" if $field->{'is_auto_inc'};

            # primary key?
            push @fdata, "PRIMARY KEY" if $field->{'is_primary_key'};

            push @field_statements, join( " ", @fdata );

        }
        $create .= join( ",\n", @field_statements );

        #
        # Other keys
        #
        my @indices = @{ $table->{'indices'} || [] };
        for ( my $i = 0; $i <= $#indices; $i++ ) {
            $create .= ",\n";
            my $key = $indices[$i];
            my ( $name, $type, $fields ) = @{ $key }{ qw( name type fields ) };
            if ( $type eq 'primary_key' ) {
                $create .= " PRIMARY KEY (@{$fields})"
            } 
            else {
                local $" = ", ";
                $create .= " KEY $name (@{$fields})"
            }
        }

        #
        # Footer
        #
        $create .= "\n);\n\n";
    }

    return $create;
}

# -------------------------------------------------------------------
sub mk_name {
    my ($basename, $type, $scope, $critical) = @_;
    my $basename_orig = $basename;
    my $max_name      = $max_id_length - (length($type) + 1);
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
    return $_[0] if !$reserved{ uc $name } && $name =~ /^[a-z]/i; 

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
