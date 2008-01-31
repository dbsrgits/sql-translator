package SQL::Translator::Producer::SQLite;

# -------------------------------------------------------------------
# $Id: SQLite.pm,v 1.15 2006-08-26 11:35:31 schiffbruechige Exp $
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

SQL::Translator::Producer::SQLite - SQLite producer for SQL::Translator

=head1 SYNOPSIS

  use SQL::Translator;

  my $t = SQL::Translator->new( parser => '...', producer => 'SQLite' );
  $t->translate;

=head1 DESCRIPTION

This module will produce text output of the schema suitable for SQLite.

=cut

use strict;
use Data::Dumper;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(debug header_comment);

use vars qw[ $VERSION $DEBUG $WARN ];

$VERSION = sprintf "%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/;
$DEBUG = 0 unless defined $DEBUG;
$WARN = 0 unless defined $WARN;

my %used_identifiers = ();
my $max_id_length    = 30;
my %global_names;
my %truncated;

sub produce {
    my $translator     = shift;
    local $DEBUG       = $translator->debug;
    local $WARN        = $translator->show_warnings;
    my $no_comments    = $translator->no_comments;
    my $add_drop_table = $translator->add_drop_table;
    my $schema         = $translator->schema;

    debug("PKG: Beginning production\n");

    my $create = '';
    $create .= header_comment unless ($no_comments);
    $create .= "BEGIN TRANSACTION;\n\n";

    my @table_defs = ();
    for my $table ( $schema->get_tables ) {
        my @defs = create_table($table, { no_comments => $no_comments,
                                          add_drop_table => $add_drop_table,});
        my $create = shift @defs;
        $create .= ";\n";
        push @table_defs, $create, map( { "$_;" } @defs), "";
    }

#    $create .= "COMMIT;\n";

    return wantarray ? ($create, @table_defs, "COMMIT;\n") : join("\n", ($create, @table_defs, "COMMIT;\n"));
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
    $basename         =~ s/\./_/g;
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

sub create_table
{
    my ($table, $options) = @_;

    my $table_name = $table->name;
    my $no_comments = $options->{no_comments};
    my $add_drop_table = $options->{add_drop_table};

    debug("PKG: Looking at table '$table_name'\n");

    my ( @index_defs, @constraint_defs, @trigger_defs );
    my @fields = $table->get_fields or die "No fields in $table_name";

    my $temp = $options->{temporary_table} ? 'TEMPORARY ' : '';
    #
    # Header.
    #
    my $create = '';
    $create .= "--\n-- Table: $table_name\n--\n" unless $no_comments;
    $create .= qq[DROP TABLE $table_name;\n] if $add_drop_table;
    $create .= "CREATE ${temp}TABLE $table_name (\n";

    #
    # Comments
    #
    if ( $table->comments and !$no_comments ){
        $create .= "-- Comments: \n-- ";
        $create .= join "\n-- ",  $table->comments;
        $create .= "\n--\n\n";
    }

    #
    # How many fields in PK?
    #
    my $pk        = $table->primary_key;
    my @pk_fields = $pk ? $pk->fields : ();

    #
    # Fields
    #
    my ( @field_defs, $pk_set );
    for my $field ( @fields ) {
        push @field_defs, create_field($field);
    }

    if ( 
         scalar @pk_fields > 1 
         || 
         ( @pk_fields && !grep /INTEGER PRIMARY KEY/, @field_defs ) 
         ) {
        push @field_defs, 'PRIMARY KEY (' . join(', ', @pk_fields ) . ')';
    }

    #
    # Indices
    #
    my $idx_name_default = 'A';
    for my $index ( $table->get_indices ) {
        push @index_defs, create_index($index);
    }

    #
    # Constraints
    #
    my $c_name_default = 'A';
    for my $c ( $table->get_constraints ) {
        next unless $c->type eq UNIQUE; 
        push @constraint_defs, create_constraint($c);
    }

    $create .= join(",\n", map { "  $_" } @field_defs ) . "\n)";

    return ($create, @index_defs, @constraint_defs, @trigger_defs );
}

sub create_field
{
    my ($field, $options) = @_;

    my $field_name = $field->name;
    debug("PKG: Looking at field '$field_name'\n");
    my $field_comments = $field->comments 
        ? "-- " . $field->comments . "\n  " 
        : '';

    my $field_def = $field_comments.$field_name;

    # data type and size
    my $size      = $field->size;
    my $data_type = $field->data_type;
    $data_type    = 'varchar' if lc $data_type eq 'set';
    $data_type  = 'blob' if lc $data_type eq 'bytea';

    if ( lc $data_type =~ /(text|blob)/i ) {
        $size = undef;
    }

#             if ( $data_type =~ /timestamp/i ) {
#                 push @trigger_defs, 
#                     "CREATE TRIGGER ts_${table_name} ".
#                     "after insert on $table_name\n".
#                     "begin\n".
#                     "  update $table_name set $field_name=timestamp() ".
#                        "where id=new.id;\n".
#                     "end;\n"
#                 ;
#
#            }

    #
    # SQLite is generally typeless, but newer versions will
    # make a field autoincrement if it is declared as (and
    # *only* as) INTEGER PRIMARY KEY
    #
    my $pk        = $field->table->primary_key;
    my @pk_fields = $pk ? $pk->fields : ();

    if ( 
         $field->is_primary_key && 
         scalar @pk_fields == 1 &&
         (
          $data_type =~ /int(eger)?$/i
          ||
          ( $data_type =~ /^number?$/i && $size !~ /,/ )
          )
         ) {
        $data_type = 'INTEGER PRIMARY KEY';
        $size      = undef;
#        $pk_set    = 1;
    }

    $field_def .= sprintf " %s%s", $data_type, 
    ( !$field->is_auto_increment && $size ) ? "($size)" : '';

    # Null?
    $field_def .= ' NOT NULL' unless $field->is_nullable;

    # Default?  XXX Need better quoting!
    my $default = $field->default_value;
    if ( defined $default ) {
        if ( uc $default eq 'NULL') {
            $field_def .= ' DEFAULT NULL';
        } elsif ( $default eq 'now()' ||
                  $default eq 'CURRENT_TIMESTAMP' ) {
            $field_def .= ' DEFAULT CURRENT_TIMESTAMP';
        } elsif ( $default =~ /val\(/ ) {
            next;
        } else {
            $field_def .= " DEFAULT '$default'";
        }
    }

    return $field_def;

}

sub create_index
{
    my ($index, $options) = @_;

    my $name   = $index->name;
    $name      = mk_name($index->table->name, $name);

    my $type   = $index->type eq 'UNIQUE' ? "UNIQUE " : ''; 

    # strip any field size qualifiers as SQLite doesn't like these
    my @fields = map { s/\(\d+\)$//; $_ } $index->fields;
    (my $index_table_name = $index->table->name) =~ s/^.+?\.//; # table name may not specify schema
    warn "removing schema name from '" . $index->table->name . "' to make '$index_table_name'\n" if $WARN;
    my $index_def =  
    "CREATE ${type}INDEX $name ON " . $index_table_name .
        ' (' . join( ', ', @fields ) . ')';

    return $index_def;
}

sub create_constraint
{
    my ($c, $options) = @_;

    my $name   = $c->name;
    $name      = mk_name($c->table->name, $name);
    my @fields = $c->fields;
    (my $index_table_name = $c->table->name) =~ s/^.+?\.//; # table name may not specify schema
    warn "removing schema name from '" . $c->table->name . "' to make '$index_table_name'\n" if $WARN;

    my $c_def =  
    "CREATE UNIQUE INDEX $name ON " . $index_table_name .
        ' (' . join( ', ', @fields ) . ')';

    return $c_def;
}

sub alter_table { } # Noop

sub add_field {
  my ($field) = @_;

  return sprintf("ALTER TABLE %s ADD COLUMN %s",
      $field->table->name, create_field($field))
}

sub alter_create_index {
  my ($index) = @_;

  # This might cause name collisions
  return create_index($index);
}

sub alter_create_constraint {
  my ($constraint) = @_;

  return create_constraint($constraint) if $constraint->type eq 'UNIQUE';
}

sub alter_drop_constraint { alter_drop_index(@_) }

sub alter_drop_index {
  my ($constraint) = @_;

  return sprintf("DROP INDEX %s ON %s",
      $constraint->name, $constraint->table->name);
}

sub batch_alter_table {
  my ($table, $diffs) = @_;

  # If we have any of the following
  #
  #  rename_field
  #  alter_field
  #  drop_field
  #
  # we need to do the following <http://www.sqlite.org/faq.html#q11>
  #
  # BEGIN TRANSACTION;
  # CREATE TEMPORARY TABLE t1_backup(a,b);
  # INSERT INTO t1_backup SELECT a,b FROM t1;
  # DROP TABLE t1;
  # CREATE TABLE t1(a,b);
  # INSERT INTO t1 SELECT a,b FROM t1_backup;
  # DROP TABLE t1_backup;
  # COMMIT;
  #
  # Fun, eh?
  #
  # If we have rename_field we do similarly.

  my $table_name = $table->name;
  my $renaming = $diffs->{rename_table} && @{$diffs->{rename_table}};

  if ( @{$diffs->{rename_field}} == 0 &&
       @{$diffs->{alter_field}}  == 0 &&
       @{$diffs->{drop_field}}   == 0
       ) {
    return join("\n", map { 
        my $meth = __PACKAGE__->can($_) or die __PACKAGE__ . " cant $_";
        map { my $sql = $meth->(ref $_ eq 'ARRAY' ? @$_ : $_); $sql ?  ("$sql;") : () } @{ $diffs->{$_} }
        
      } grep { @{$diffs->{$_}} } 
    qw/rename_table
       alter_drop_constraint
       alter_drop_index
       drop_field
       add_field
       alter_field
       rename_field
       alter_create_index
       alter_create_constraint
       alter_table/);
  }


  my @sql;
  my $old_table = $renaming ? $diffs->{rename_table}[0][0] : $table;
  
  do {
    local $table->{name} = $table_name . '_temp_alter';
    # We only want the table - dont care about indexes on tmp table
    my ($table_sql) = create_table($table, {no_comments => 1, temporary_table => 1});
    push @sql,$table_sql;
  };

  push @sql, "INSERT INTO @{[$table_name]}_temp_alter SELECT @{[ join(', ', $old_table->get_fields)]} FROM @{[$old_table]}",
             "DROP TABLE @{[$old_table]}",
             create_table($table, { no_comments => 1 }),
             "INSERT INTO @{[$table_name]} SELECT @{[ join(', ', $old_table->get_fields)]} FROM @{[$table_name]}_temp_alter",
             "DROP TABLE @{[$table_name]}_temp_alter";

  return join(";\n", @sql, "");
}

sub drop_table {
  my ($table) = @_;
  return "DROP TABLE $table;";
}

sub rename_table {
  my ($old_table, $new_table, $options) = @_;

  my $qt = $options->{quote_table_names} || '';

  return "ALTER TABLE $qt$old_table$qt RENAME TO $qt$new_table$qt";

}

# No-op. Just here to signify that we are a new style parser.
sub preproces_schema { }

1;

=pod

=head1 SEE ALSO

SQL::Translator, http://www.sqlite.org/.

=head1 AUTHOR

Ken Y. Clark C<< <kclark@cpan.orgE> >>.

Diff code added by Ash Berlin C<< <ash@cpan.org> >>.

=cut
