package SQL::Translator::Producer::Sybase;

# -------------------------------------------------------------------
# $Id: Sybase.pm,v 1.1 2003-05-12 14:29:51 angiuoli Exp $
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

SQL::Translator::Producer::Sybase - Sybase producer for SQL::Translator

=cut

use strict;
use vars qw[ $DEBUG $WARN $VERSION ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;
$DEBUG = 1 unless defined $DEBUG;

use Data::Dumper;

my %translate  = (
    #
    # Sybase types
    #
    integer        => 'numeric',
    money      => 'money',
    varchar    => 'varchar',
    timestamp   => 'datetime',
    text       => 'varchar',
    real       => 'double precision',
    comment    => 'text',
    bit        => 'bit',
    tinyint    => 'smallint',
    float      => 'double precision',
    serial     => 'numeric', 
    boolean    => 'varchar',
    char  => 'char'
		  
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

=head1 Sybase Create Table Syntax

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

    for my $table ( 
        map  { $_->[1] }
        sort { $a->[0] <=> $b->[0] }
        map  { [ $_->{'order'}, $_ ] }
        values %$data
   ) {
        my $table_name    = $table->{'table_name'};
        $table_name       = mk_name( $table_name, '', undef, 1 );
        my $table_name_ur = unreserve($table_name);

        my ( @comments, @field_decs, @sequence_decs, @constraints );

        push @comments, "--\n-- Table: $table_name_ur\n--" unless $no_comments;

        #
        # Fields
        #
        my %field_name_scope;
        for my $field ( 
            map  { $_->[1] }
            sort { $a->[0] <=> $b->[0] }
            map  { [ $_->{'order'}, $_ ] }
            values %{ $table->{'fields'} }
        ) {
            my $field_name    = mk_name(
                $field->{'name'}, '', \%field_name_scope, undef,1 
            );
            my $field_name_ur = unreserve( $field_name, $table_name );
            my $field_str     = qq["$field_name_ur"];
	    $field_str =~ s/\"//g;
	    if ($field_str =~ /identity/){
		$field_str =~ s/identity/pidentity/;
	    }

            #
            # Datatype
            #
            my $data_type = lc $field->{'data_type'};
	    my $orig_data_type = $data_type;
            my $list      = $field->{'list'} || [];
            my $commalist = join ",", @$list;
            my $seq_name;

            if ( $data_type eq 'enum' ) {
                my $len = 0;
                $len = ($len < length($_)) ? length($_) : $len for (@$list);
                my $check_name = mk_name( $table_name.'_'.$field_name, 'chk' ,undef,1);
                push @constraints, 
                "CONSTRAINT $check_name CHECK ($field_name IN ($commalist))";
                $field_str .= " character varying($len)";
            }
            elsif ( $data_type eq 'set' ) {
                # XXX add a CHECK constraint maybe 
                # (trickier and slower, than enum :)
                my $len     = length $commalist;
                $field_str .= " character varying($len) /* set $commalist */";
            }
            elsif ( $field->{'is_auto_inc'} ) {
                $field_str .= ' IDENTITY';
            }
            else {
                $data_type  = defined $translate{ $data_type } ?
                              $translate{ $data_type } :
                              die "Unknown datatype: $data_type\n";
                $field_str .= ' '.$data_type;
                if ( $data_type =~ /(char|varbit|decimal)/i ) {
                    $field_str .= '('.join(',', @{ $field->{'size'} }).')' 
                        if @{ $field->{'size'} || [] };
                }
		elsif( $data_type =~ /numeric/){
		    $field_str .= '(9,0)';
		}
		if( $orig_data_type eq 'text'){
		    #interpret text fields as long varchars
		    $field_str .= '(255)';
		}
		elsif($data_type eq "varchar" && $orig_data_type eq "boolean"){
		    $field_str .= '(6)';
		}
		elsif($data_type eq "varchar" && (!$field->{'size'})){
		    $field_str .= '(255)';
		}
            }


            #
            # Default value
            #
            if ( defined $field->{'default'} ) {
                $field_str .= sprintf( ' DEFAULT %s',
                    ( $field->{'is_auto_inc'} && $seq_name )
                    ? qq[nextval('"$seq_name"'::text)] :
                    ( $field->{'default'} =~ m/null/i )
                    ? 'NULL' : 
                    "'".$field->{'default'}."'"
                );
            }

            #
            # Not null constraint
            #
            unless ( $field->{'null'} ) {
                my $constraint_name = mk_name($field_name_ur, 'nn',undef,1);
#                $field_str .= ' CONSTRAINT '.$constraint_name.' NOT NULL';
                $field_str .= ' NOT NULL';
            }
	    else {
		$field_str .= ' NULL' if($data_type ne "bit");
	    }

            push @field_decs, $field_str;
        }

        #
        # Constraint Declarations
        #
        my @constraint_decs = ();
        my $idx_name_default;
        for my $constraint ( @{ $table->{'constraints'} } ) {
            my $constraint_name = $constraint->{'name'} || '';
            my $constraint_type = $constraint->{'type'} || 'normal';
            my @fields     = map { unreserve( $_, $table_name ) }
                             @{ $constraint->{'fields'} };
            next unless @fields;

            if ( $constraint_type eq 'primary_key' ) {
                $constraint_name = mk_name( $table_name, 'pk',undef,1 );
                push @constraints, 'CONSTRAINT '.$constraint_name.' PRIMARY KEY '.
                    '(' . join( ', ', @fields ) . ')';
            }
            if ( $constraint_type eq 'foreign_key' ) {
                $constraint_name = mk_name( $table_name, 'fk',undef,1 );
                push @constraints, 'CONSTRAINT '.$constraint_name.' FOREIGN KEY '.
                    '(' . join( ', ', @fields ) . ') '.
		    "REFERENCES $constraint->{'reference_table'}($constraint->{'reference_fields'}[0])";
            }
            elsif ( $constraint_type eq 'unique' ) {
                $constraint_name = mk_name( 
                    $table_name, $constraint_name || ++$idx_name_default,undef, 1
                );
                push @constraints, 'CONSTRAINT ' . $constraint_name . ' UNIQUE ' .
                    '(' . join( ', ', @fields ) . ')';
            }
            elsif ( $constraint_type eq 'normal' ) {
                $constraint_name = mk_name( 
                    $table_name, $constraint_name || ++$idx_name_default, undef, 1
                );
                push @constraint_decs, 
                    qq[CREATE CONSTRAINT "$constraint_name" on $table_name_ur (].
                        join( ', ', @fields ).  
                    ');'; 
            }
            else {
                warn "Unknown constraint type ($constraint_type) on table $table_name.\n"
                    if $WARN;
            }
        }

        my $create_statement;
        $create_statement  = qq[DROP TABLE $table_name_ur;\n] 
            if $add_drop_table;
        $create_statement .= qq[CREATE TABLE $table_name_ur (\n].
            join( ",\n", map { "  $_" } @field_decs, @constraints ).
            "\n);"
        ;

        $output .= join( "\n\n", 
            @comments,
            @sequence_decs, 
            $create_statement, 
            @constraint_decs, 
            '' 
        );
			    }
#
	    # Index Declarations
	    #
	    for my $table ( 
			    map  { $_->[1] }
			    sort { $a->[0] <=> $b->[0] }
			    map  { [ $_->{'order'}, $_ ] }
			    values %$data
			    ) {
		my $table_name    = $table->{'table_name'};
		$table_name       = mk_name( $table_name, '', undef, 1 );
		my $table_name_ur = unreserve($table_name);
		
		my @index_decs = ();
		for my $index ( @{ $table->{'indices'} } ) {
		    my $unique = ($index->{'name'} eq 'unique') ? 'unique' : '';
		    $output .= "CREATE $unique INDEX $index->{'name'} ON $table->{'table_name'} (".join(',',@{$index->{'fields'}}).");\n";
		}
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
    $name = substr( $name, 0, $max_id_length ) 
                        if ((length( $name ) > $max_id_length) && $critical);
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
