package SQL::Translator::Producer::SQLServer;

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

=head1 NAME

SQL::Translator::Producer::SQLServer - MS SQLServer producer for SQL::Translator

=head1 SYNOPSIS

  use SQL::Translator;

  my $t = SQL::Translator->new( parser => '...', producer => 'SQLServer' );
  $t->translate;

=head1 DESCRIPTION

B<WARNING>B This is still fairly early code, basically a hacked version of the
Sybase Producer (thanks Sam, Paul and Ken for doing the real work ;-)

=head1 Extra Attributes

=over 4

=item field.list

List of values for an enum field.

=back

=head1 TODO

 * !! Write some tests !!
 * Reserved words list needs updating to SQLServer.
 * Triggers, Procedures and Views DO NOT WORK

=cut

use strict;
use vars qw[ $DEBUG $WARN $VERSION ];
$VERSION = '1.59';
$DEBUG = 1 unless defined $DEBUG;

use Data::Dumper;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(debug header_comment);

my %translate  = (
    date      => 'datetime',
    'time'    => 'datetime',
    # Sybase types
    #integer   => 'numeric',
    #int       => 'numeric',
    #number    => 'numeric',
    #money     => 'money',
    #varchar   => 'varchar',
    #varchar2  => 'varchar',
    #timestamp => 'datetime',
    #text      => 'varchar',
    #real      => 'double precision',
    #comment   => 'text',
    #bit       => 'bit',
    #tinyint   => 'smallint',
    #float     => 'double precision',
    #serial    => 'numeric', 
    #boolean   => 'varchar',
    #char      => 'char',
    #long      => 'varchar',
);

# TODO - This is still the Sybase list!
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

# If these datatypes have size appended the sql fails.
my @no_size = qw/tinyint smallint int integer bigint text bit image datetime/;

my $max_id_length    = 128;
my %global_names;
my %unreserve;

=pod

=head1 SQLServer Create Table Syntax

TODO

=cut

# -------------------------------------------------------------------
sub produce {
    my $translator     = shift;
    $DEBUG             = $translator->debug;
    $WARN              = $translator->show_warnings;
    my $no_comments    = $translator->no_comments;
    my $add_drop_table = $translator->add_drop_table;
    my $schema         = $translator->schema;

    %global_names = (); #reset
    %unreserve = ();

    my $output;
    $output .= header_comment."\n" unless ($no_comments);

    # Generate the DROP statements. We do this in one block here as if we
    # have fkeys we need to drop in the correct order otherwise they will fail
    # due to the dependancies the fkeys setup. (There is no way to turn off
    # fkey checking while we sort the schema like MySQL's set
    # foreign_key_checks=0)
    # We assume the tables are in the correct order to set them up as you need
    # to have created a table to fkey to it. So the reverse order should drop
    # them properly, fingers crossed...
    if ($add_drop_table) {
        $output .= "--\n-- Drop tables\n--\n\n" unless $no_comments;
        foreach my $table (
            sort { $b->order <=> $a->order } $schema->get_tables
        ) {
            my $name = unreserve($table->name);
            $output .= qq{IF EXISTS (SELECT name FROM sysobjects WHERE name = '$name' AND type = 'U') DROP TABLE $name;\n\n}
        }
    }

    # Generate the CREATE sql

    my @foreign_constraints = (); # these need to be added separately, as tables may not exist yet

    for my $table ( $schema->get_tables ) {
        my $table_name    = $table->name or next;
        my $table_name_ur = unreserve($table_name) || '';

        my ( @comments, @field_defs, @index_defs, @constraint_defs );

        push @comments, "\n\n--\n-- Table: $table_name_ur\n--"
        unless $no_comments;

        push @comments, map { "-- $_" } $table->comments;

        #
        # Fields
        #
        my %field_name_scope;
        for my $field ( $table->get_fields ) {
            my $field_name    = $field->name;
            my $field_name_ur = unreserve( $field_name, $table_name );
            my $field_def     = qq["$field_name_ur"];
            $field_def        =~ s/\"//g;
            if ( $field_def =~ /identity/ ){
                $field_def =~ s/identity/pidentity/;
            }

            #
            # Datatype
            #
            my $data_type      = lc $field->data_type;
            my $orig_data_type = $data_type;
            my %extra          = $field->extra;
            my $list           = $extra{'list'} || [];
            # \todo deal with embedded quotes
            my $commalist      = join( ', ', map { qq['$_'] } @$list );

            if ( $data_type eq 'enum' ) {
                my $check_name = mk_name( $field_name . '_chk' );
                push @constraint_defs,
                  "CONSTRAINT $check_name CHECK ($field_name IN ($commalist))";
                $data_type .= 'character varying';
            }
            elsif ( $data_type eq 'set' ) {
                $data_type .= 'character varying';
            }
            elsif ( grep { $data_type eq $_ } qw/bytea blob clob/ ) {
                $data_type = 'varbinary';
            }
            else {
                if ( defined $translate{ $data_type } ) {
                    $data_type = $translate{ $data_type };
                }
                else {
                    warn "Unknown datatype: $data_type ",
                        "($table_name.$field_name)\n" if $WARN;
                }
            }

            my $size = $field->size;
            if ( grep $_ eq $data_type, @no_size) {
            # SQLServer doesn't seem to like sizes on some datatypes
                $size = undef;
            }
            elsif ( !$size ) {
                if ( $data_type =~ /numeric/ ) {
                    $size = '9,0';
                }
                elsif ( $orig_data_type eq 'text' ) {
                    #interpret text fields as long varchars
                    $size = '255';
                }
                elsif (
                    $data_type eq 'varchar' &&
                    $orig_data_type eq 'boolean'
                ) {
                    $size = '6';
                }
                elsif ( $data_type eq 'varchar' ) {
                    $size = '255';
                }
            }

            $field_def .= " $data_type";
            $field_def .= "($size)" if $size;

            $field_def .= ' IDENTITY' if $field->is_auto_increment;

            #
            # Not null constraint
            #
            unless ( $field->is_nullable ) {
                $field_def .= ' NOT NULL';
            }
            else {
                $field_def .= ' NULL' if $data_type ne 'bit';
            }

            #
            # Default value
            #
            SQL::Translator::Producer->_apply_default_value(
              $field,
              \$field_def,
              [
                'NULL'       => \'NULL',
              ],
            );

            push @field_defs, $field_def;            
        }

        #
        # Constraint Declarations
        #
        my @constraint_decs = ();
        for my $constraint ( $table->get_constraints ) {
            my $name    = $constraint->name || '';
            # Make sure we get a unique name
            my $type    = $constraint->type || NORMAL;
            my @fields  = map { unreserve( $_, $table_name ) }
                $constraint->fields;
            my @rfields = map { unreserve( $_, $table_name ) }
                $constraint->reference_fields;
            next unless @fields;

            my $c_def;
            if ( $type eq FOREIGN_KEY ) {
                $name ||= mk_name( $table_name . '_fk' );
                my $on_delete = uc ($constraint->on_delete || '');
                my $on_update = uc ($constraint->on_update || '');

                # The default implicit constraint action in MSSQL is RESTRICT
                # but you can not specify it explicitly. Go figure :)
                for ($on_delete, $on_update) {
                  undef $_ if $_ eq 'RESTRICT'
                }

                $c_def = 
                    "ALTER TABLE $table_name ADD CONSTRAINT $name FOREIGN KEY".
                    ' (' . join( ', ', @fields ) . ') REFERENCES '.
                    $constraint->reference_table.
                    ' (' . join( ', ', @rfields ) . ')'
                ;

                if ( $on_delete && $on_delete ne "NO ACTION") {
                  $c_def .= " ON DELETE $on_delete";
                }
                if ( $on_update && $on_update ne "NO ACTION") {
                  $c_def .= " ON UPDATE $on_update";
                }

                $c_def .= ";";

                push @foreign_constraints, $c_def;
                next;
            }


            if ( $type eq PRIMARY_KEY ) {
                $name ||= mk_name( $table_name . '_pk' );
                $c_def = 
                    "CONSTRAINT $name PRIMARY KEY ".
                    '(' . join( ', ', @fields ) . ')';
            }
            elsif ( $type eq UNIQUE ) {
                $name ||= mk_name( $table_name . '_uc' );
                $c_def = 
                    "CONSTRAINT $name UNIQUE " .
                    '(' . join( ', ', @fields ) . ')';
            }
            push @constraint_defs, $c_def;
        }

        #
        # Indices
        #
        for my $index ( $table->get_indices ) {
            my $idx_name = $index->name || mk_name($table_name . '_idx');
            push @index_defs,
                "CREATE INDEX $idx_name ON $table_name (".
                join( ', ', $index->fields ) . ");";
        }

        my $create_statement = "";
        $create_statement .= qq[CREATE TABLE $table_name_ur (\n].
            join( ",\n", 
                map { "  $_" } @field_defs, @constraint_defs
            ).
            "\n);"
        ;

        $output .= join( "\n\n",
            @comments,
            $create_statement,
            @index_defs,
        );
    }

# Add FK constraints
    $output .= join ("\n", '', @foreign_constraints) if @foreign_constraints;

# create view/procedure are NOT prepended to the input $sql, needs
# to be filled in with the proper syntax

=pod

    # Text of view is already a 'create view' statement so no need to
    # be fancy
    foreach ( $schema->get_views ) {
        my $name = $_->name();
        $output .= "\n\n";
        $output .= "--\n-- View: $name\n--\n\n" unless $no_comments;
        my $text = $_->sql();
        $text =~ s/\r//g;
        $output .= "$text\nGO\n";
    }

    # Text of procedure already has the 'create procedure' stuff
    # so there is no need to do anything fancy. However, we should
    # think about doing fancy stuff with granting permissions and
    # so on.
    foreach ( $schema->get_procedures ) {
        my $name = $_->name();
        $output .= "\n\n";
        $output .= "--\n-- Procedure: $name\n--\n\n" unless $no_comments;
        my $text = $_->sql();
		$text =~ s/\r//g;
        $output .= "$text\nGO\n";
    }
=cut

    return $output;
}

# -------------------------------------------------------------------
sub mk_name {
    my ($name, $scope, $critical) = @_;

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
    $name = substr( $name, 0, $max_id_length ) 
                        if ((length( $name ) > $max_id_length) && $critical);
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

=pod

=head1 SEE ALSO

SQL::Translator.

=head1 AUTHORS

Mark Addison E<lt>grommit@users.sourceforge.netE<gt> - Bulk of code from
Sybase producer, I just tweaked it for SQLServer. Thanks.

=cut
