package SQL::Translator::Producer::Sybase;

=head1 NAME

SQL::Translator::Producer::Sybase - Sybase producer for SQL::Translator

=head1 SYNOPSIS

  use SQL::Translator;

  my $t = SQL::Translator->new( parser => '...', producer => 'Sybase' );
  $t->translate;

=head1 DESCRIPTION

This module will produce text output of the schema suitable for Sybase.

=cut

use strict;
use warnings;
our ($DEBUG, $WARN);
our $VERSION = '1.66';
$DEBUG = 1 unless defined $DEBUG;

use Data::Dumper;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(debug header_comment);

my %translate = (
  #
  # Sybase types
  #
  integer   => 'numeric',
  int       => 'numeric',
  number    => 'numeric',
  money     => 'money',
  varchar   => 'varchar',
  varchar2  => 'varchar',
  timestamp => 'datetime',
  text      => 'varchar',
  real      => 'double precision',
  comment   => 'text',
  bit       => 'bit',
  tinyint   => 'smallint',
  float     => 'double precision',
  serial    => 'numeric',
  boolean   => 'varchar',
  char      => 'char',
  long      => 'varchar',
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

sub produce {
  my $translator = shift;
  $DEBUG = $translator->debug;
  $WARN  = $translator->show_warnings;
  my $no_comments    = $translator->no_comments;
  my $add_drop_table = $translator->add_drop_table;
  my $schema         = $translator->schema;

  my @output;
  push @output, header_comment unless ($no_comments);

  my @foreign_keys;

  for my $table ($schema->get_tables) {
    my $table_name = $table->name or next;
    $table_name = mk_name($table_name, '', undef, 1);
    my $table_name_ur = unreserve($table_name) || '';

    my (@comments, @field_defs, @index_defs, @constraint_defs);

    push @comments, "--\n-- Table: $table_name_ur\n--" unless $no_comments;

    push @comments, map {"-- $_"} $table->comments;

    #
    # Fields
    #
    my %field_name_scope;
    for my $field ($table->get_fields) {
      my $field_name    = mk_name($field->name, '', \%field_name_scope, undef, 1);
      my $field_name_ur = unreserve($field_name, $table_name);
      my $field_def     = qq["$field_name_ur"];
      $field_def =~ s/\"//g;
      if ($field_def =~ /identity/) {
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
      my $commalist = join(', ', map {qq['$_']} @$list);
      my $seq_name;

      my $identity = '';

      if ($data_type eq 'enum') {
        my $check_name = mk_name($table_name . '_' . $field_name, 'chk', undef, 1);
        push @constraint_defs, "CONSTRAINT $check_name CHECK ($field_name IN ($commalist))";
        $data_type .= 'character varying';
      } elsif ($data_type eq 'set') {
        $data_type .= 'character varying';
      } else {
        if ($field->is_auto_increment) {
          $identity = 'IDENTITY';
        }
        if (defined $translate{$data_type}) {
          $data_type = $translate{$data_type};
        } else {
          warn "Unknown datatype: $data_type ", "($table_name.$field_name)\n"
              if $WARN;
        }
      }

      my $size = $field->size;
      unless ($size) {
        if ($data_type =~ /numeric/) {
          $size = '9,0';
        } elsif ($orig_data_type eq 'text') {

          #interpret text fields as long varchars
          $size = '255';
        } elsif ($data_type eq 'varchar'
          && $orig_data_type eq 'boolean') {
          $size = '6';
        } elsif ($data_type eq 'varchar') {
          $size = '255';
        }
      }

      $field_def .= " $data_type";
      $field_def .= "($size)"    if $size;
      $field_def .= " $identity" if $identity;

      #
      # Default value
      #
      my $default = $field->default_value;
      if (defined $default) {
        $field_def .= sprintf(' DEFAULT %s',
            ($field->is_auto_increment && $seq_name) ? qq[nextval('"$seq_name"'::text)]
          : ($default =~ m/null/i)                   ? 'NULL'
          :                                            "'$default'");
      }

      #
      # Not null constraint
      #
      unless ($field->is_nullable) {
        $field_def .= ' NOT NULL';
      } else {
        $field_def .= ' NULL' if $data_type ne 'bit';
      }

      push @field_defs, $field_def;
    }

    #
    # Constraint Declarations
    #
    my @constraint_decs = ();
    my $c_name_default;
    for my $constraint ($table->get_constraints) {
      my $name    = $constraint->name || '';
      my $type    = $constraint->type || NORMAL;
      my @fields  = map { unreserve($_, $table_name) } $constraint->fields;
      my @rfields = map { unreserve($_, $table_name) } $constraint->reference_fields;
      next unless @fields;

      if ($type eq PRIMARY_KEY) {
        $name ||= mk_name($table_name, 'pk', undef, 1);
        push @constraint_defs, "CONSTRAINT $name PRIMARY KEY " . '(' . join(', ', @fields) . ')';
      } elsif ($type eq FOREIGN_KEY) {
        $name ||= mk_name($table_name, 'fk', undef, 1);
        push @foreign_keys,
              "ALTER TABLE $table ADD CONSTRAINT $name FOREIGN KEY" . ' ('
            . join(', ', @fields)
            . ') REFERENCES '
            . $constraint->reference_table . ' ('
            . join(', ', @rfields) . ')';
      } elsif ($type eq UNIQUE) {
        $name ||= mk_name($table_name, $name || ++$c_name_default, undef, 1);
        push @constraint_defs, "CONSTRAINT $name UNIQUE " . '(' . join(', ', @fields) . ')';
      }
    }

    #
    # Indices
    #
    for my $index ($table->get_indices) {
      push @index_defs, 'CREATE INDEX ' . $index->name . " ON $table_name (" . join(', ', $index->fields) . ")";
    }

    my $drop_statement = $add_drop_table ? qq[DROP TABLE $table_name_ur] : '';
    my $create_statement
        = qq[CREATE TABLE $table_name_ur (\n] . join(",\n", map {"  $_"} @field_defs, @constraint_defs) . "\n)";

    $create_statement = join("\n\n", @comments) . "\n\n" . $create_statement;
    push @output, $create_statement, @index_defs,;
  }

  foreach my $view ($schema->get_views) {
    my (@comments, $view_name);

    $view_name = $view->name();
    push @comments, "--\n-- View: $view_name\n--" unless $no_comments;

    # text of view is already a 'create view' statement so no need
    # to do anything fancy.

    push @output, join("\n\n", @comments, $view->sql(),);
  }

  foreach my $procedure ($schema->get_procedures) {
    my (@comments, $procedure_name);

    $procedure_name = $procedure->name();
    push @comments, "--\n-- Procedure: $procedure_name\n--"
        unless $no_comments;

    # text of procedure  already has the 'create procedure' stuff
    # so there is no need to do anything fancy. However, we should
    # think about doing fancy stuff with granting permissions and
    # so on.

    push @output, join("\n\n", @comments, $procedure->sql(),);
  }
  push @output, @foreign_keys;

  if ($WARN) {
    if (%truncated) {
      warn "Truncated " . keys(%truncated) . " names:\n";
      warn "\t" . join("\n\t", sort keys %truncated) . "\n";
    }

    if (%unreserve) {
      warn "Encounted " . keys(%unreserve) . " unsafe names in schema (reserved or invalid):\n";
      warn "\t" . join("\n\t", sort keys %unreserve) . "\n";
    }
  }

  return wantarray ? @output : join ";\n\n", @output;
}

sub mk_name {
  my $basename      = shift || '';
  my $type          = shift || '';
  my $scope         = shift || '';
  my $critical      = shift || '';
  my $basename_orig = $basename;
  my $max_name
      = $type
      ? $max_id_length - (length($type) + 1)
      : $max_id_length;
  $basename = substr($basename, 0, $max_name)
      if length($basename) > $max_name;
  my $name = $type ? "${type}_$basename" : $basename;

  if ($basename ne $basename_orig and $critical) {
    my $show_type = $type ? "+'$type'" : "";
    warn "Truncating '$basename_orig'$show_type to $max_id_length ", "character limit to make '$name'\n"
        if $WARN;
    $truncated{$basename_orig} = $name;
  }

  $scope ||= \%global_names;
  if (my $prev = $scope->{$name}) {
    my $name_orig = $name;
    $name .= sprintf("%02d", ++$prev);
    substr($name, $max_id_length - 3) = "00"
        if length($name) > $max_id_length;

    warn "The name '$name_orig' has been changed to ", "'$name' to make it unique.\n"
        if $WARN;

    $scope->{$name_orig}++;
  }
  $name = substr($name, 0, $max_id_length)
      if ((length($name) > $max_id_length) && $critical);
  $scope->{$name}++;
  return $name;
}

sub unreserve {
  my $name            = shift || '';
  my $schema_obj_name = shift || '';
  my ($suffix)        = ($name =~ s/(\W.*)$//) ? $1 : '';

  # also trap fields that don't begin with a letter
  return $name if !$reserved{ uc $name } && $name =~ /^[a-z]/i;

  if ($schema_obj_name) {
    ++$unreserve{"$schema_obj_name.$name"};
  } else {
    ++$unreserve{"$name (table name)"};
  }

  my $unreserve = sprintf '%s_', $name;
  return $unreserve . $suffix;
}

1;

=pod

=head1 SEE ALSO

SQL::Translator.

=head1 AUTHORS

Sam Angiuoli E<lt>angiuoli@users.sourceforge.netE<gt>,
Paul Harrington E<lt>harringp@deshaw.comE<gt>,
Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut
