package SQL::Translator::Producer::SQLite;

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
use warnings;
use Data::Dumper;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(debug header_comment parse_dbms_version batch_alter_table_statements);
use SQL::Translator::Generator::DDL::SQLite;

our ($DEBUG, $WARN);
our $VERSION = '1.66';
$DEBUG = 0 unless defined $DEBUG;
$WARN  = 0 unless defined $WARN;

our $max_id_length = 30;
my %global_names;

# HIDEOUS TEMPORARY DEFAULT WITHOUT QUOTING!
our $NO_QUOTES = 1;
{

  my ($quoting_generator, $nonquoting_generator);

  sub _generator {
    $NO_QUOTES
        ? $nonquoting_generator ||= SQL::Translator::Generator::DDL::SQLite->new(quote_chars => [])
        : $quoting_generator ||= SQL::Translator::Generator::DDL::SQLite->new;
  }
}

sub produce {
  my $translator = shift;
  local $DEBUG = $translator->debug;
  local $WARN  = $translator->show_warnings;
  my $no_comments    = $translator->no_comments;
  my $add_drop_table = $translator->add_drop_table;
  my $schema         = $translator->schema;
  my $producer_args  = $translator->producer_args;
  my $sqlite_version = parse_dbms_version($producer_args->{sqlite_version}, 'perl');
  my $no_txn         = $producer_args->{no_transaction};

  debug("PKG: Beginning production\n");

  %global_names = ();    #reset

  # only quote if quotes were requested for real
  # 0E0 indicates "the default of true" was assumed
  local $NO_QUOTES = 0
      if $translator->quote_identifiers
      and $translator->quote_identifiers ne '0E0';

  my $head;
  $head = (header_comment() . "\n") unless $no_comments;

  my @create = ();

  push @create, "BEGIN TRANSACTION" unless $no_txn;

  for my $table ($schema->get_tables) {
    push @create,
        create_table(
          $table,
          {
            no_comments    => $no_comments,
            sqlite_version => $sqlite_version,
            add_drop_table => $add_drop_table,
          }
        );
  }

  for my $view ($schema->get_views) {
    push @create,
        create_view(
          $view,
          {
            add_drop_view => $add_drop_table,
            no_comments   => $no_comments,
          }
        );
  }

  for my $trigger ($schema->get_triggers) {
    push @create,
        create_trigger(
          $trigger,
          {
            add_drop_trigger => $add_drop_table,
            no_comments      => $no_comments,
          }
        );
  }

  push @create, "COMMIT" unless $no_txn;

  if (wantarray) {
    return ($head || (), @create);
  } else {
    return join('', $head || (), join(";\n\n", @create), ";\n",);
  }
}

sub mk_name {
  my ($name, $scope, $critical) = @_;

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

  $scope->{$name}++;
  return _generator()->quote($name);
}

sub create_view {
  my ($view, $options) = @_;
  my $add_drop_view = $options->{add_drop_view};

  my $view_name = _generator()->quote($view->name);
  $global_names{ $view->name } = 1;

  debug("PKG: Looking at view '${view_name}'\n");

  # Header.  Should this look like what mysqldump produces?
  my $extra = $view->extra;
  my @create;
  push @create, "DROP VIEW IF EXISTS $view_name" if $add_drop_view;

  my $create_view = 'CREATE';
  $create_view .= " TEMPORARY"
      if exists($extra->{temporary}) && $extra->{temporary};
  $create_view .= ' VIEW';
  $create_view .= " IF NOT EXISTS"
      if exists($extra->{if_not_exists}) && $extra->{if_not_exists};
  $create_view .= " ${view_name}";

  if (my $sql = $view->sql) {
    $create_view .= " AS\n    ${sql}";
  }
  push @create, $create_view;

  # Tack the comment onto the first statement.
  unless ($options->{no_comments}) {
    $create[0] = "--\n-- View: ${view_name}\n--\n" . $create[0];
  }

  return @create;
}

sub create_table {
  my ($table, $options) = @_;

  my $table_name = _generator()->quote($table->name);
  $global_names{ $table->name } = 1;

  my $no_comments    = $options->{no_comments};
  my $add_drop_table = $options->{add_drop_table};
  my $sqlite_version = $options->{sqlite_version} || 0;

  debug("PKG: Looking at table '$table_name'\n");

  my (@index_defs, @constraint_defs);
  my @fields = $table->get_fields or die "No fields in $table_name";

  my $temp = $options->{temporary_table} ? 'TEMPORARY ' : '';
  #
  # Header.
  #
  my $exists = ($sqlite_version >= 3.003) ? ' IF EXISTS' : '';
  my @create;
  my ($comment, $create_table) = "";
  $comment = "--\n-- Table: $table_name\n--\n" unless $no_comments;
  if ($add_drop_table) {
    push @create, $comment . qq[DROP TABLE$exists $table_name];
  } else {
    $create_table = $comment;
  }

  $create_table .= "CREATE ${temp}TABLE $table_name (\n";

  #
  # Comments
  #
  if ($table->comments and !$no_comments) {
    $create_table .= "-- Comments: \n-- ";
    $create_table .= join "\n-- ", $table->comments;
    $create_table .= "\n--\n\n";
  }

  #
  # How many fields in PK?
  #
  my $pk        = $table->primary_key;
  my @pk_fields = $pk ? $pk->fields : ();

  #
  # Fields
  #
  my (@field_defs, $pk_set);
  for my $field (@fields) {
    push @field_defs, create_field($field);
  }

  if (scalar @pk_fields > 1
    || (@pk_fields && !grep /INTEGER PRIMARY KEY/, @field_defs)) {
    push @field_defs, 'PRIMARY KEY (' . join(', ', map _generator()->quote($_), @pk_fields) . ')';
  }

  #
  # Indices
  #
  for my $index ($table->get_indices) {
    push @index_defs, create_index($index);
  }

  #
  # Constraints
  #
  for my $c ($table->get_constraints) {
    if ($c->type eq "FOREIGN KEY") {
      push @field_defs, create_foreignkey($c);
    } elsif ($c->type eq "CHECK") {
      push @field_defs, create_check_constraint($c);
    }
    next unless $c->type eq UNIQUE;
    push @constraint_defs, create_constraint($c);
  }

  $create_table .= join(",\n", map {"  $_"} @field_defs) . "\n)";

  return (@create, $create_table, @index_defs, @constraint_defs);
}

sub create_check_constraint {
  my $c     = shift;
  my $check = '';
  $check .= 'CONSTRAINT ' . _generator->quote($c->name) . ' ' if $c->name;
  $check .= 'CHECK(' . $c->expression . ')';
  return $check;
}

sub create_foreignkey {
  my $c = shift;

  my @fields  = $c->fields;
  my @rfields = map { $_ || () } $c->reference_fields;
  unless (@rfields) {
    my $rtable_name = $c->reference_table;
    if (my $ref_table = $c->schema->get_table($rtable_name)) {
      push @rfields, $ref_table->primary_key;

      die "FK constraint on " . $rtable_name . '.' . join('', @fields) . " has no reference fields\n"
          unless @rfields;
    } else {
      die "Can't find reference table '$rtable_name' in schema\n";
    }
  }

  my $fk_sql = sprintf 'FOREIGN KEY (%s) REFERENCES %s(%s)',
      join(', ', map { _generator()->quote($_) } @fields),
      _generator()->quote($c->reference_table),
      join(', ', map { _generator()->quote($_) } @rfields);

  $fk_sql .= " ON DELETE " . $c->{on_delete} if $c->{on_delete};
  $fk_sql .= " ON UPDATE " . $c->{on_update} if $c->{on_update};

  return $fk_sql;
}

sub create_field { return _generator()->field($_[0]) }

sub create_index {
  my ($index, $options) = @_;

  (my $index_table_name = $index->table->name) =~ s/^.+?\.//;    # table name may not specify schema
  my $name = mk_name($index->name || "${index_table_name}_idx");

  my $type = $index->type eq 'UNIQUE' ? "UNIQUE " : '';

  # strip any field size qualifiers as SQLite doesn't like these
  my @fields = map { s/\(\d+\)$//; _generator()->quote($_) } $index->fields;
  $index_table_name = _generator()->quote($index_table_name);
  warn "removing schema name from '" . $index->table->name . "' to make '$index_table_name'\n"
      if $WARN;
  my $index_def = "CREATE ${type}INDEX $name ON " . $index_table_name . ' (' . join(', ', @fields) . ')';

  return $index_def;
}

sub create_constraint {
  my ($c, $options) = @_;

  (my $index_table_name = $c->table->name) =~ s/^.+?\.//;    # table name may not specify schema
  my $name   = mk_name($c->name || "${index_table_name}_idx");
  my @fields = map _generator()->quote($_), $c->fields;
  $index_table_name = _generator()->quote($index_table_name);
  warn "removing schema name from '" . $c->table->name . "' to make '$index_table_name'\n"
      if $WARN;

  my $c_def = "CREATE UNIQUE INDEX $name ON " . $index_table_name . ' (' . join(', ', @fields) . ')';

  return $c_def;
}

sub create_trigger {
  my ($trigger, $options) = @_;
  my $add_drop = $options->{add_drop_trigger};

  my @statements;

  my $trigger_name = $trigger->name;
  $global_names{$trigger_name} = 1;

  my $events = $trigger->database_events;
  for my $evt (@$events) {

    my $trig_name = $trigger_name;
    if (@$events > 1) {
      $trig_name .= "_$evt";

      warn
          "Multiple database events supplied for trigger '$trigger_name', ",
          "creating trigger '$trig_name' for the '$evt' event.\n"
          if $WARN;
    }

    $trig_name = _generator()->quote($trig_name);
    push @statements, "DROP TRIGGER IF EXISTS $trig_name" if $add_drop;

    $DB::single = 1;
    my $action = "";
    if (not ref $trigger->action) {
      $action = $trigger->action;
      $action = "BEGIN " . $action . " END"
          unless $action =~ /^ \s* BEGIN [\s\;] .*? [\s\;] END [\s\;]* $/six;
    } else {
      $action = $trigger->action->{for_each} . " "
          if $trigger->action->{for_each};

      $action = $trigger->action->{when} . " "
          if $trigger->action->{when};

      my $steps = $trigger->action->{steps} || [];

      $action .= "BEGIN ";
      $action .= $_ . "; " for (@$steps);
      $action .= "END";
    }

    push @statements,
        sprintf(
          'CREATE TRIGGER %s %s %s on %s %s',
          $trig_name, $trigger->perform_action_when,
          $evt, _generator()->quote($trigger->on_table), $action
        );
  }

  return @statements;
}

sub alter_table { () }    # Noop

sub add_field {
  my ($field) = @_;

  return sprintf("ALTER TABLE %s ADD COLUMN %s", _generator()->quote($field->table->name), create_field($field));
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

  return sprintf("DROP INDEX %s", _generator()->quote($constraint->name));
}

sub batch_alter_table {
  my ($table, $diffs, $options) = @_;

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
  #
  # We create the temporary table as a copy of the new table, copy all data
  # to temp table, create new table and then copy as appropriate taking note
  # of renamed fields.

  my $table_name = $table->name;

  if ( @{ $diffs->{rename_field} } == 0
    && @{ $diffs->{alter_field} } == 0
    && @{ $diffs->{drop_field} } == 0) {
    return batch_alter_table_statements($diffs, $options);
  }

  my @sql;

  # $table is the new table but we may need an old one
  # TODO: this is NOT very well tested at the moment so add more tests

  my $old_table = $table;

  if ($diffs->{rename_table} && @{ $diffs->{rename_table} }) {
    $old_table = $diffs->{rename_table}[0][0];
  }

  my $temp_table_name = $table_name . '_temp_alter';

  # CREATE TEMPORARY TABLE t1_backup(a,b);

  my %temp_table_fields;
  do {
    local $table->{name} = $temp_table_name;

    # We only want the table - don't care about indexes on tmp table
    my ($table_sql)
        = create_table($table, { no_comments => 1, temporary_table => 1 });
    push @sql, $table_sql;

    %temp_table_fields = map { $_ => 1 } $table->get_fields;
  };

  # record renamed fields for later
  my %rename_field = map { $_->[1]->name => $_->[0]->name } @{ $diffs->{rename_field} };

  # drop added fields from %temp_table_fields
  delete @temp_table_fields{ @{ $diffs->{add_field} } };

  # INSERT INTO t1_backup SELECT a,b FROM t1;

  push @sql, sprintf(
    'INSERT INTO %s( %s) SELECT %s FROM %s',

    _generator()->quote($temp_table_name),

    join(', ', map _generator()->quote($_), grep { $temp_table_fields{$_} } $table->get_fields),

    join(', ',
      map _generator()->quote($_),
      map      { $rename_field{$_} ? $rename_field{$_} : $_ }
          grep { $temp_table_fields{$_} } $table->get_fields),

    _generator()->quote($old_table->name)
  );

  # DROP TABLE t1;

  push @sql, sprintf('DROP TABLE %s', _generator()->quote($old_table->name));

  # CREATE TABLE t1(a,b);

  push @sql, create_table($table, { no_comments => 1 });

  # INSERT INTO t1 SELECT a,b FROM t1_backup;

  push @sql,
      sprintf(
        'INSERT INTO %s SELECT %s FROM %s',
        _generator()->quote($table_name),
        join(', ', map _generator()->quote($_), $table->get_fields),
        _generator()->quote($temp_table_name)
      );

  # DROP TABLE t1_backup;

  push @sql, sprintf('DROP TABLE %s', _generator()->quote($temp_table_name));

  return wantarray ? @sql : join(";\n", @sql);
}

sub drop_table {
  my ($table) = @_;
  $table = _generator()->quote($table);
  return "DROP TABLE $table";
}

sub rename_table {
  my ($old_table, $new_table, $options) = @_;

  $old_table = _generator()->quote($old_table);
  $new_table = _generator()->quote($new_table);

  return "ALTER TABLE $old_table RENAME TO $new_table";

}

# No-op. Just here to signify that we are a new style parser.
sub preproces_schema { }

1;

=pod

=head1 SEE ALSO

SQL::Translator, http://www.sqlite.org/.

=head1 AUTHOR

Ken Youens-Clark C<< <kclark@cpan.orgE> >>.

Diff code added by Ash Berlin C<< <ash@cpan.org> >>.

=cut
