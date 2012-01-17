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
use SQL::Translator::Utils qw(debug header_comment parse_dbms_version);
use SQL::Translator::ProducerUtils;
my $util = SQL::Translator::ProducerUtils->new( quote_chars => q(') );

our ( $DEBUG, $WARN );
our $VERSION = '1.59';
$DEBUG = 0 unless defined $DEBUG;
$WARN = 0 unless defined $WARN;

our $max_id_length    = 30;
my %global_names;

sub produce {
    my $translator     = shift;
    local $DEBUG       = $translator->debug;
    local $WARN        = $translator->show_warnings;
    my $no_comments    = $translator->no_comments;
    my $add_drop_table = $translator->add_drop_table;
    my $schema         = $translator->schema;
    my $producer_args  = $translator->producer_args;
    my $sqlite_version = parse_dbms_version(
        $producer_args->{sqlite_version}, 'perl'
    );
    my $no_txn         = $producer_args->{no_transaction};

    debug("PKG: Beginning production\n");

    %global_names = ();   #reset


    my $head = (header_comment() . "\n") unless $no_comments;

    my @create = ();

    push @create, "BEGIN TRANSACTION" unless $no_txn;

    for my $table ( $schema->get_tables ) {
        push @create, create_table($table, { no_comments => $no_comments,
                                             sqlite_version => $sqlite_version,
                                          add_drop_table => $add_drop_table,});
    }

    for my $view ( $schema->get_views ) {
      push @create, create_view($view, {
        add_drop_view => $add_drop_table,
        no_comments   => $no_comments,
      });
    }

    for my $trigger ( $schema->get_triggers ) {
      push @create, create_trigger($trigger, {
        add_drop_trigger => $add_drop_table,
        no_comments   => $no_comments,
      });
    }

    push @create, "COMMIT" unless $no_txn;

    if (wantarray) {
      return ($head||(), @create);
    } else {
      return join ('',
        $head||(),
        join(";\n\n", @create ),
        ";\n",
      );
    }
}

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

    $scope->{ $name }++;
    return $util->quote($name);
}

sub create_view {
    my ($view, $options) = @_;
    my $add_drop_view = $options->{add_drop_view};

    my $view_name = $util->quote($view->name);
    $global_names{$view->name} = 1;

    debug("PKG: Looking at view '${view_name}'\n");

    # Header.  Should this look like what mysqldump produces?
    my $extra = $view->extra;
    my @create;
    push @create, "DROP VIEW IF EXISTS $view_name" if $add_drop_view;

    my $create_view = 'CREATE';
    $create_view .= " TEMPORARY" if exists($extra->{temporary}) && $extra->{temporary};
    $create_view .= ' VIEW';
    $create_view .= " IF NOT EXISTS" if exists($extra->{if_not_exists}) && $extra->{if_not_exists};
    $create_view .= " ${view_name}";

    if( my $sql = $view->sql ){
      $create_view .= " AS\n    ${sql}";
    }
    push @create, $create_view;

    # Tack the comment onto the first statement.
    unless ($options->{no_comments}) {
      $create[0] = "--\n-- View: ${view_name}\n--\n" . $create[0];
    }

    return @create;
}


sub create_table
{
    my ($table, $options) = @_;

    my $table_name = $util->quote($table->name);
    $global_names{$table->name} = 1;

    my $no_comments = $options->{no_comments};
    my $add_drop_table = $options->{add_drop_table};
    my $sqlite_version = $options->{sqlite_version} || 0;

    debug("PKG: Looking at table '$table_name'\n");

    my ( @index_defs, @constraint_defs );
    my @fields = $table->get_fields or die "No fields in $table_name";

    my $temp = $options->{temporary_table} ? 'TEMPORARY ' : '';
    #
    # Header.
    #
    my $exists = ($sqlite_version >= 3.003) ? ' IF EXISTS' : '';
    my @create;
    my ($comment, $create_table) = "";
    $comment =  "--\n-- Table: $table_name\n--\n" unless $no_comments;
    if ($add_drop_table) {
      push @create, $comment . qq[DROP TABLE$exists $table_name];
    } else {
      $create_table = $comment;
    }

    $create_table .= "CREATE ${temp}TABLE $table_name (\n";

    #
    # Comments
    #
    if ( $table->comments and !$no_comments ){
        $create_table .= "-- Comments: \n-- ";
        $create_table .= join "\n-- ",  $table->comments;
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
    my ( @field_defs, $pk_set );
    for my $field ( @fields ) {
        push @field_defs, create_field($field);
    }

    if (
         scalar @pk_fields > 1
         ||
         ( @pk_fields && !grep /INTEGER PRIMARY KEY/, @field_defs )
         ) {
        push @field_defs, 'PRIMARY KEY (' . join(', ', map $util->quote($_), @pk_fields ) . ')';
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
        if ($c->type eq "FOREIGN KEY") {
            push @field_defs, create_foreignkey($c);
        }
        next unless $c->type eq UNIQUE;
        push @constraint_defs, create_constraint($c);
    }

    $create_table .= join(",\n", map { "  $_" } @field_defs ) . "\n)";

    return (@create, $create_table, @index_defs, @constraint_defs );
}

sub create_foreignkey {
    my $c = shift;

    my @fields = $c->fields;
    my @rfields = map { $_ || () } $c->reference_fields;
    unless ( @rfields ) {
        my $rtable_name = $c->reference_table;
        if ( my $ref_table = $c->schema->get_table( $rtable_name ) ) {
            push @rfields, $ref_table->primary_key;

            die "FK constraint on " . $rtable_name . '.' . join('', @fields) . " has no reference fields\n"
              unless @rfields;
        }
        else {
            die "Can't find reference table '$rtable_name' in schema\n";
        }
    }

    my $fk_sql = sprintf 'FOREIGN KEY (%s) REFERENCES %s(%s)',
        join (', ', map { $util->quote($_) } @fields ),
        $util->quote($c->reference_table),
        join (', ', map { $util->quote($_) } @rfields )
    ;

    $fk_sql .= " ON DELETE " . $c->{on_delete} if $c->{on_delete};
    $fk_sql .= " ON UPDATE " . $c->{on_update} if $c->{on_update};

    return $fk_sql;
}

sub create_field
{
    my ($field, $options) = @_;

    my $field_name = $util->quote($field->name);
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

    # Default?
    SQL::Translator::Producer->_apply_default_value(
        $field,
        \$field_def,
        [
         'NULL'              => \'NULL',
         'now()'             => 'now()',
         'CURRENT_TIMESTAMP' => 'CURRENT_TIMESTAMP',
        ],
    );

    return $field_def;

}

sub create_index
{
    my ($index, $options) = @_;

    my $name   = $index->name;
    $name      = mk_name($name);

    my $type   = $index->type eq 'UNIQUE' ? "UNIQUE " : '';

    # strip any field size qualifiers as SQLite doesn't like these
    my @fields = map { s/\(\d+\)$//; $util->quote($_) } $index->fields;
    (my $index_table_name = $index->table->name) =~ s/^.+?\.//; # table name may not specify schema
    $index_table_name = $util->quote($index_table_name);
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
    $name      = mk_name($name);
    my @fields = map $util->quote($_), $c->fields;
    (my $index_table_name = $c->table->name) =~ s/^.+?\.//; # table name may not specify schema
    $index_table_name = $util->quote($index_table_name);
    warn "removing schema name from '" . $c->table->name . "' to make '$index_table_name'\n" if $WARN;

    my $c_def =
    "CREATE UNIQUE INDEX $name ON " . $index_table_name .
        ' (' . join( ', ', @fields ) . ')';

    return $c_def;
}

sub create_trigger {
  my ($trigger, $options) = @_;
  my $add_drop = $options->{add_drop_trigger};

  my @statements;

  my $trigger_name = $trigger->name;
  $global_names{$trigger_name} = 1;

  my $events = $trigger->database_events;
  for my $evt ( @$events ) {

    my $trig_name = $trigger_name;
    if (@$events > 1) {
      $trig_name .= "_$evt";

      warn "Multiple database events supplied for trigger '$trigger_name', ",
        "creating trigger '$trig_name' for the '$evt' event.\n" if $WARN;
    }

    $trig_name = $util->quote($trig_name);
    push @statements,  "DROP TRIGGER IF EXISTS $trig_name" if $add_drop;


    $DB::single = 1;
    my $action = "";
    if (not ref $trigger->action) {
      $action .= "BEGIN " . $trigger->action . " END";
    }
    else {
      $action = $trigger->action->{for_each} . " "
        if $trigger->action->{for_each};

      $action = $trigger->action->{when} . " "
        if $trigger->action->{when};

      my $steps = $trigger->action->{steps} || [];

      $action .= "BEGIN ";
      $action .= $_ . "; " for (@$steps);
      $action .= "END";
    }

    push @statements, sprintf (
      'CREATE TRIGGER %s %s %s on %s %s',
      $trig_name,
      $trigger->perform_action_when,
      $evt,
      $util->quote($trigger->on_table),
      $action
    );
  }

  return @statements;
}

sub alter_table { } # Noop

sub add_field {
  my ($field) = @_;

  return sprintf("ALTER TABLE %s ADD COLUMN %s",
      $util->quote($field->table->name), create_field($field))
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

  return sprintf("DROP INDEX %s",
      $util->quote($constraint->name));
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
#    return join("\n", map {
    return map {
        my $meth = __PACKAGE__->can($_) or die __PACKAGE__ . " cant $_";
        map { my $sql = $meth->(ref $_ eq 'ARRAY' ? @$_ : $_); $sql ?  ("$sql") : () } @{ $diffs->{$_} }

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
       alter_table/;
  }


  my @sql;
  my $old_table = $renaming ? $diffs->{rename_table}[0][0] : $table;

  do {
    local $table->{name} = $table_name . '_temp_alter';
    # We only want the table - dont care about indexes on tmp table
    my ($table_sql) = create_table($table, {no_comments => 1, temporary_table => 1});
    push @sql,$table_sql;
  };

  push @sql, "INSERT INTO @{[$util->quote($table_name.'_temp_alter')]} SELECT @{[ join(', ', map $util->quote($_), $old_table->get_fields)]} FROM @{[$util->quote($old_table)]}",
             "DROP TABLE @{[$util->quote($old_table)]}",
             create_table($table, { no_comments => 1 }),
             "INSERT INTO @{[$util->quote($table_name)]} SELECT @{[ join(', ', map $util->quote($_), $old_table->get_fields)]} FROM @{[$util->quote($table_name.'_temp_alter')]}",
             "DROP TABLE @{[$util->quote($table_name.'_temp_alter')]}";

  return @sql;
#  return join("", @sql, "");
}

sub drop_table {
  my ($table) = @_;
  $table = $util->quote($table);
  return "DROP TABLE $table";
}

sub rename_table {
  my ($old_table, $new_table, $options) = @_;

  $old_table = $util->quote($old_table);
  $new_table = $util->quote($new_table);

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
