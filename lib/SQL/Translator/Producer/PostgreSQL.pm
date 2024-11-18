package SQL::Translator::Producer::PostgreSQL;

=head1 NAME

SQL::Translator::Producer::PostgreSQL - PostgreSQL producer for SQL::Translator

=head1 SYNOPSIS

  my $t = SQL::Translator->new( parser => '...', producer => 'PostgreSQL' );
  $t->translate;

=head1 DESCRIPTION

Creates a DDL suitable for PostgreSQL.  Very heavily based on the Oracle
producer.

Now handles PostGIS Geometry and Geography data types on table definitions.
Does not yet support PostGIS Views.

=head2 Producer Args

You can change the global behavior of the producer by passing the following options to the
C<producer_args> attribute of C<SQL::Translator>.

=over 4

=item postgres_version

The version of postgres to generate DDL for. Turns on features only available in later versions. The following features are supported

=over 4

=item IF EXISTS

If your postgres_version is higher than 8.003 (I should hope it is by now), then the DDL
generated for dropping objects in the database will contain IF EXISTS.

=back

=item attach_comments

Generates table and column comments via the COMMENT command rather than as a comment in
the DDL. You could then look it up with \dt+ or \d+ (for tables and columns respectively)
in psql. The comment is dollar quoted with $comment$ so you can include ' in it. Just to clarify: you get this

    CREATE TABLE foo ...;
    COMMENT on TABLE foo IS $comment$hi there$comment$;

instead of this

    -- comment
    CREAT TABLE foo ...;

=back

=head2 Extra args

Various schema types support various options via the C<extra> attribute.

=over 2

=item Tables

=over 2

=item temporary

Produces a temporary table.

=back

=item Views

=over 2

=item temporary

Produces a temporary view.

=item materialized

Produces a materialized view.

=back

=item Fields

=over 2

=item list, custom_type_name

For enum types, list is the list of valid values, and custom_type_name is the name that
the type should have. Defaults to $table_$field_type.

=item geometry_type, srid, dimensions, geography_type

Fields for use with PostGIS types.

=back

=back

=cut

use strict;
use warnings;
our ($DEBUG, $WARN);
our $VERSION = '1.66';
$DEBUG = 0 unless defined $DEBUG;

use base qw(SQL::Translator::Producer);
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils
    qw(debug header_comment parse_dbms_version batch_alter_table_statements normalize_quote_options);
use SQL::Translator::Generator::DDL::PostgreSQL;
use Data::Dumper;

use constant MAX_ID_LENGTH => 62;

{
  my ($quoting_generator, $nonquoting_generator);

  sub _generator {
    my $options = shift;
    return $options->{generator} if exists $options->{generator};

    return normalize_quote_options($options)
        ? $quoting_generator ||= SQL::Translator::Generator::DDL::PostgreSQL->new
        : $nonquoting_generator ||= SQL::Translator::Generator::DDL::PostgreSQL->new(quote_chars => [],);
  }
}

my (%translate);

BEGIN {

  %translate = (
    #
    # MySQL types
    #
    double     => 'double precision',
    decimal    => 'numeric',
    int        => 'integer',
    mediumint  => 'integer',
    tinyint    => 'smallint',
    char       => 'character',
    varchar    => 'character varying',
    longtext   => 'text',
    mediumtext => 'text',
    tinytext   => 'text',
    tinyblob   => 'bytea',
    blob       => 'bytea',
    mediumblob => 'bytea',
    longblob   => 'bytea',
    enum       => 'character varying',
    set        => 'character varying',
    datetime   => 'timestamp',
    year       => 'date',

    #
    # Oracle types
    #
    number   => 'integer',
    varchar2 => 'character varying',
    long     => 'text',
    clob     => 'text',

    #
    # Sybase types
    #
    comment => 'text',

    #
    # MS Access types
    #
    memo => 'text',
  );
}
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
    EXCLUDE [USING acc_method] (expression) [INCLUDE (column [, ...])] [WHERE (predicate)]
    FOREIGN KEY ( column_name [, ... ] ) REFERENCES reftable [ ( refcolumn [, ... ] ) ]
      [ MATCH FULL | MATCH PARTIAL ] [ ON DELETE action ] [ ON UPDATE action ] }
  [ DEFERRABLE | NOT DEFERRABLE ] [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]

=head1 Create Index Syntax

  CREATE [ UNIQUE ] INDEX index_name ON table
      [ USING acc_method ] ( column [ ops_name ] [, ...] )
      [ INCLUDE  ( column [, ...] ) ]
      [ WHERE predicate ]
  CREATE [ UNIQUE ] INDEX index_name ON table
      [ USING acc_method ] ( func_name( column [, ... ]) [ ops_name ] )
      [ WHERE predicate ]

=cut

sub produce {
  my $translator = shift;
  local $DEBUG = $translator->debug;
  local $WARN  = $translator->show_warnings;
  my $no_comments      = $translator->no_comments;
  my $add_drop_table   = $translator->add_drop_table;
  my $schema           = $translator->schema;
  my $pargs            = $translator->producer_args;
  my $postgres_version = parse_dbms_version($pargs->{postgres_version}, 'perl');

  my $generator = _generator({ quote_identifiers => $translator->quote_identifiers });

  my @output;
  push @output, header_comment unless ($no_comments);

  my (@table_defs, @fks);
  my %type_defs;
  for my $table ($schema->get_tables) {

    my ($table_def, $fks) = create_table(
      $table,
      {
        generator        => $generator,
        no_comments      => $no_comments,
        postgres_version => $postgres_version,
        add_drop_table   => $add_drop_table,
        type_defs        => \%type_defs,
        attach_comments  => $pargs->{attach_comments}
      }
    );

    push @table_defs, $table_def;
    push @fks,        @$fks;
  }

  for my $view ($schema->get_views) {
    push @table_defs,
        create_view(
          $view,
          {
            postgres_version => $postgres_version,
            add_drop_view    => $add_drop_table,
            generator        => $generator,
            no_comments      => $no_comments,
          }
        );
  }

  for my $trigger ($schema->get_triggers) {
    push @table_defs,
        create_trigger(
          $trigger,
          {
            add_drop_trigger => $add_drop_table,
            generator        => $generator,
            no_comments      => $no_comments,
          }
        );
  }

  push @output, map {"$_;\n\n"} values %type_defs;
  push @output, map {"$_;\n\n"} @table_defs;
  if (@fks) {
    push @output, "--\n-- Foreign Key Definitions\n--\n\n"
        unless $no_comments;
    push @output, map {"$_;\n\n"} @fks;
  }

  if ($WARN) {
    if (%truncated) {
      warn "Truncated " . keys(%truncated) . " names:\n";
      warn "\t" . join("\n\t", sort keys %truncated) . "\n";
    }
  }

  return wantarray
      ? @output
      : join('', @output);
}

{
  my %global_names;

  sub mk_name {
    my $basename      = shift || '';
    my $type          = shift || '';
    my $scope         = shift || '';
    my $critical      = shift || '';
    my $basename_orig = $basename;

    my $max_name
        = $type
        ? MAX_ID_LENGTH - (length($type) + 1)
        : MAX_ID_LENGTH;
    $basename = substr($basename, 0, $max_name)
        if length($basename) > $max_name;
    my $name = $type ? "${type}_$basename" : $basename;

    if ($basename ne $basename_orig and $critical) {
      my $show_type = $type ? "+'$type'" : "";
      warn "Truncating '$basename_orig'$show_type to ", MAX_ID_LENGTH, " character limit to make '$name'\n"
          if $WARN;
      $truncated{$basename_orig} = $name;
    }

    $scope ||= \%global_names;
    if (my $prev = $scope->{$name}) {
      my $name_orig = $name;
      $name .= sprintf("%02d", ++$prev);
      substr($name, MAX_ID_LENGTH - 3) = "00"
          if length($name) > MAX_ID_LENGTH;

      warn "The name '$name_orig' has been changed to ", "'$name' to make it unique.\n"
          if $WARN;

      $scope->{$name_orig}++;
    }

    $scope->{$name}++;
    return $name;
  }
}

sub is_geometry {
  my $field = shift;
  return 1 if $field->data_type eq 'geometry';
}

sub is_geography {
  my $field = shift;
  return 1 if $field->data_type eq 'geography';
}

sub create_table {
  my ($table, $options) = @_;

  my $generator        = _generator($options);
  my $no_comments      = $options->{no_comments}      || 0;
  my $add_drop_table   = $options->{add_drop_table}   || 0;
  my $postgres_version = $options->{postgres_version} || 0;
  my $type_defs        = $options->{type_defs}        || {};
  my $attach_comments  = $options->{attach_comments};

  my $table_name    = $table->name or next;
  my $table_name_qt = $generator->quote($table_name);

  my (@comments, @field_defs, @index_defs, @constraint_defs, @fks);

  push @comments, "--\n-- Table: $table_name\n--\n" unless $no_comments;

  my @comment_statements;
  if (my $comments = $table->comments) {
    if ($attach_comments) {

# this follows the example in the MySQL producer, where all comments are added as
# table comments, even though they could have originally been parsed as DDL comments
# quoted via $$ string so there can be 'quotes' inside the comments
      my $comment_ddl = "COMMENT on TABLE $table_name_qt IS \$comment\$$comments\$comment\$";
      push @comment_statements, $comment_ddl;
    } elsif (!$no_comments) {
      $comments =~ s/^/-- /mg;
      push @comments, "-- Comments:\n$comments\n--\n";
    }
  }

  #
  # Fields
  #
  for my $field ($table->get_fields) {
    push @field_defs,
        create_field(
          $field,
          {
            generator        => $generator,
            postgres_version => $postgres_version,
            type_defs        => $type_defs,
            constraint_defs  => \@constraint_defs,
            attach_comments  => $attach_comments
          }
        );
    if ($attach_comments) {
      my $field_comments = $field->comments;
      next unless $field_comments;
      my $field_name_qt = $generator->quote($field->name);
      my $comment_ddl   = "COMMENT on COLUMN $table_name_qt.$field_name_qt IS \$comment\$$field_comments\$comment\$";
      push @comment_statements, $comment_ddl;
    }

  }

  #
  # Index Declarations
  #
  for my $index ($table->get_indices) {
    my ($idef, $constraints) = create_index(
      $index,
      {
        generator        => $generator,
        postgres_version => $postgres_version,
      }
    );
    $idef and push @index_defs, $idef;
    push @constraint_defs, @$constraints;
  }

  #
  # Table constraints
  #
  for my $c ($table->get_constraints) {
    my ($cdefs, $fks) = create_constraint(
      $c,
      {
        generator => $generator,
      }
    );
    push @constraint_defs, @$cdefs;
    push @fks,             @$fks;
  }

  my $create_statement = join("\n", @comments);
  if ($add_drop_table) {
    if ($postgres_version >= 8.002) {
      $create_statement .= "DROP TABLE IF EXISTS $table_name_qt CASCADE;\n";
    } else {
      $create_statement .= "DROP TABLE $table_name_qt CASCADE;\n";
    }
  }
  my $temporary = $table->extra->{temporary} ? "TEMPORARY " : "";
  $create_statement .= "CREATE ${temporary}TABLE $table_name_qt (\n"
      . join(",\n", map {"  $_"} @field_defs, @constraint_defs) . "\n)";
  $create_statement .= @index_defs ? ';' : q{};
  $create_statement .= ($create_statement =~ /;$/ ? "\n" : q{}) . join(";\n", @index_defs);

  #
  # Geometry
  #
  if (my @geometry_columns = grep { is_geometry($_) } $table->get_fields) {
    $create_statement .= join(";\n", '', map { drop_geometry_column($_, $options) } @geometry_columns)
        if $options->{add_drop_table};
    $create_statement .= join(";\n", '', map { add_geometry_column($_, $options) } @geometry_columns);
  }

  if (@comment_statements) {
    $create_statement .= join(";\n", '', @comment_statements);
  }

  return $create_statement, \@fks;
}

sub create_view {
  my ($view, $options) = @_;
  my $generator        = _generator($options);
  my $postgres_version = $options->{postgres_version} || 0;
  my $add_drop_view    = $options->{add_drop_view};

  my $view_name = $view->name;
  debug("PKG: Looking at view '${view_name}'\n");

  my $create = '';
  $create .= "--\n-- View: " . $generator->quote($view_name) . "\n--\n"
      unless $options->{no_comments};
  if ($add_drop_view) {
    if ($postgres_version >= 8.002) {
      $create .= "DROP VIEW IF EXISTS " . $generator->quote($view_name) . ";\n";
    } else {
      $create .= "DROP VIEW " . $generator->quote($view_name) . ";\n";
    }
  }
  $create .= 'CREATE';

  my $extra = $view->extra;
  $create .= " TEMPORARY"
      if exists($extra->{temporary}) && $extra->{temporary};
  $create .= " MATERIALIZED"
      if exists($extra->{materialized}) && $extra->{materialized};
  $create .= " VIEW " . $generator->quote($view_name);

  if (my @fields = $view->fields) {
    my $field_list = join ', ', map { $generator->quote($_) } @fields;
    $create .= " ( ${field_list} )";
  }

  if (my $sql = $view->sql) {
    $create .= " AS\n    ${sql}\n";
  }

  if ($extra->{check_option}) {
    $create .= ' WITH ' . uc $extra->{check_option} . ' CHECK OPTION';
  }

  return $create;
}

# Returns a enum custom type name and list of values iff the field looks like an enum.
sub _enum_typename_and_values {
  my $field = shift;
  if (ref $field->extra->{list} eq 'ARRAY') {    # can't do anything unless we know the list
    if ($field->extra->{custom_type_name}) {
      return ($field->extra->{custom_type_name}, $field->extra->{list});
    } elsif ($field->data_type eq 'enum') {
      my $name = $field->table->name . '_' . $field->name . '_type';
      return ($name, $field->extra->{list});
    }
  }
  return ();
}

{

  my %field_name_scope;

  sub create_field {
    my ($field, $options) = @_;

    my $generator        = _generator($options);
    my $table_name       = $field->table->name;
    my $constraint_defs  = $options->{constraint_defs}  || [];
    my $postgres_version = $options->{postgres_version} || 0;
    my $type_defs        = $options->{type_defs}        || {};
    my $attach_comments  = $options->{attach_comments};

    $field_name_scope{$table_name} ||= {};
    my $field_name = $field->name;

    my $field_comments = '';
    if (!$attach_comments and my $comments = $field->comments) {
      $comments =~ s/(?<!\A)^/  -- /mg;
      $field_comments = "-- $comments\n  ";
    }

    my $field_def = $field_comments . $generator->quote($field_name);

    #
    # Datatype
    #
    my $data_type = lc $field->data_type;
    my %extra     = $field->extra;
    my ($enum_typename, $list) = _enum_typename_and_values($field);

    if ($postgres_version >= 8.003 && $enum_typename) {
      my $commalist = join(', ', map { __PACKAGE__->_quote_string($_) } @$list);
      $field_def .= ' ' . $enum_typename;
      my $new_type_def
          = "DROP TYPE IF EXISTS $enum_typename CASCADE;\n" . "CREATE TYPE $enum_typename AS ENUM ($commalist)";
      if (!exists $type_defs->{$enum_typename}) {
        $type_defs->{$enum_typename} = $new_type_def;
      } elsif ($type_defs->{$enum_typename} ne $new_type_def) {
        die "Attempted to redefine type name '$enum_typename' as a different type.\n";
      }
    } else {
      $field_def .= ' ' . convert_datatype($field);
    }

    #
    # Default value
    #
    __PACKAGE__->_apply_default_value(
      $field,
      \$field_def,
      [
        'NULL'              => \'NULL',
        'now()'             => 'now()',
        'CURRENT_TIMESTAMP' => 'CURRENT_TIMESTAMP',
      ],
    );

    #
    # Not null constraint
    #
    $field_def .= ' NOT NULL' unless $field->is_nullable;

    #
    # Geometry constraints
    #
    if (is_geometry($field)) {
      foreach (create_geometry_constraints($field, $options)) {
        my ($cdefs, $fks) = create_constraint($_, $options);
        push @$constraint_defs, @$cdefs;
        push @$fks,             @$fks;
      }
    }

    return $field_def;
  }
}

sub create_geometry_constraints {
  my ($field, $options) = @_;

  my $fname = _generator($options)->quote($field);
  my @constraints;
  push @constraints,
      SQL::Translator::Schema::Constraint->new(
        name       => "enforce_dims_" . $field->name,
        expression => "(ST_NDims($fname) = " . $field->extra->{dimensions} . ")",
        table      => $field->table,
        type       => CHECK_C,
      );

  push @constraints,
      SQL::Translator::Schema::Constraint->new(
        name       => "enforce_srid_" . $field->name,
        expression => "(ST_SRID($fname) = " . $field->extra->{srid} . ")",
        table      => $field->table,
        type       => CHECK_C,
      );
  push @constraints,
      SQL::Translator::Schema::Constraint->new(
        name       => "enforce_geotype_" . $field->name,
        expression => "(GeometryType($fname) = "
        . __PACKAGE__->_quote_string($field->extra->{geometry_type})
        . "::text OR $fname IS NULL)",
        table => $field->table,
        type  => CHECK_C,
      );

  return @constraints;
}

sub _extract_extras_from_options {
  my ($options_haver, $dispatcher) = @_;
  for my $opt ($options_haver->options) {
    if (ref $opt eq 'HASH') {
      for my $key (keys %$opt) {
        my $val = $opt->{$key};
        next unless defined $val;
        $dispatcher->{ lc $key }->($val);
      }
    }
  }
}

{
  my %index_name;

  sub create_index {
    my ($index, $options) = @_;

    my $generator        = _generator($options);
    my $table_name       = $index->table->name;
    my $postgres_version = $options->{postgres_version} || 0;

    my ($index_def, @constraint_defs);

    my $name = $index->name
        || join('_', $table_name, 'idx', ++$index_name{$table_name});

    my $type   = $index->type || NORMAL;
    my @fields = $index->fields;
    return unless @fields;

    my %index_extras;
    _extract_extras_from_options(
      $index,
      {
        using   => sub { $index_extras{using} = "USING $_[0]" },
        where   => sub { $index_extras{where} = "WHERE $_[0]" },
        include => sub {
          my ($value) = @_;
          return unless $postgres_version >= 11;
          die 'Include list must be an arrayref'
              unless ref $value eq 'ARRAY';
          my $value_list = join ', ', @$value;
          $index_extras{include} = "INCLUDE ($value_list)";
        }
      }
    );

    my $def_start   = 'CONSTRAINT ' . $generator->quote($name) . ' ';
    my $field_names = '(' . join(", ", (map { $_ =~ /\(.*\)/ ? $_ : ($generator->quote($_)) } @fields)) . ')';
    if ($type eq PRIMARY_KEY) {
      push @constraint_defs, "${def_start}PRIMARY KEY " . $field_names;
    } elsif ($type eq UNIQUE) {
      push @constraint_defs, "${def_start}UNIQUE " . $field_names;
    } elsif ($type eq NORMAL) {
      $index_def
          = 'CREATE INDEX ' . $generator->quote($name) . ' on ' . $generator->quote($table_name) . ' ' . join ' ',
          grep {defined} $index_extras{using}, $field_names,
          @index_extras{ 'include', 'where' };
    } else {
      warn "Unknown index type ($type) on table $table_name.\n"
          if $WARN;
    }

    return $index_def, \@constraint_defs;
  }
}

sub create_constraint {
  my ($c, $options) = @_;

  my $generator        = _generator($options);
  my $postgres_version = $options->{postgres_version} || 0;
  my $table_name       = $c->table->name;
  my (@constraint_defs, @fks);
  my %constraint_extras;
  _extract_extras_from_options(
    $c,
    {
      using   => sub { $constraint_extras{using} = "USING $_[0]" },
      where   => sub { $constraint_extras{where} = "WHERE ( $_[0] )" },
      include => sub {
        my ($value) = @_;
        return unless $postgres_version >= 11;
        die 'Include list must be an arrayref'
            unless ref $value eq 'ARRAY';
        my $value_list = join ', ', @$value;
        $constraint_extras{include} = "INCLUDE ( $value_list )";
      },
    }
  );

  my $name = $c->name || '';

  my @fields = grep {defined} $c->fields;

  my @rfields = grep {defined} $c->reference_fields;

  return if !@fields && ($c->type ne CHECK_C && $c->type ne EXCLUDE);
  my $def_start   = $name ? 'CONSTRAINT ' . $generator->quote($name) : '';
  my $field_names = '(' . join(", ", (map { $_ =~ /\(.*\)/ ? $_ : ($generator->quote($_)) } @fields)) . ')';
  my $include     = $constraint_extras{include} || '';
  if ($c->type eq PRIMARY_KEY) {
    push @constraint_defs, join ' ', grep $_, $def_start, "PRIMARY KEY", $field_names, $include;
  } elsif ($c->type eq UNIQUE) {
    push @constraint_defs, join ' ', grep $_, $def_start, "UNIQUE", $field_names, $include;
  } elsif ($c->type eq CHECK_C) {
    my $expression = $c->expression;
    push @constraint_defs, join ' ', grep $_, $def_start, "CHECK ($expression)";
  } elsif ($c->type eq FOREIGN_KEY) {
    my $def .= join ' ', grep $_, "ALTER TABLE",
        $generator->quote($table_name), 'ADD', $def_start,
        "FOREIGN KEY $field_names";
    $def .= "\n  REFERENCES " . $generator->quote($c->reference_table);

    if (@rfields) {
      $def .= ' (' . join(', ', map { $generator->quote($_) } @rfields) . ')';
    }

    if ($c->match_type) {
      $def .= ' MATCH ' . ($c->match_type =~ /full/i) ? 'FULL' : 'PARTIAL';
    }

    if ($c->on_delete) {
      $def .= ' ON DELETE ' . $c->on_delete;
    }

    if ($c->on_update) {
      $def .= ' ON UPDATE ' . $c->on_update;
    }

    if ($c->deferrable) {
      $def .= ' DEFERRABLE';
    }

    push @fks, "$def";
  } elsif ($c->type eq EXCLUDE) {
    my $using      = $constraint_extras{using} || '';
    my $expression = $c->expression;
    my $where      = $constraint_extras{where} || '';
    push @constraint_defs, join ' ', grep $_, $def_start, 'EXCLUDE', $using, "( $expression )", $include, $where;
  }

  return \@constraint_defs, \@fks;
}

sub create_trigger {
  my ($trigger, $options) = @_;
  my $generator = _generator($options);

  my @statements;

  push @statements, sprintf('DROP TRIGGER IF EXISTS %s', $generator->quote($trigger->name))
      if $options->{add_drop_trigger};

  my $scope = $trigger->scope || '';
  $scope = " FOR EACH $scope" if $scope;

  push @statements,
      sprintf(
        'CREATE TRIGGER %s %s %s ON %s%s %s',
        $generator->quote($trigger->name),
        $trigger->perform_action_when,
        join(' OR ', @{ $trigger->database_events }),
        $generator->quote($trigger->on_table),
        $scope, $trigger->action,
      );

  return @statements;
}

sub convert_datatype {
  my ($field) = @_;

  my @size      = $field->size;
  my $data_type = lc $field->data_type;
  my $array     = $data_type =~ s/\[\]$//;

  if ($data_type eq 'enum') {

    #        my $len = 0;
    #        $len = ($len < length($_)) ? length($_) : $len for (@$list);
    #        my $chk_name = mk_name( $table_name.'_'.$field_name, 'chk' );
    #        push @$constraint_defs,
    #        'CONSTRAINT "$chk_name" CHECK (' . $generator->quote(field_name) .
    #           qq[IN ($commalist))];
    $data_type = 'character varying';
  } elsif ($data_type eq 'set') {
    $data_type = 'character varying';
  } elsif ($field->is_auto_increment) {
    if ((defined $size[0] && $size[0] > 11) or $data_type eq 'bigint') {
      $data_type = 'bigserial';
    } else {
      $data_type = 'serial';
    }
    undef @size;
  } else {
    $data_type
        = defined $translate{ lc $data_type }
        ? $translate{ lc $data_type }
        : $data_type;
  }

  if ($data_type =~ /^time/i || $data_type =~ /^interval/i) {
    if (defined $size[0] && $size[0] > 6) {
      $size[0] = 6;
    }
  }

  if ($data_type eq 'integer') {
    if (defined $size[0] && $size[0] > 0) {
      if ($size[0] > 10) {
        $data_type = 'bigint';
      } elsif ($size[0] < 5) {
        $data_type = 'smallint';
      } else {
        $data_type = 'integer';
      }
    } else {
      $data_type = 'integer';
    }
  }

  my $type_with_size = join('|',
    'bit',  'varbit',    'character', 'bit varying', 'character varying',
    'time', 'timestamp', 'interval',  'numeric',     'float');

  if ($data_type !~ /$type_with_size/) {
    @size = ();
  }

  if (defined $size[0] && $size[0] > 0 && $data_type =~ /^time/i) {
    $data_type =~ s/^(time.*?)( with.*)?$/$1($size[0])/;
    $data_type .= $2 if (defined $2);
  } elsif (defined $size[0] && $size[0] > 0) {
    $data_type .= '(' . join(',', @size) . ')';
  }
  if ($array) {
    $data_type .= '[]';
  }

  #
  # Geography
  #
  if ($data_type eq 'geography') {
    $data_type .= '(' . $field->extra->{geography_type} . ',' . $field->extra->{srid} . ')';
  }

  return $data_type;
}

sub alter_field {
  my ($from_field, $to_field, $options) = @_;

  die "Can't alter field in another table"
      if ($from_field->table->name ne $to_field->table->name);

  my $generator = _generator($options);
  my @out;

  # drop geometry column and constraints
  push @out, drop_geometry_column($from_field, $options), drop_geometry_constraints($from_field, $options),
      if is_geometry($from_field);

  # it's necessary to start with rename column cause this would affect
  # all of the following statements which would be broken if do the
  # rename later
  # BUT: drop geometry is done before the rename, cause it work's on the
  # $from_field directly
  push @out,
      sprintf('ALTER TABLE %s RENAME COLUMN %s TO %s',
    map($generator->quote($_), $to_field->table->name, $from_field->name, $to_field->name,),)
      if ($from_field->name ne $to_field->name);

  push @out,
      sprintf('ALTER TABLE %s ALTER COLUMN %s SET NOT NULL',
    map($generator->quote($_), $to_field->table->name, $to_field->name),)
      if (!$to_field->is_nullable and $from_field->is_nullable);

  push @out,
      sprintf('ALTER TABLE %s ALTER COLUMN %s DROP NOT NULL',
    map($generator->quote($_), $to_field->table->name, $to_field->name),)
      if (!$from_field->is_nullable and $to_field->is_nullable);

  my $from_dt = convert_datatype($from_field);
  my $to_dt   = convert_datatype($to_field);
  push @out,
      sprintf('ALTER TABLE %s ALTER COLUMN %s TYPE %s',
    map($generator->quote($_), $to_field->table->name, $to_field->name), $to_dt,)
      if ($to_dt ne $from_dt);

  my ($from_enum_typename, $from_list) = _enum_typename_and_values($from_field);
  my ($to_enum_typename,   $to_list)   = _enum_typename_and_values($to_field);
  if ( $from_enum_typename
    && $to_enum_typename
    && $from_enum_typename eq $to_enum_typename) {
    # See if new enum values were added, and update the enum
    my %existing_vals = map +($_ => 1), @$from_list;
    my %desired_vals  = map +($_ => 1), @$to_list;
    my @add_vals      = grep !$existing_vals{$_}, keys %desired_vals;
    my @del_vals      = grep !$desired_vals{$_},  keys %existing_vals;
    my $pg_ver_ok     = ($options->{postgres_version} || 0) >= 9.001;
    push @out, '-- Set $sqlt->producer_args->{postgres_version} >= 9.001 to alter enums'
        if !$pg_ver_ok && @add_vals;
    for (@add_vals) {
      push @out, sprintf '%sALTER TYPE %s ADD VALUE IF NOT EXISTS %s',
          ($pg_ver_ok ? '' : '-- '), $to_enum_typename,
          $generator->quote_string($_);
    }
    push @out, "-- Unimplemented: delete values from enum type '$to_enum_typename': " . join(", ", @del_vals)
        if @del_vals;
  }

  my $old_default   = $from_field->default_value;
  my $new_default   = $to_field->default_value;
  my $default_value = $to_field->default_value;

  # fixes bug where output like this was created:
  # ALTER TABLE users ALTER COLUMN column SET DEFAULT ThisIsUnescaped;
  if (ref $default_value eq "SCALAR") {
    $default_value = $$default_value;
  } elsif (defined $default_value
    && $to_dt =~ /^(character|text|timestamp|date)/xsmi) {
    $default_value = __PACKAGE__->_quote_string($default_value);
  }

  push @out,
      sprintf(
        'ALTER TABLE %s ALTER COLUMN %s SET DEFAULT %s',
        map($generator->quote($_), $to_field->table->name, $to_field->name,),
        $default_value,
      )
      if (defined $new_default
        && (!defined $old_default || $old_default ne $new_default));

  # fixes bug where removing the DEFAULT statement of a column
  # would result in no change

  push @out,
      sprintf('ALTER TABLE %s ALTER COLUMN %s DROP DEFAULT',
    map($generator->quote($_), $to_field->table->name, $to_field->name,),)
      if (!defined $new_default && defined $old_default);

  # add geometry column and constraints
  push @out, add_geometry_column($to_field, $options), add_geometry_constraints($to_field, $options),
      if is_geometry($to_field);

  return wantarray ? @out : join(";\n", @out);
}

sub rename_field { alter_field(@_) }

sub add_field {
  my ($new_field, $options) = @_;

  my $out = sprintf(
    'ALTER TABLE %s ADD COLUMN %s',
    _generator($options)->quote($new_field->table->name),
    create_field($new_field, $options)
  );
  $out .= ";\n" . add_geometry_column($new_field, $options) . ";\n" . add_geometry_constraints($new_field, $options)
      if is_geometry($new_field);
  return $out;

}

sub drop_field {
  my ($old_field, $options) = @_;

  my $generator = _generator($options);

  my $out = sprintf(
    'ALTER TABLE %s DROP COLUMN %s',
    $generator->quote($old_field->table->name),
    $generator->quote($old_field->name)
  );
  $out .= ";\n" . drop_geometry_column($old_field, $options)
      if is_geometry($old_field);
  return $out;
}

sub add_geometry_column {
  my ($field, $options) = @_;

  return sprintf(
    "INSERT INTO geometry_columns VALUES (%s,%s,%s,%s,%s,%s,%s)",
    map(__PACKAGE__->_quote_string($_),
      '',
      $field->table->schema->name,
      $options->{table} ? $options->{table} : $field->table->name,
      $field->name,
      $field->extra->{dimensions},
      $field->extra->{srid},
      $field->extra->{geometry_type},
    ),
  );
}

sub drop_geometry_column {
  my ($field) = @_;

  return
      sprintf("DELETE FROM geometry_columns WHERE f_table_schema = %s AND f_table_name = %s AND f_geometry_column = %s",
        map(__PACKAGE__->_quote_string($_), $field->table->schema->name, $field->table->name, $field->name,),);
}

sub add_geometry_constraints {
  my ($field, $options) = @_;

  return join(";\n", map { alter_create_constraint($_, $options) } create_geometry_constraints($field, $options));
}

sub drop_geometry_constraints {
  my ($field, $options) = @_;

  return join(";\n", map { alter_drop_constraint($_, $options) } create_geometry_constraints($field, $options));

}

sub alter_table {
  my ($to_table, $options) = @_;
  my $generator = _generator($options);
  my $out       = sprintf('ALTER TABLE %s %s', $generator->quote($to_table->name), $options->{alter_table_action});
  $out .= ";\n" . $options->{geometry_changes}
      if $options->{geometry_changes};
  return $out;
}

sub rename_table {
  my ($old_table, $new_table, $options) = @_;
  my $generator = _generator($options);
  $options->{alter_table_action} = "RENAME TO " . $generator->quote($new_table);

  my @geometry_changes
      = map { drop_geometry_column($_, $options), add_geometry_column($_, { %{$options}, table => $new_table }), }
      grep { is_geometry($_) } $old_table->get_fields;

  $options->{geometry_changes} = join(";\n", @geometry_changes)
      if @geometry_changes;

  return alter_table($old_table, $options);
}

sub alter_create_index {
  my ($index, $options) = @_;
  my $generator = _generator($options);
  my ($idef, $constraints) = create_index($index, $options);
  return $index->type eq NORMAL
      ? $idef
      : sprintf('ALTER TABLE %s ADD %s', $generator->quote($index->table->name), join(q{}, @$constraints));
}

sub alter_drop_index {
  my ($index, $options) = @_;
  return 'DROP INDEX ' . _generator($options)->quote($index->name);
}

sub alter_drop_constraint {
  my ($c, $options) = @_;
  my $generator = _generator($options);

  # NOT NULL constraint does not require a DROP CONSTRAINT statement
  if ($c->type eq NOT_NULL) {
    return;
  }

  # attention: Postgres  has a very special naming structure for naming
  # foreign keys and primary keys.  It names them using the name of the
  # table as prefix and fkey or pkey as suffix, concatenated by an underscore
  my $c_name;
  if ($c->name) {

    # Already has a name, just use it
    $c_name = $c->name;
  } else {
    # if the name is dotted we need the table, not schema nor database
    my ($tablename) = reverse split /[.]/, $c->table->name;
    if ($c->type eq FOREIGN_KEY) {

      # Doesn't have a name, and is foreign key, append '_fkey'
      $c_name = $tablename . '_' . ($c->fields)[0] . '_fkey';
    } elsif ($c->type eq PRIMARY_KEY) {

      # Doesn't have a name, and is primary key, append '_pkey'
      $c_name = $tablename . '_pkey';
    }
  }

  return sprintf('ALTER TABLE %s DROP CONSTRAINT %s', map { $generator->quote($_) } $c->table->name, $c_name,);
}

sub alter_create_constraint {
  my ($index, $options) = @_;
  my $generator = _generator($options);
  my ($defs, $fks) = create_constraint(@_);

  # return if there are no constraint definitions so we don't run
  # into output like this:
  # ALTER TABLE users ADD ;

  return unless (@{$defs} || @{$fks});
  return $index->type eq FOREIGN_KEY
      ? join(q{}, @{$fks})
      : join(' ', 'ALTER TABLE', $generator->quote($index->table->name), 'ADD', join(q{}, @{$defs}, @{$fks}));
}

sub drop_table {
  my ($table, $options) = @_;
  my $generator = _generator($options);
  my $out       = "DROP TABLE " . $generator->quote($table) . " CASCADE";

  my @geometry_drops = map { drop_geometry_column($_); }
      grep { is_geometry($_) } $table->get_fields;

  $out .= join(";\n", '', @geometry_drops) if @geometry_drops;
  return $out;
}

sub batch_alter_table {
  my ($table, $diff_hash, $options) = @_;

  # as long as we're not renaming the table we don't need to be here
  if (@{ $diff_hash->{rename_table} } == 0) {
    return batch_alter_table_statements($diff_hash, $options);
  }

  # first we need to perform drops which are on old table
  my @sql = batch_alter_table_statements(
    $diff_hash, $options, qw(
      alter_drop_constraint
      alter_drop_index
      drop_field
    )
  );

  # next comes the rename_table
  my $old_table = $diff_hash->{rename_table}[0][0];
  push @sql, rename_table($old_table, $table, $options);

  # for alter_field (and so also rename_field) we need to make sure old
  # field has table name set to new table otherwise calling alter_field dies
  $diff_hash->{alter_field}  = [ map { $_->[0]->table($table) && $_ } @{ $diff_hash->{alter_field} } ];
  $diff_hash->{rename_field} = [ map { $_->[0]->table($table) && $_ } @{ $diff_hash->{rename_field} } ];

  # now add everything else
  push @sql, batch_alter_table_statements(
    $diff_hash, $options, qw(
      add_field
      alter_field
      rename_field
      alter_create_index
      alter_create_constraint
      alter_table
    )
  );

  return @sql;
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

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut
