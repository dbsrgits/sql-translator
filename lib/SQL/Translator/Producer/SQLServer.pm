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
use SQL::Translator::ProducerUtils;

my $util = SQL::Translator::ProducerUtils->new( quote_chars => ['[', ']'] );

my %translate  = (
    date       => 'datetime',
    'time'     => 'datetime',
    enum       => 'varchar',
    bytea      => 'varbinary',
    blob       => 'varbinary',
    clob       => 'varbinary',
    tinyblob   => 'varbinary',
    mediumblob => 'varbinary',
    longblob   => 'varbinary'
);

# If these datatypes have size appended the sql fails.
my @no_size = qw/tinyint smallint int integer bigint text bit image datetime/;

my $max_id_length    = 128;
my %global_names;

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
    my $options= {
        add_drop_table    => $add_drop_table,
        show_warnings     => $WARN,
        no_comments       => $no_comments,
    };

    %global_names = (); #reset

    my $output;
    $output .= header_comment."\n" unless ($no_comments);

    # Generate the DROP statements.
    if ($add_drop_table) {
        my @tables = sort { $b->order <=> $a->order } $schema->get_tables;
        $output .= "--\n-- Turn off constraints\n--\n\n" unless $no_comments;
        foreach my $table (@tables) {
            my $name = $table->name;
            my $q_name = $util->quote( $name );
            $output .= "IF EXISTS (SELECT name FROM sysobjects WHERE name = '$name' AND type = 'U') ALTER TABLE $q_name NOCHECK CONSTRAINT all;\n"
        }
        $output .= "\n";
        $output .= "--\n-- Drop tables\n--\n\n" unless $no_comments;
        foreach my $table (@tables) {
            my $name = $table->name;
            my $q_name = $util->quote( $name );
            $output .= "IF EXISTS (SELECT name FROM sysobjects WHERE name = '$name' AND type = 'U') DROP TABLE $q_name;\n"
        }
    }

    # Generate the CREATE sql

    my @foreign_constraints = (); # these need to be added separately, as tables may not exist yet

    for my $table ( $schema->get_tables ) {
        my $table_name   = $table->name or next;
        my $table_name_q = $util->quote( $table_name );

        my ( @comments, @field_defs, @index_defs, @constraint_defs );

        push @comments, "\n\n--\n-- Table: $table_name_q\n--"
        unless $no_comments;

        push @comments, map { "-- $_" } $table->comments;

        #
        # Fields
        #
        for my $field ( $table->get_fields ) {
            my $field_clause= build_field_clause($field, $options);
            if (lc($field->data_type) eq 'enum') {
                push @constraint_defs, build_enum_constraint($field, $options);
            }
            push @field_defs, $field_clause;
        }

        #
        # Constraint Declarations
        #
        my @constraint_defs = ();
        for my $constraint ( $table->get_constraints ) {
            next unless $constraint->fields;
            my ($stmt, $createClause)= build_constraint_stmt($constraint, $options);
            # use a clause, if the constraint can be written that way
            if ($createClause) {
                push @constraint_defs, $createClause;
            }
            # created a foreign key statement, which we save til the end
            elsif ( $constraint->type eq FOREIGN_KEY ) {
                push @foreign_constraints, $stmt;
            }
            # created an index statement, instead of a clause, which we append to "create table"
            else { #if ( $constraint->type eq UNIQUE ) {
                push @index_defs, $stmt;
            }
        }

        #
        # Indices
        #
        for my $index ( $table->get_indices ) {
            my $idx_name = $index->name || unique_name($table_name . '_idx');
            my $idx_name_q = $util->quote($idx_name);
            push @index_defs,
                "CREATE INDEX $idx_name_q ON $table_name_q (".
                join( ', ', map { $util->quote($_) } $index->fields ) . ");";
        }

        my $create_statement = "";
        $create_statement .= "CREATE TABLE $table_name_q (\n".
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

sub alter_field {
    my ($from_field, $to_field, $options) = @_;

    my $field_clause= build_field_clause($to_field, $options);
    my $table_name_q= $util->quote($to_field->table->name);
    
    my @sql;
    if (lc($from_field->data_type) eq 'enum') {
        push @sql, build_drop_enum_constraint($from_field, $options).';';
    }

    push @sql, "ALTER TABLE $table_name_q ALTER COLUMN $field_clause;";

    if ($from_field->name ne $to_field->name) {
        push @sql, rename_field(@_);
    }
    
    if (lc($to_field->data_type) eq 'enum') {
        push @sql, build_add_enum_constraint($to_field, $options).';';
    }
    
    return join("\n", @sql);
}

sub build_rename_field {
    my ($from_field, $to_field, $options) = @_;
 
    return sprintf "EXEC sp_rename \@objname = '%s', \@newname = '%s', \@objtype = 'COLUMN';",
           $from_field->name,
           $to_field->name;
}

sub add_field {
    my ($new_field, $options) = @_;
    
    my $field_clause= build_field_clause(@_);
    my $table_name_q= $util->quote($new_field->table->name);

    my @sql= "ALTER TABLE $table_name_q ADD COLUMN $field_clause;";
    if (lc($new_field->data_type) eq 'enum') {
        push @sql, build_add_enum_constraint($new_field, $options).';';
    }

    return join("\n", @sql);
}

sub drop_field { 
    my ($old_field, $options) = @_;

    my $table_name_q= $util->quote($old_field->table->name);
    my $field_name_q= $util->quote($old_field->name);
    
    my @sql;
    if (lc($old_field->data_type) eq 'enum') {
        push @sql, build_drop_enum_constraint($old_field, $options).';';
    }

    push @sql, "ALTER TABLE $table_name_q DROP COLUMN $field_name_q;";

    return join("\n", @sql);
}

sub alter_create_constraint {
    my ($constraint, $options) = @_;
    my ($stmt, $clause)= build_constraint_stmt(@_);
    return $stmt.';';
}

sub alter_drop_constraint {
    my ($constraint, $options) = @_;
    my $table_name_q= $util->quote($constraint->table->name);
    my $ct_name_q= $util->quote($constraint->name);
    return "ALTER TABLE $table_name_q DROP CONSTRAINT $ct_name_q;";
}

sub alter_create_index {
    my ($index, $options) = @_;
    my ($stmt, $clause)= build_index_stmt(@_);
    return $stmt.';';
}

sub alter_drop_index {
    my ($index, $options) = @_;
    my $table_name_q= $util->quote($index->table->name);
    my $index_name_q= $util->quote($index->name);
    return "ALTER TABLE $table_name_q DROP $index_name_q";
}

sub build_field_clause {
    my ($field, $options)= @_;
    
    my $field_name   = $field->name;
    my $field_name_q = $util->quote($field_name);
    my $field_def    = $field_name_q;

    #
    # Datatype
    #
    my $data_type      = lc $field->data_type;
    my $orig_data_type = $data_type;
    my %extra          = $field->extra;
    my $list           = $extra{'list'} || [];
    # \todo deal with embedded quotes
    my $commalist      = join( ', ', map { qq['$_'] } @$list );
    my $size           = $field->size;

    if ( $data_type eq 'set' ) {
        # TODO: do we need more logic here?
        $data_type = 'varchar';
    }
    elsif ( defined $translate{ $data_type } ) {
        $data_type = $translate{ $data_type };
    }
    else {
        warn "Unknown datatype: $data_type ",
            "(".$field->table->name.".$field_name)\n" if $WARN;
    }

    if ( grep $_ eq $data_type, @no_size) {
    # SQLServer doesn't seem to like sizes on some datatypes
        $size = undef;
    }
    elsif ( $data_type eq 'varbinary' ) {
        $size ||= 255 if $orig_data_type eq 'tinyblob';
        # SQL Server has a max specifyable size of 8000, but if you say 'max', you get 2^31.  Go figure.
        # Note that 'max' was introduced in SQL Server 2005.  Before that, you need a type of 'image',
        #   which is now deprecated.
        # TODO: add version support and return 'image' for old versions
        $size= 'max' if $size > 8000 || !$size;
    }
    elsif ( !$size ) {
        if ( $data_type =~ /numeric/ ) {
            $size = '9,0';
        }
        elsif ( $orig_data_type eq 'text' ) {
            #interpret text fields as long varchars
            $size = 255;
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
    
    return $field_def;
}

sub build_enum_constraint {
    my ($field, $options)= @_;
    my %extra = $field->extra;
    my $list = $extra{'list'} || [];
    # \todo deal with embedded quotes
    my $commalist = join( ', ', map { qq['$_'] } @$list );
    my $field_name_q = $util->quote($field->name);
    my $check_name_q = $util->quote( unique_name( $field->table->name . '_' . $field->name . '_chk' ) );
    return "CONSTRAINT $check_name_q CHECK ($field_name_q IN ($commalist))";
}

sub build_add_enum_constraint {
    my ($field, $options)= @_;
    my $table_name_q = $util->quote($field->table->name);
    return "ALTER TABLE $table_name_q ADD ".build_enum_constraint(@_);
}

sub build_drop_enum_constraint {
    my ($field, $options)= @_;
    my $table_name_q = $util->quote($field->table->name);
    my $check_name_q = $util->quote( unique_name( $field->table->name . '_' . $field->name . '_chk' ) );
    return "ALTER TABLE $table_name_q DROP $check_name_q";
}

# build_constraint_stmt($constraint, $options)
# Returns ($stmt, $clause)
#
# Multiple return values are necessary because some things that you would
#   like to be clauses in CREATE TABLE become separate statements.
# $stmt will always be returned, but $clause might be undef
#
sub build_constraint_stmt {
    my ($constraint, $options)= @_;
    my $table_name_q = $util->quote($constraint->table->name);
    my $field_list   = join(', ', map { $util->quote($_) } $constraint->fields );
    my $type         = $constraint->type || NORMAL;

    if ( $type eq FOREIGN_KEY ) {
        my $ct_name= $constraint->name || unique_name( $constraint->table->name . '_fk' );
        my $ct_name_q=    $util->quote($ct_name);
        my $ref_tbl_q=    $util->quote($constraint->reference_table);
        my $rfield_list=  join( ', ', map { $util->quote($_) } $constraint->reference_fields );

        my $c_def =
            "ALTER TABLE $table_name_q ADD CONSTRAINT $ct_name_q ".
            "FOREIGN KEY ($field_list) REFERENCES $ref_tbl_q ($rfield_list)";

        # The default implicit constraint action in MSSQL is RESTRICT
        # but you can not specify it explicitly. Go figure :)
        my $on_delete = uc ($constraint->on_delete || '');
        my $on_update = uc ($constraint->on_update || '');
        if ( $on_delete && $on_delete ne "NO ACTION" && $on_delete ne "RESTRICT") {
            $c_def .= " ON DELETE $on_delete";
        }
        if ( $on_update && $on_update ne "NO ACTION" && $on_delete ne "RESTRICT") {
            $c_def .= " ON UPDATE $on_update";
        }

        return $c_def, undef;
    }
    elsif ( $type eq PRIMARY_KEY ) {
        my $ct_name=      $constraint->name || unique_name( $constraint->table->name . '_pk' );
        my $ct_name_q=    $util->quote($ct_name);

        my $clause= "CONSTRAINT $ct_name_q PRIMARY KEY ($field_list)";
        my $stmt=   "ALTER TABLE $table_name_q ADD $clause";
        return $stmt, $clause;
    }
    elsif ( $type eq UNIQUE ) {
        my $ct_name=      $constraint->name || unique_name( $constraint->table->name . '_uc' );
        my $ct_name_q=    $util->quote($ct_name);

        my @nullable = grep { $_->is_nullable } $constraint->fields;
        if (!@nullable) {
            my $clause= "CONSTRAINT $ct_name_q UNIQUE ($field_list)";
            my $stmt=   "ALTER TABLE $table_name_q ADD $clause";
            return $stmt, $clause;
        }
        else {
            my $where_clause= join(' AND ', map { $util->quote($_->name) . ' IS NOT NULL' } @nullable );
            my $stmt= "CREATE UNIQUE NONCLUSTERED INDEX $ct_name_q" .
                      " ON $table_name_q ($field_list)" .
                      " WHERE $where_clause";
            return $stmt, undef;
        }
    }
    
    die "Unhandled constraint type $type";
}

sub build_index_stmt {
    my ($index, $options)= @_;
    my $table_name_q = $util->quote($index->table->name);
    my $idx_name_q   = $util->quote($index->name);
    my $field_list   = join(', ', map { $util->quote($_) } $index->fields );

    my $stmt= "CREATE UNIQUE NONCLUSTERED INDEX $idx_name_q" .
              " ON $table_name_q ($field_list)";
    return $stmt, undef;
}

# -------------------------------------------------------------------
sub unique_name {
    my ($name, $scope, $critical) = @_;

    $scope ||= \%global_names;
    if ( my $prev = $scope->{ $name } ) {
        my $name_orig = $name;
        $name        .= sprintf( "%02d", ++$prev );
        substr($name, $max_id_length - 3) = "00"
            if length( $name ) > $max_id_length;

        warn "The name '$name_orig' has been changed to '$name' to make it".
             "unique.\nThis can wreak havoc if you try generating upgrade or".
             "downgrade scripts.\n" if $WARN;

        $scope->{ $name_orig }++;
    }
    $name = substr( $name, 0, $max_id_length )
                        if ((length( $name ) > $max_id_length) && $critical);
    $scope->{ $name }++;
    return $name;
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
