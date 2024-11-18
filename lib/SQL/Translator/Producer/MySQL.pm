package SQL::Translator::Producer::MySQL;

=head1 NAME

SQL::Translator::Producer::MySQL - MySQL-specific producer for SQL::Translator

=head1 SYNOPSIS

Use via SQL::Translator:

  use SQL::Translator;

  my $t = SQL::Translator->new( parser => '...', producer => 'MySQL', '...' );
  $t->translate;

=head1 DESCRIPTION

This module will produce text output of the schema suitable for MySQL.
There are still some issues to be worked out with syntax differences
between MySQL versions 3 and 4 ("SET foreign_key_checks," character sets
for fields, etc.).

=head1 ARGUMENTS

This producer takes a single optional producer_arg C<mysql_version>, which
provides the desired version for the target database. By default MySQL v3 is
assumed, and statements pertaining to any features introduced in later versions
(e.g. CREATE VIEW) are not produced.

Valid version specifiers for C<mysql_version> are listed L<here|SQL::Translator::Utils/parse_mysql_version>

=head2 Table Types

Normally the tables will be created without any explicit table type given and
so will use the MySQL default.

Any tables involved in foreign key constraints automatically get a table type
of InnoDB, unless this is overridden by setting the C<mysql_table_type> extra
attribute explicitly on the table.

=head2 Extra attributes.

The producer recognises the following extra attributes on the Schema objects.

=over 4

=item B<field.list>

Set the list of allowed values for Enum fields.

=item B<field.binary>, B<field.unsigned>, B<field.zerofill>

Set the MySQL field options of the same name.

=item B<field.renamed_from>, B<table.renamed_from>

Use when producing diffs to indicate that the current table/field has been
renamed from the old name as given in the attribute value.

=item B<table.mysql_table_type>

Set the type of the table e.g. 'InnoDB', 'MyISAM'. This will be
automatically set for tables involved in foreign key constraints if it is
not already set explicitly. See L<"Table Types">.

Please note that the C<ENGINE> option is the preferred method of specifying
the MySQL storage engine to use, but this method still works for backwards
compatibility.

=item B<table.mysql_charset>, B<table.mysql_collate>

Set the tables default character set and collation order.

=item B<field.mysql_charset>, B<field.mysql_collate>

Set the fields character set and collation order.

=back

=cut

use strict;
use warnings;
our ($DEBUG, %used_names);
our $VERSION = '1.66';
$DEBUG = 0 unless defined $DEBUG;

# Maximum length for most identifiers is 64, according to:
#   http://dev.mysql.com/doc/refman/4.1/en/identifiers.html
#   http://dev.mysql.com/doc/refman/5.0/en/identifiers.html
my $DEFAULT_MAX_ID_LENGTH = 64;

use base qw(SQL::Translator::Producer);
use Data::Dumper;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Generator::DDL::MySQL;
use SQL::Translator::Utils qw(debug header_comment
    truncate_id_uniquely parse_mysql_version
    batch_alter_table_statements
    normalize_quote_options
);

#
# Use only lowercase for the keys (e.g. "long" and not "LONG")
#
my %translate = (
  #
  # Oracle types
  #
  varchar2 => 'varchar',
  long     => 'text',
  clob     => 'longtext',

  #
  # Sybase types
  #
  int     => 'integer',
  money   => 'float',
  real    => 'double',
  comment => 'text',
  bit     => 'tinyint',

  #
  # Access types
  #
  'long integer' => 'integer',
  'text'         => 'text',
  'datetime'     => 'datetime',

  #
  # PostgreSQL types
  #
  bytea => 'BLOB',
);

#
# Column types that do not support length attribute
#
my @no_length_attr = qw/
    date time timestamp datetime year
    /;

sub preprocess_schema {
  my ($schema) = @_;

  # extra->{mysql_table_type} used to be the type. It belongs in options, so
  # move it if we find it. Return Engine type if found in extra or options
  # Similarly for mysql_charset and mysql_collate
  my $extra_to_options = sub {
    my ($table, $extra_name, $opt_name) = @_;

    my $extra = $table->extra;

    my $extra_type = delete $extra->{$extra_name};

    # Now just to find if there is already an Engine or Type option...
    # and lets normalize it to ENGINE since:
    #
    # The ENGINE table option specifies the storage engine for the table.
    # TYPE is a synonym, but ENGINE is the preferred option name.
    #

    my $options = $table->options;

    # If multiple option names, normalize to the first one
    if (ref $opt_name) {
  OPT_NAME: for (@$opt_name[ 1 .. $#$opt_name ]) {
        for my $idx (0 .. $#{$options}) {
          my ($key, $value) = %{ $options->[$idx] };

          if (uc $key eq $_) {
            $options->[$idx] = { $opt_name->[0] => $value };
            last OPT_NAME;
          }
        }
      }
      $opt_name = $opt_name->[0];

    }

    # This assumes that there isn't both a Type and an Engine option.
OPTION:
    for my $idx (0 .. $#{$options}) {
      my ($key, $value) = %{ $options->[$idx] };

      next unless uc $key eq $opt_name;

      # make sure case is right on option name
      delete $options->[$idx]{$key};
      return $options->[$idx]{$opt_name} = $value || $extra_type;

    }

    if ($extra_type) {
      push @$options, { $opt_name => $extra_type };
      return $extra_type;
    }

  };

  # Names are only specific to a given schema
  local %used_names = ();

  #
  # Work out which tables need to be InnoDB to support foreign key
  # constraints. We do this first as we need InnoDB at both ends.
  #
  foreach my $table ($schema->get_tables) {

    $extra_to_options->($table, 'mysql_table_type', [ 'ENGINE', 'TYPE' ]);
    $extra_to_options->($table, 'mysql_charset',    'CHARACTER SET');
    $extra_to_options->($table, 'mysql_collate',    'COLLATE');

    foreach my $c ($table->get_constraints) {
      next unless $c->type eq FOREIGN_KEY;

      # Normalize constraint names here.
      my $c_name = $c->name;

      # Give the constraint a name if it doesn't have one, so it doesn't feel
      # left out
      $c_name = $table->name . '_fk' unless length $c_name;

      $c->name(next_unused_name($c_name));

      for my $meth (qw/table reference_table/) {
        my $table = $schema->get_table($c->$meth) || next;

        # This normalizes the types to ENGINE and returns the value if its there
        next
            if $extra_to_options->($table, 'mysql_table_type', [ 'ENGINE', 'TYPE' ]);
        $table->options({ 'ENGINE' => 'InnoDB' });
      }
    }    # foreach constraints

    my %map = (mysql_collate => 'collate', mysql_charset => 'character set');
    foreach my $f ($table->get_fields) {
      my $extra = $f->extra;
      for (keys %map) {
        $extra->{ $map{$_} } = delete $extra->{$_}
            if exists $extra->{$_};
      }

      my @size = $f->size;
      if (!$size[0] && $f->data_type =~ /char$/) {
        $f->size((255));
      }
    }

  }
}

{
  my ($quoting_generator, $nonquoting_generator);

  sub _generator {
    my $options = shift;
    return $options->{generator} if exists $options->{generator};

    return normalize_quote_options($options)
        ? $quoting_generator ||= SQL::Translator::Generator::DDL::MySQL->new()
        : $nonquoting_generator ||= SQL::Translator::Generator::DDL::MySQL->new(quote_chars => [],);
  }
}

sub produce {
  my $translator = shift;
  local $DEBUG = $translator->debug;
  local %used_names;
  my $no_comments    = $translator->no_comments;
  my $add_drop_table = $translator->add_drop_table;
  my $schema         = $translator->schema;
  my $show_warnings  = $translator->show_warnings || 0;
  my $producer_args  = $translator->producer_args;
  my $mysql_version  = parse_mysql_version($producer_args->{mysql_version}, 'perl') || 0;
  my $max_id_length  = $producer_args->{mysql_max_id_length}                        || $DEFAULT_MAX_ID_LENGTH;

  my $generator = _generator({ quote_identifiers => $translator->quote_identifiers });

  debug("PKG: Beginning production\n");
  %used_names = ();
  my $create = '';
  $create .= header_comment unless ($no_comments);

  # \todo Don't set if MySQL 3.x is set on command line
  my @create = "SET foreign_key_checks=0";

  preprocess_schema($schema);

  #
  # Generate sql
  #
  my @table_defs = ();

  for my $table ($schema->get_tables) {

    #        print $table->name, "\n";
    push @table_defs,
        create_table(
          $table,
          {
            add_drop_table => $add_drop_table,
            show_warnings  => $show_warnings,
            no_comments    => $no_comments,
            generator      => $generator,
            max_id_length  => $max_id_length,
            mysql_version  => $mysql_version
          }
        );
  }

  if ($mysql_version >= 5.000001) {
    for my $view ($schema->get_views) {
      push @table_defs,
          create_view(
            $view,
            {
              add_replace_view => $add_drop_table,
              show_warnings    => $show_warnings,
              no_comments      => $no_comments,
              generator        => $generator,
              max_id_length    => $max_id_length,
              mysql_version    => $mysql_version
            }
          );
    }
  }

  if ($mysql_version >= 5.000002) {
    for my $trigger ($schema->get_triggers) {
      push @table_defs,
          create_trigger(
            $trigger,
            {
              add_drop_trigger => $add_drop_table,
              show_warnings    => $show_warnings,
              no_comments      => $no_comments,
              generator        => $generator,
              max_id_length    => $max_id_length,
              mysql_version    => $mysql_version
            }
          );
    }
  }

  #    print "@table_defs\n";
  push @table_defs, "SET foreign_key_checks=1";

  return wantarray
      ? ($create ? $create : (), @create, @table_defs)
      : ($create . join('', map { $_ ? "$_;\n\n" : () } (@create, @table_defs)));
}

sub create_trigger {
  my ($trigger, $options) = @_;
  my $generator = _generator($options);

  my $trigger_name = $trigger->name;
  debug("PKG: Looking at trigger '${trigger_name}'\n");

  my @statements;

  my $events = $trigger->database_events;
  for my $event (@$events) {
    my $name = $trigger_name;
    if (@$events > 1) {
      $name .= "_$event";

      warn
          "Multiple database events supplied for trigger '${trigger_name}', ",
          "creating trigger '${name}'  for the '${event}' event\n"
          if $options->{show_warnings};
    }

    my $action = $trigger->action;
    if ($action !~ /^ \s* BEGIN [\s\;] .*? [\s\;] END [\s\;]* $/six) {
      $action .= ";" unless $action =~ /;\s*\z/;
      $action = "BEGIN $action END";
    }

    push @statements, "DROP TRIGGER IF EXISTS " . $generator->quote($name)
        if $options->{add_drop_trigger};
    push @statements,
        sprintf(
          "CREATE TRIGGER %s %s %s ON %s\n  FOR EACH ROW %s",
          $generator->quote($name),
          $trigger->perform_action_when,
          $event, $generator->quote($trigger->on_table), $action,
        );

  }

  # Tack the comment onto the first statement
  $statements[0] = "--\n-- Trigger " . $generator->quote($trigger_name) . "\n--\n" . $statements[0]
      unless $options->{no_comments};
  return @statements;
}

sub create_view {
  my ($view, $options) = @_;
  my $generator = _generator($options);

  my $view_name    = $view->name;
  my $view_name_qt = $generator->quote($view_name);

  debug("PKG: Looking at view '${view_name}'\n");

  # Header.  Should this look like what mysqldump produces?
  my $create = '';
  $create .= "--\n-- View: $view_name_qt\n--\n"
      unless $options->{no_comments};
  $create .= 'CREATE';
  $create .= ' OR REPLACE' if $options->{add_replace_view};
  $create .= "\n";

  my $extra = $view->extra;

  # ALGORITHM
  if (exists($extra->{mysql_algorithm})
    && defined(my $algorithm = $extra->{mysql_algorithm})) {
    $create .= "   ALGORITHM = ${algorithm}\n"
        if $algorithm =~ /(?:UNDEFINED|MERGE|TEMPTABLE)/i;
  }

  # DEFINER
  if (exists($extra->{mysql_definer})
    && defined(my $user = $extra->{mysql_definer})) {
    $create .= "   DEFINER = ${user}\n";
  }

  # SECURITY
  if (exists($extra->{mysql_security})
    && defined(my $security = $extra->{mysql_security})) {
    $create .= "   SQL SECURITY ${security}\n"
        if $security =~ /(?:DEFINER|INVOKER)/i;
  }

  #Header, cont.
  $create .= "  VIEW $view_name_qt";

  if (my @fields = $view->fields) {
    my $list = join ', ', map { $generator->quote($_) } @fields;
    $create .= " ( ${list} )";
  }
  if (my $sql = $view->sql) {

    # do not wrap parenthesis around the selector, mysql doesn't like this
    # http://bugs.mysql.com/bug.php?id=9198
    $create .= " AS\n    ${sql}\n";
  }

  #    $create .= "";
  return $create;
}

sub create_table {
  my ($table, $options) = @_;
  my $generator = _generator($options);

  my $table_name = $generator->quote($table->name);
  debug("PKG: Looking at table '$table_name'\n");

  #
  # Header.  Should this look like what mysqldump produces?
  #
  my $create = '';
  my $drop;
  $create .= "--\n-- Table: $table_name\n--\n" unless $options->{no_comments};
  $drop = qq[DROP TABLE IF EXISTS $table_name] if $options->{add_drop_table};
  $create .= "CREATE TABLE $table_name (\n";

  #
  # Fields
  #
  my @field_defs;
  for my $field ($table->get_fields) {
    push @field_defs, create_field($field, $options);
  }

  #
  # Indices
  #
  my @index_defs;
  my %indexed_fields;
  for my $index ($table->get_indices) {
    push @index_defs, create_index($index, $options);
    $indexed_fields{$_} = 1 for $index->fields;
  }

  #
  # Constraints -- need to handle more than just FK. -ky
  #
  my @constraint_defs;
  my @constraints = $table->get_constraints;
  for my $c (@constraints) {
    my $constr = create_constraint($c, $options);
    push @constraint_defs, $constr if ($constr);

    unless ($indexed_fields{ ($c->fields())[0] }
      || $c->type ne FOREIGN_KEY) {
      push @index_defs, "INDEX (" . $generator->quote(($c->fields())[0]) . ")";
      $indexed_fields{ ($c->fields())[0] } = 1;
    }
  }

  $create .= join(",\n", map {"  $_"} @field_defs, @index_defs, @constraint_defs);

  #
  # Footer
  #
  $create .= "\n)";
  $create .= generate_table_options($table, $options) || '';

  #    $create .= ";\n\n";

  return $drop ? ($drop, $create) : $create;
}

sub generate_table_options {
  my ($table, $options) = @_;
  my $create;

  my $table_type_defined = 0;
  my $generator          = _generator($options);
  my $charset            = $table->extra('mysql_charset');
  my $collate            = $table->extra('mysql_collate');
  my $union              = undef;
  for my $t1_option_ref ($table->options) {
    my ($key, $value) = %{$t1_option_ref};
    $table_type_defined = 1
        if uc $key eq 'ENGINE'
        or uc $key eq 'TYPE';
    if (uc $key eq 'CHARACTER SET') {
      $charset = $value;
      next;
    } elsif (uc $key eq 'COLLATE') {
      $collate = $value;
      next;
    } elsif (uc $key eq 'UNION') {
      $union = '(' . join(', ', map { $generator->quote($_) } @$value) . ')';
      next;
    }
    $create .= " $key=$value";
  }

  my $mysql_table_type = $table->extra('mysql_table_type');
  $create .= " ENGINE=$mysql_table_type"
      if $mysql_table_type && !$table_type_defined;
  my $comments = $table->comments;

  $create .= " DEFAULT CHARACTER SET $charset" if $charset;
  $create .= " COLLATE $collate"               if $collate;
  $create .= " UNION=$union"                   if $union;
  $create .= qq[ comment='$comments']          if $comments;
  return $create;
}

sub create_field {
  my ($field, $options) = @_;

  my $generator = _generator($options);

  my $field_name = $field->name;
  debug("PKG: Looking at field '$field_name'\n");
  my $field_def = $generator->quote($field_name);

  # data type and size
  my $data_type = $field->data_type;
  my @size      = $field->size;
  my %extra     = $field->extra;
  my $list      = $extra{'list'} || [];
  my $commalist = join(', ', map { __PACKAGE__->_quote_string($_) } @$list);
  my $charset   = $extra{'mysql_charset'};
  my $collate   = $extra{'mysql_collate'};

  my $mysql_version = $options->{mysql_version} || 0;
  #
  # Oracle "number" type -- figure best MySQL type
  #
  if (lc $data_type eq 'number') {

    # not an integer
    if (scalar @size > 1) {
      $data_type = 'double';
    } elsif ($size[0] && $size[0] >= 12) {
      $data_type = 'bigint';
    } elsif ($size[0] && $size[0] <= 1) {
      $data_type = 'tinyint';
    } else {
      $data_type = 'int';
    }
  }
  #
  # Convert a large Oracle varchar to "text"
  # (not necessary as of 5.0.3 http://dev.mysql.com/doc/refman/5.0/en/char.html)
  #
  elsif ($data_type =~ /char/i && $size[0] > 255) {
    unless ($size[0] <= 65535 && $mysql_version >= 5.000003) {
      $data_type = 'text';
      @size      = ();
    }
  } elsif ($data_type =~ /boolean/i) {
    if ($mysql_version >= 4) {
      $data_type = 'boolean';
    } else {
      $data_type = 'enum';
      $commalist = "'0','1'";
    }
  } elsif (exists $translate{ lc $data_type }) {
    $data_type = $translate{ lc $data_type };
  }

  @size = () if $data_type =~ /(text|blob)/i;

  if ($data_type =~ /(double|float)/ && scalar @size == 1) {
    push @size, '0';
  }

  $field_def .= " $data_type";

  if (lc($data_type) eq 'enum' || lc($data_type) eq 'set') {
    $field_def .= '(' . $commalist . ')';
  } elsif (defined $size[0] && $size[0] > 0 && !grep lc($data_type) eq $_, @no_length_attr) {
    $field_def .= '(' . join(', ', @size) . ')';
  }

  # char sets
  $field_def .= " CHARACTER SET $charset" if $charset;
  $field_def .= " COLLATE $collate"       if $collate;

  # MySQL qualifiers
  for my $qual (qw[ binary unsigned zerofill ]) {
    my $val = $extra{$qual} || $extra{ uc $qual } or next;
    $field_def .= " $qual";
  }
  for my $qual ('character set', 'collate', 'on update') {
    my $val = $extra{$qual} || $extra{ uc $qual } or next;
    if (ref $val) {
      $field_def .= " $qual ${$val}";
    } else {
      $field_def .= " $qual $val";
    }
  }

  # Null?
  if ($field->is_nullable) {
    $field_def .= ' NULL';
  } else {
    $field_def .= ' NOT NULL';
  }

  # Default?
  __PACKAGE__->_apply_default_value(
    $field,
    \$field_def,
    [
      'NULL' => \'NULL',
    ],
  );

  if (my $comments = $field->comments) {
    $comments = __PACKAGE__->_quote_string($comments);
    $field_def .= qq[ comment $comments];
  }

  # auto_increment?
  $field_def .= " auto_increment" if $field->is_auto_increment;

  return $field_def;
}

sub _quote_string {
  my ($self, $string) = @_;

  $string =~ s/([\\'])/$1$1/g;
  return qq{'$string'};
}

sub alter_create_index {
  my ($index, $options) = @_;

  my $table_name = _generator($options)->quote($index->table->name);
  return join(' ', 'ALTER TABLE', $table_name, 'ADD', create_index(@_));
}

sub create_index {
  my ($index, $options) = @_;
  my $generator = _generator($options);

  my @fields;
  for my $field ($index->fields) {
    my $name = $generator->quote($field->name);
    if (my $len = $field->extra->{prefix_length}) {
      $name .= "($len)";
    }
    push @fields, $name;

  }
  return join(' ',
    map { $_ || () } lc $index->type eq 'normal' ? 'INDEX' : $index->type . ' INDEX',
    $index->name
    ? $generator->quote(truncate_id_uniquely($index->name, $options->{max_id_length} || $DEFAULT_MAX_ID_LENGTH))
    : '',
    '(' . join(', ', @fields) . ')');
}

sub alter_drop_index {
  my ($index, $options) = @_;

  my $table_name = _generator($options)->quote($index->table->name);

  return join(' ', 'ALTER TABLE', $table_name, 'DROP', 'INDEX', $index->name || $index->fields);

}

sub alter_drop_constraint {
  my ($c, $options) = @_;

  my $generator  = _generator($options);
  my $table_name = $generator->quote($c->table->name);

  my @out = ('ALTER', 'TABLE', $table_name, 'DROP');
  if ($c->type eq PRIMARY_KEY) {
    push @out, $c->type;
  } else {
    push @out, ($c->type eq FOREIGN_KEY ? $c->type : "CONSTRAINT"), $generator->quote($c->name);
  }
  return join(' ', @out);
}

sub alter_create_constraint {
  my ($index, $options) = @_;

  my $table_name = _generator($options)->quote($index->table->name);
  return join(' ', 'ALTER TABLE', $table_name, 'ADD', create_constraint(@_));
}

sub create_constraint {
  my ($c, $options) = @_;

  my $generator  = _generator($options);
  my $leave_name = $options->{leave_name} || undef;

  my $reference_table_name = $generator->quote($c->reference_table);

  my @fields = $c->fields;

  if ($c->type eq PRIMARY_KEY) {
    return unless @fields;
    return 'PRIMARY KEY (' . join(", ", map { $generator->quote($_) } @fields) . ')';
  } elsif ($c->type eq UNIQUE) {
    return unless @fields;
    return sprintf 'UNIQUE %s(%s)',
        (
          (defined $c->name && $c->name)
          ? $generator->quote(truncate_id_uniquely($c->name, $options->{max_id_length} || $DEFAULT_MAX_ID_LENGTH),)
          . ' '
          : ''
        ),
        (join ', ', map { $generator->quote($_) } @fields),
        ;
  } elsif ($c->type eq FOREIGN_KEY) {
    return unless @fields;
    #
    # Make sure FK field is indexed or MySQL complains.
    #

    my $table  = $c->table;
    my $c_name = truncate_id_uniquely($c->name, $options->{max_id_length} || $DEFAULT_MAX_ID_LENGTH);

    my $def = join(' ', 'CONSTRAINT', ($c_name ? $generator->quote($c_name) : ()), 'FOREIGN KEY');

    $def .= ' (' . join(', ', map { $generator->quote($_) } @fields) . ')';

    $def .= ' REFERENCES ' . $reference_table_name;

    my @rfields = map { $_ || () } $c->reference_fields;
    unless (@rfields) {
      my $rtable_name = $c->reference_table;
      if (my $ref_table = $table->schema->get_table($rtable_name)) {
        push @rfields, $ref_table->primary_key;
      } else {
        warn "Can't find reference table '$rtable_name' " . "in schema\n"
            if $options->{show_warnings};
      }
    }

    if (@rfields) {
      $def .= ' (' . join(', ', map { $generator->quote($_) } @rfields) . ')';
    } else {
      warn "FK constraint on " . $table->name . '.' . join('', @fields) . " has no reference fields\n"
          if $options->{show_warnings};
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
    return $def;
  } elsif ($c->type eq CHECK_C) {
    my $table  = $c->table;
    my $c_name = truncate_id_uniquely($c->name, $options->{max_id_length} || $DEFAULT_MAX_ID_LENGTH);

    my $def = join(' ', 'CONSTRAINT', ($c_name ? $generator->quote($c_name) : ()), 'CHECK');

    $def .= ' (' . $c->expression . ')';
    return $def;
  }

  return undef;
}

sub alter_table {
  my ($to_table, $options) = @_;

  my $table_options = generate_table_options($to_table, $options) || '';
  my $table_name    = _generator($options)->quote($to_table->name);
  my $out           = sprintf('ALTER TABLE %s%s', $table_name, $table_options);

  return $out;
}

sub rename_field { alter_field(@_) }

sub alter_field {
  my ($from_field, $to_field, $options) = @_;

  my $generator  = _generator($options);
  my $table_name = $generator->quote($to_field->table->name);

  my $out = sprintf(
    'ALTER TABLE %s CHANGE COLUMN %s %s',
    $table_name,
    $generator->quote($from_field->name),
    create_field($to_field, $options)
  );

  return $out;
}

sub add_field {
  my ($new_field, $options) = @_;

  my $table_name = _generator($options)->quote($new_field->table->name);

  my $out = sprintf('ALTER TABLE %s ADD COLUMN %s', $table_name, create_field($new_field, $options));

  return $out;

}

sub drop_field {
  my ($old_field, $options) = @_;

  my $generator  = _generator($options);
  my $table_name = $generator->quote($old_field->table->name);

  my $out = sprintf('ALTER TABLE %s DROP COLUMN %s', $table_name, $generator->quote($old_field->name));

  return $out;

}

sub batch_alter_table {
  my ($table, $diff_hash, $options) = @_;

  # InnoDB has an issue with dropping and re-adding a FK constraint under the
  # name in a single alter statement, see: http://bugs.mysql.com/bug.php?id=13741
  #
  # We have to work round this.

  my %fks_to_alter;
  my %fks_to_drop = map { $_->type eq FOREIGN_KEY ? ($_->name => $_) : () } @{ $diff_hash->{alter_drop_constraint} };

  my %fks_to_create = map {
    if ($_->type eq FOREIGN_KEY) {
      $fks_to_alter{ $_->name } = $fks_to_drop{ $_->name }
          if $fks_to_drop{ $_->name };
      ($_->name => $_);
    } else {
      ()
    }
  } @{ $diff_hash->{alter_create_constraint} };

  my @drop_stmt;
  if (scalar keys %fks_to_alter) {
    $diff_hash->{alter_drop_constraint}
        = [ grep { !$fks_to_alter{ $_->name } } @{ $diff_hash->{alter_drop_constraint} } ];

    @drop_stmt = batch_alter_table($table, { alter_drop_constraint => [ values %fks_to_alter ] }, $options);

  }

  my @stmts = batch_alter_table_statements($diff_hash, $options);

  #quote
  my $generator = _generator($options);

  # rename_table makes things a bit more complex
  my $renamed_from = "";
  $renamed_from = $generator->quote($diff_hash->{rename_table}[0][0]->name)
      if $diff_hash->{rename_table} && @{ $diff_hash->{rename_table} };

  return unless @stmts;

  # Just zero or one stmts. return now
  return (@drop_stmt, @stmts) unless @stmts > 1;

  # Now strip off the 'ALTER TABLE xyz' of all but the first one

  my $table_name = $generator->quote($table->name);

  my $re
      = $renamed_from
      ? qr/^ALTER TABLE (?:\Q$table_name\E|\Q$renamed_from\E) /
      : qr/^ALTER TABLE \Q$table_name\E /;

  my $first = shift @stmts;
  my ($alter_table) = $first =~ /($re)/;

  my $padd = " " x length($alter_table);

  return @drop_stmt, join(",\n", $first, map { s/$re//; $padd . $_ } @stmts);

}

sub drop_table {
  my ($table, $options) = @_;

  return (
    # Drop (foreign key) constraints so table drops cleanly
    batch_alter_table(
      $table,
      {
        alter_drop_constraint => [ grep { $_->type eq 'FOREIGN KEY' } $table->get_constraints ]
      },
      $options
    ),
    'DROP TABLE ' . _generator($options)->quote($table),
  );
}

sub rename_table {
  my ($old_table, $new_table, $options) = @_;

  my $generator      = _generator($options);
  my $old_table_name = $generator->quote($old_table);
  my $new_table_name = $generator->quote($new_table);

  return "ALTER TABLE $old_table_name RENAME TO $new_table_name";
}

sub next_unused_name {
  my $name = shift || '';
  if (!defined($used_names{$name})) {
    $used_names{$name} = $name;
    return $name;
  }

  my $i = 1;
  while (defined($used_names{ $name . '_' . $i })) {
    ++$i;
  }
  $name .= '_' . $i;
  $used_names{$name} = $name;
  return $name;
}

1;

=pod

=head1 SEE ALSO

SQL::Translator, http://www.mysql.com/.

=head1 AUTHORS

darren chamberlain E<lt>darren@cpan.orgE<gt>,
Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut
