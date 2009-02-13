package SQL::Translator::Producer::PostgreSQL;

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

SQL::Translator::Producer::PostgreSQL - PostgreSQL producer for SQL::Translator

=head1 SYNOPSIS

  my $t = SQL::Translator->new( parser => '...', producer => 'PostgreSQL' );
  $t->translate;

=head1 DESCRIPTION

Creates a DDL suitable for PostgreSQL.  Very heavily based on the Oracle
producer.

=cut

use strict;
use warnings;
use vars qw[ $DEBUG $WARN $VERSION %used_names ];
$VERSION = '1.59';
$DEBUG = 0 unless defined $DEBUG;

use base qw(SQL::Translator::Producer);
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(debug header_comment);
use Data::Dumper;

my %translate;
my $max_id_length;

BEGIN {

 %translate  = (
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
    time       => 'time',
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

 $max_id_length = 62;
}
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

# my $max_id_length    = 62;
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
    local $DEBUG             = $translator->debug;
    local $WARN              = $translator->show_warnings;
    my $no_comments    = $translator->no_comments;
    my $add_drop_table = $translator->add_drop_table;
    my $schema         = $translator->schema;
    my $pargs          = $translator->producer_args;
    local %used_names  = ();

    my $postgres_version = $pargs->{postgres_version} || 0;

    my $qt = '';
    $qt = '"' if ($translator->quote_table_names);
    my $qf = '';
    $qf = '"' if ($translator->quote_field_names);
    
    my $output;
    $output .= header_comment unless ($no_comments);

    my (@table_defs, @fks);
    for my $table ( $schema->get_tables ) {

        my ($table_def, $fks) = create_table($table, 
                                             { quote_table_names => $qt,
                                               quote_field_names => $qf,
                                               no_comments => $no_comments,
                                               postgres_version => $postgres_version,
                                               add_drop_table => $add_drop_table,});
        push @table_defs, $table_def;
        push @fks, @$fks;

    }

    for my $view ( $schema->get_views ) {
      push @table_defs, create_view($view, {
        add_drop_view     => $add_drop_table,
        quote_table_names => $qt,
        quote_field_names => $qf,
        no_comments       => $no_comments,
      });
    }

    $output  = join(";\n\n", @table_defs) . ";\n\n";
    if ( @fks ) {
        $output .= "--\n-- Foreign Key Definitions\n--\n\n" unless $no_comments;
        $output .= join( ";\n\n", @fks ) . ";\n";
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
#    my $max_id_length = 62;
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
    return $name if (!$reserved{ uc $name }) && $name =~ /^[a-z]/i; 

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
    my $name = shift || '';
    if ( !defined( $used_names{$name} ) ) {
        $used_names{$name} = $name;
        return $name;
    }

    my $i = 2;
    while ( defined( $used_names{ $name . $i } ) ) {
        ++$i;
    }
    $name .= $i;
    $used_names{$name} = $name;
    return $name;
}


sub create_table 
{
    my ($table, $options) = @_;

    my $qt = $options->{quote_table_names} || '';
    my $qf = $options->{quote_field_names} || '';
    my $no_comments = $options->{no_comments} || 0;
    my $add_drop_table = $options->{add_drop_table} || 0;
    my $postgres_version = $options->{postgres_version} || 0;

    my $table_name = $table->name or next;
    $table_name    = mk_name( $table_name, '', undef, 1 );
    my ( $fql_tbl_name ) = ( $table_name =~ s/\W(.*)$// ) ? $1 : q{};
    my $table_name_ur = $qt ? $table_name
        : $fql_tbl_name ? join('.', $table_name, unreserve($fql_tbl_name))
        : unreserve($table_name);
    $table->name($table_name_ur);

# print STDERR "$table_name table_name\n";
    my ( @comments, @field_defs, @sequence_defs, @constraint_defs, @type_defs, @type_drops, @fks );

    push @comments, "--\n-- Table: $table_name_ur\n--\n" unless $no_comments;

    if ( $table->comments and !$no_comments ){
        my $c = "-- Comments: \n-- ";
        $c .= join "\n-- ",  $table->comments;
        $c .= "\n--\n";
        push @comments, $c;
    }

    #
    # Fields
    #
    my %field_name_scope;
    for my $field ( $table->get_fields ) {
        push @field_defs, create_field($field, { quote_table_names => $qt,
                                                 quote_field_names => $qf,
                                                 table_name => $table_name_ur,
                                                 postgres_version => $postgres_version,
                                                 type_defs => \@type_defs,
                                                 type_drops => \@type_drops,
                                                 constraint_defs => \@constraint_defs,});
    }

    #
    # Index Declarations
    #
    my @index_defs = ();
 #   my $idx_name_default;
    for my $index ( $table->get_indices ) {
        my ($idef, $constraints) = create_index($index,
                                              { 
                                                  quote_field_names => $qf,
                                                  quote_table_names => $qt,
                                                  table_name => $table_name,
                                              });
        $idef and push @index_defs, $idef;
        push @constraint_defs, @$constraints;
    }

    #
    # Table constraints
    #
    my $c_name_default;
    for my $c ( $table->get_constraints ) {
        my ($cdefs, $fks) = create_constraint($c, 
                                              { 
                                                  quote_field_names => $qf,
                                                  quote_table_names => $qt,
                                                  table_name => $table_name,
                                              });
        push @constraint_defs, @$cdefs;
        push @fks, @$fks;
    }


    my $temporary = "";

    if(exists $table->{extra}{temporary}) {
        $temporary = $table->{extra}{temporary} ? "TEMPORARY " : "";
    } 

    my $create_statement;
    $create_statement = join("\n", @comments);
    if ($add_drop_table) {
        if ($postgres_version >= 8.2) {
            $create_statement .= qq[DROP TABLE IF EXISTS $qt$table_name_ur$qt CASCADE;\n];
            $create_statement .= join ("\n", @type_drops) . "\n"
                if $postgres_version >= 8.3;
        } else {
            $create_statement .= qq[DROP TABLE $qt$table_name_ur$qt CASCADE;\n];
        }
    }
    $create_statement .= join("\n", @type_defs) . "\n"
        if $postgres_version >= 8.3;
    $create_statement .= qq[CREATE ${temporary}TABLE $qt$table_name_ur$qt (\n].
                            join( ",\n", map { "  $_" } @field_defs, @constraint_defs ).
                            "\n)"
                            ;
    $create_statement .= @index_defs ? ';' : q{};
    $create_statement .= ( $create_statement =~ /;$/ ? "\n" : q{} )
        . join(";\n", @index_defs);

    return $create_statement, \@fks;
}

sub create_view {
    my ($view, $options) = @_;
    my $qt = $options->{quote_table_names} || '';
    my $qf = $options->{quote_field_names} || '';
    my $add_drop_view = $options->{add_drop_view};

    my $view_name = $view->name;
    debug("PKG: Looking at view '${view_name}'\n");

    my $create = '';
    $create .= "--\n-- View: ${qt}${view_name}${qt}\n--\n"
        unless $options->{no_comments};
    $create .= "DROP VIEW ${qt}${view_name}${qt};\n" if $add_drop_view;
    $create .= 'CREATE';

    my $extra = $view->extra;
    $create .= " TEMPORARY" if exists($extra->{temporary}) && $extra->{temporary};
    $create .= " VIEW ${qt}${view_name}${qt}";

    if ( my @fields = $view->fields ) {
        my $field_list = join ', ', map { "${qf}${_}${qf}" } @fields;
        $create .= " ( ${field_list} )";
    }

    if ( my $sql = $view->sql ) {
        $create .= " AS (\n    ${sql}\n  )";
    }

    if ( $extra->{check_option} ) {
        $create .= ' WITH ' . uc $extra->{check_option} . ' CHECK OPTION';
    }

    return $create;
}

{ 

    my %field_name_scope;

    sub create_field
    {
        my ($field, $options) = @_;

        my $qt = $options->{quote_table_names} || '';
        my $qf = $options->{quote_field_names} || '';
        my $table_name = $field->table->name;
        my $constraint_defs = $options->{constraint_defs} || [];
        my $postgres_version = $options->{postgres_version} || 0;
        my $type_defs = $options->{type_defs} || [];
        my $type_drops = $options->{type_drops} || [];

        $field_name_scope{$table_name} ||= {};
        my $field_name    = mk_name(
                                    $field->name, '', $field_name_scope{$table_name}, 1 
                                    );
        my $field_name_ur = $qf ? $field_name : unreserve($field_name, $table_name );
        $field->name($field_name_ur);
        my $field_comments = $field->comments 
            ? "-- " . $field->comments . "\n  " 
            : '';

        my $field_def     = $field_comments.qq[$qf$field_name_ur$qf];

        #
        # Datatype
        #
        my @size      = $field->size;
        my $data_type = lc $field->data_type;
        my %extra     = $field->extra;
        my $list      = $extra{'list'} || [];
        # todo deal with embedded quotes
        my $commalist = join( ', ', map { qq['$_'] } @$list );

        if ($postgres_version >= 8.3 && $field->data_type eq 'enum') {
            my $type_name = $field->table->name . '_' . $field->name . '_type';
            $field_def .= ' '. $type_name;
            push @$type_defs, "CREATE TYPE $type_name AS ENUM ($commalist)";
            push @$type_drops, "DROP TYPE IF EXISTS $type_name";
        } else {
            $field_def .= ' '. convert_datatype($field);
        }

        #
        # Default value 
        #
        my $default = $field->default_value;
        if ( defined $default ) {
            SQL::Translator::Producer->_apply_default_value(
              \$field_def,
              $default,
              [
                'NULL'              => \'NULL',
                'now()'             => 'now()',
                'CURRENT_TIMESTAMP' => 'CURRENT_TIMESTAMP',
              ],
            );
        }

        #
        # Not null constraint
        #
        $field_def .= ' NOT NULL' unless $field->is_nullable;

        return $field_def;
    }
}

    sub create_index
    {
        my ($index, $options) = @_;

        my $qt = $options->{quote_table_names} ||'';
        my $qf = $options->{quote_field_names} ||'';
        my $table_name = $index->table->name;
#        my $table_name_ur = $qt ? unreserve($table_name) : $table_name;

        my ($index_def, @constraint_defs);

        my $name = $index->name || '';
        if ( $name ) {
            $name = next_unused_name($name);
        }

        my $type = $index->type || NORMAL;
        my @fields     = 
            map { $_ =~ s/\(.+\)//; $_ }
        map { $qt ? $_ : unreserve($_, $table_name ) }
        $index->fields;
        next unless @fields;

        my $def_start = qq[CONSTRAINT "$name" ];
        if ( $type eq PRIMARY_KEY ) {
            push @constraint_defs, "${def_start}PRIMARY KEY ".
                '(' .$qf . join( $qf. ', '.$qf, @fields ) . $qf . ')';
        }
        elsif ( $type eq UNIQUE ) {
            push @constraint_defs, "${def_start}UNIQUE " .
                '(' . $qf . join( $qf. ', '.$qf, @fields ) . $qf.')';
        }
        elsif ( $type eq NORMAL ) {
            $index_def = 
                "CREATE INDEX ${qf}${name}${qf} on ${qt}${table_name}${qt} (".
                join( ', ', map { qq[$qf$_$qf] } @fields ).  
                ')'
                ; 
        }
        else {
            warn "Unknown index type ($type) on table $table_name.\n"
                if $WARN;
        }

        return $index_def, \@constraint_defs;
    }

    sub create_constraint
    {
        my ($c, $options) = @_;

        my $qf = $options->{quote_field_names} ||'';
        my $qt = $options->{quote_table_names} ||'';
        my $table_name = $c->table->name;
        my (@constraint_defs, @fks);

        my $name = $c->name || '';
        if ( $name ) {
            $name = next_unused_name($name);
        }

        my @fields     = 
            map { $_ =~ s/\(.+\)//; $_ }
        map { $qt ? $_ : unreserve( $_, $table_name )}
        $c->fields;

        my @rfields     = 
            map { $_ =~ s/\(.+\)//; $_ }
        map { $qt ? $_ : unreserve( $_, $table_name )}
        $c->reference_fields;

        next if !@fields && $c->type ne CHECK_C;
        my $def_start = $name ? qq[CONSTRAINT "$name" ] : '';
        if ( $c->type eq PRIMARY_KEY ) {
            push @constraint_defs, "${def_start}PRIMARY KEY ".
                '('.$qf . join( $qf.', '.$qf, @fields ) . $qf.')';
        }
        elsif ( $c->type eq UNIQUE ) {
            $name = next_unused_name($name);
            push @constraint_defs, "${def_start}UNIQUE " .
                '('.$qf . join( $qf.', '.$qf, @fields ) . $qf.')';
        }
        elsif ( $c->type eq CHECK_C ) {
            my $expression = $c->expression;
            push @constraint_defs, "${def_start}CHECK ($expression)";
        }
        elsif ( $c->type eq FOREIGN_KEY ) {
            my $def .= "ALTER TABLE ${qt}${table_name}${qt} ADD FOREIGN KEY (" . 
                join( ', ', map { qq[$qf$_$qf] } @fields ) . ')' .
                "\n  REFERENCES " . $qt . $c->reference_table . $qt;

            if ( @rfields ) {
                $def .= ' ('.$qf . join( $qf.', '.$qf, @rfields ) . $qf.')';
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

            if ( $c->deferrable ) {
                $def .= ' DEFERRABLE';
            }

            push @fks, "$def";
        }

        return \@constraint_defs, \@fks;
    }

sub convert_datatype
{
    my ($field) = @_;

    my @size      = $field->size;
    my $data_type = lc $field->data_type;

    if ( $data_type eq 'enum' ) {
#        my $len = 0;
#        $len = ($len < length($_)) ? length($_) : $len for (@$list);
#        my $chk_name = mk_name( $table_name.'_'.$field_name, 'chk' );
#        push @$constraint_defs, 
#        qq[CONSTRAINT "$chk_name" CHECK ($qf$field_name$qf ].
#           qq[IN ($commalist))];
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
        if ( defined $size[0] && $size[0] > 0) {
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
    my @type_without_size = qw/bigint boolean box bytea cidr circle date inet
                               integer smallint text line lseg macaddr money
                               path point polygon real/;
    foreach (@type_without_size) {
        if ( $data_type =~ qr/$_/ ) {
            undef @size; last;
        }
    }

    if ( defined $size[0] && $size[0] > 0 ) {
        $data_type .= '(' . join( ',', @size ) . ')';
    }
    elsif (defined $size[0] && $data_type eq 'timestamp' ) {
        $data_type .= '(' . join( ',', @size ) . ')';
    }


    return $data_type;
}


sub alter_field
{
    my ($from_field, $to_field) = @_;

    die "Can't alter field in another table" 
        if($from_field->table->name ne $to_field->table->name);

    my @out;
    push @out, sprintf('ALTER TABLE %s ALTER COLUMN %s SET NOT NULL',
                       $to_field->table->name,
                       $to_field->name) if(!$to_field->is_nullable and
                                           $from_field->is_nullable);

    my $from_dt = convert_datatype($from_field);
    my $to_dt   = convert_datatype($to_field);
    push @out, sprintf('ALTER TABLE %s ALTER COLUMN %s TYPE %s',
                       $to_field->table->name,
                       $to_field->name,
                       $to_dt) if($to_dt ne $from_dt);

    push @out, sprintf('ALTER TABLE %s RENAME COLUMN %s TO %s',
                       $to_field->table->name,
                       $from_field->name,
                       $to_field->name) if($from_field->name ne $to_field->name);

    my $old_default = $from_field->default_value;
    my $new_default = $to_field->default_value;
    push @out, sprintf('ALTER TABLE %s ALTER COLUMN %s SET DEFAULT %s',
                       $to_field->table->name,
                       $to_field->name,
                       $to_field->default_value)
        if ( defined $new_default &&
             (!defined $old_default || $old_default ne $new_default) );

    return wantarray ? @out : join("\n", @out);
}

sub rename_field { alter_field(@_) }

sub add_field
{
    my ($new_field) = @_;

    my $out = sprintf('ALTER TABLE %s ADD COLUMN %s',
                      $new_field->table->name,
                      create_field($new_field));
    return $out;

}

sub drop_field
{
    my ($old_field) = @_;

    my $out = sprintf('ALTER TABLE %s DROP COLUMN %s',
                      $old_field->table->name,
                      $old_field->name);

    return $out;    
}

sub alter_table {
    my ($to_table, $options) = @_;
    my $qt = $options->{quote_table_names} || '';
    my $out = sprintf('ALTER TABLE %s %s',
                      $qt . $to_table->name . $qt,
                      $options->{alter_table_action});
    return $out;
}

sub rename_table {
    my ($old_table, $new_table, $options) = @_;
    my $qt = $options->{quote_table_names} || '';
    $options->{alter_table_action} = "RENAME TO $qt$new_table$qt";
    return alter_table($old_table, $options);
}

sub alter_create_index {
    my ($index, $options) = @_;
    my $qt = $options->{quote_table_names} || '';
    my $qf = $options->{quote_field_names} || '';
    my ($idef, $constraints) = create_index($index, {
        quote_field_names => $qf,
        quote_table_names => $qt,
        table_name => $index->table->name,
    });
    return $index->type eq NORMAL ? $idef
        : sprintf('ALTER TABLE %s ADD %s',
              $qt . $index->table->name . $qt,
              join(q{}, @$constraints)
          );
}

sub alter_drop_index {
    my ($index, $options) = @_;
    my $index_name = $index->name;
    return "DROP INDEX $index_name";
}

sub alter_drop_constraint {
    my ($c, $options) = @_;
    my $qt = $options->{quote_table_names} || '';
    my $qc = $options->{quote_field_names} || '';
    my $out = sprintf('ALTER TABLE %s DROP CONSTRAINT %s',
                      $qt . $c->table->name . $qt,
                      $qc . $c->name . $qc );
    return $out;
}

sub alter_create_constraint {
    my ($index, $options) = @_;
    my $qt = $options->{quote_table_names} || '';
    return $index->type eq FOREIGN_KEY ? join(q{}, @{create_constraint(@_)})
        : join( ' ', 'ALTER TABLE', $qt.$index->table->name.$qt,
              'ADD', join(q{}, map { @{$_} } create_constraint(@_))
          );
}

sub drop_table {
    my ($table, $options) = @_;
    my $qt = $options->{quote_table_names} || '';
    return "DROP TABLE $qt$table$qt CASCADE";
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
