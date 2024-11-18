package SQL::Translator::Producer::Oracle;

=head1 NAME

SQL::Translator::Producer::Oracle - Oracle SQL producer

=head1 SYNOPSIS

  use SQL::Translator;

  my $t = SQL::Translator->new( parser => '...', producer => 'Oracle' );
  print $translator->translate( $file );

=head1 DESCRIPTION

Creates an SQL DDL suitable for Oracle.

=head1 producer_args

=over

=item delay_constraints

This option remove the primary key and other key constraints from the
CREATE TABLE statement and adds ALTER TABLEs at the end with it.

=item quote_field_names

Controls whether quotes are being used around column names in generated DDL.

=item quote_table_names

Controls whether quotes are being used around table, sequence and trigger names in
generated DDL.

=back

=head1 NOTES

=head2 Autoincremental primary keys

This producer uses sequences and triggers to autoincrement primary key
columns, if necessary. SQLPlus and DBI expect a slightly different syntax
of CREATE TRIGGER statement. You might have noticed that this
producer returns a scalar containing all statements concatenated by
newlines or an array of single statements depending on the context
(scalar, array) it has been called in.

SQLPlus expects following trigger syntax:

    CREATE OR REPLACE TRIGGER ai_person_id
    BEFORE INSERT ON person
    FOR EACH ROW WHEN (
     new.id IS NULL OR new.id = 0
    )
    BEGIN
     SELECT sq_person_id.nextval
     INTO :new.id
     FROM dual;
    END;
    /

Whereas if you want to create the same trigger using L<DBI/do>, you need
to omit the last slash:

    my $dbh = DBI->connect('dbi:Oracle:mysid', 'scott', 'tiger');
    $dbh->do("
        CREATE OR REPLACE TRIGGER ai_person_id
        BEFORE INSERT ON person
        FOR EACH ROW WHEN (
         new.id IS NULL OR new.id = 0
        )
        BEGIN
         SELECT sq_person_id.nextval
         INTO :new.id
         FROM dual;
        END;
    ");

If you call this producer in array context, we expect you want to process
the returned array of statements using L<DBI> like
L<DBIx::Class::Schema/deploy> does.

To get this working we removed the slash in those statements in version
0.09002 of L<SQL::Translator> when called in array context. In scalar
context the slash will be still there to ensure compatibility with SQLPlus.

=cut

use strict;
use warnings;
our ($DEBUG, $WARN);
our $VERSION = '1.66';
$DEBUG = 0 unless defined $DEBUG;

use base 'SQL::Translator::Producer';
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(debug header_comment);
use Data::Dumper;

my %translate = (
  #
  # MySQL types
  #
  bigint     => 'number',
  double     => 'float',
  decimal    => 'number',
  float      => 'float',
  int        => 'number',
  integer    => 'number',
  mediumint  => 'number',
  smallint   => 'number',
  tinyint    => 'number',
  char       => 'char',
  varchar    => 'varchar2',
  tinyblob   => 'blob',
  blob       => 'blob',
  mediumblob => 'blob',
  longblob   => 'blob',
  tinytext   => 'varchar2',
  text       => 'clob',
  longtext   => 'clob',
  mediumtext => 'clob',
  enum       => 'varchar2',
  set        => 'varchar2',
  date       => 'date',
  datetime   => 'date',
  time       => 'date',
  timestamp  => 'date',
  year       => 'date',

  #
  # PostgreSQL types
  #
  numeric             => 'number',
  'double precision'  => 'number',
  serial              => 'number',
  bigserial           => 'number',
  money               => 'number',
  character           => 'char',
  'character varying' => 'varchar2',
  bytea               => 'BLOB',
  interval            => 'number',
  boolean             => 'number',
  point               => 'number',
  line                => 'number',
  lseg                => 'number',
  box                 => 'number',
  path                => 'number',
  polygon             => 'number',
  circle              => 'number',
  cidr                => 'number',
  inet                => 'varchar2',
  macaddr             => 'varchar2',
  bit                 => 'number',
  'bit varying'       => 'number',

  #
  # Oracle types
  #
  number   => 'number',
  varchar2 => 'varchar2',
  long     => 'clob',
);

#
# Oracle 8/9 max size of data types from:
# http://www.ss64.com/orasyntax/datatypes.html
#
my %max_size = (
  char      => 2000,
  float     => 126,
  nchar     => 2000,
  nvarchar2 => 4000,
  number    => [ 38, 127 ],
  raw       => 2000,
  varchar   => 4000,          # only synonym for varchar2
  varchar2  => 4000,
);

my $max_id_length    = 30;
my %used_identifiers = ();
my %global_names;
my %truncated;

# Quote used to escape table, field, sequence and trigger names
my $quote_char = '"';

sub produce {
  my $translator = shift;
  $DEBUG = $translator->debug;
  $WARN  = $translator->show_warnings || 0;
  my $no_comments       = $translator->no_comments;
  my $add_drop_table    = $translator->add_drop_table;
  my $schema            = $translator->schema;
  my $oracle_version    = $translator->producer_args->{oracle_version} || 0;
  my $delay_constraints = $translator->producer_args->{delay_constraints};
  my ($output, $create, @table_defs, @fk_defs, @trigger_defs, @index_defs, @constraint_defs);

  debug("ORA: Beginning production");
  $create .= header_comment unless ($no_comments);
  my $qt = 1 if $translator->quote_table_names;
  my $qf = 1 if $translator->quote_field_names;

  if ($translator->parser_type =~ /mysql/i) {
    $create
        .= "-- We assume that default NLS_DATE_FORMAT has been changed\n"
        . "-- but we set it here anyway to be self-consistent.\n"
        unless $no_comments;

    $create .= "ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';\n\n";
  }

  for my $table ($schema->get_tables) {
    debug("ORA: Producing for table " . $table->name);
    my ($table_def, $fk_def, $trigger_def, $index_def, $constraint_def) = create_table(
      $table,
      {
        add_drop_table    => $add_drop_table,
        show_warnings     => $WARN,
        no_comments       => $no_comments,
        delay_constraints => $delay_constraints,
        quote_table_names => $qt,
        quote_field_names => $qf,
      }
    );
    push @table_defs,      @$table_def;
    push @fk_defs,         @$fk_def;
    push @trigger_defs,    @$trigger_def;
    push @index_defs,      @$index_def;
    push @constraint_defs, @$constraint_def;
  }

  my (@view_defs);
  foreach my $view ($schema->get_views) {
    my ($view_def) = create_view(
      $view,
      {
        add_drop_view     => $add_drop_table,
        quote_table_names => $qt,
      }
    );
    push @view_defs, @$view_def;
  }

  if (wantarray) {
    return defined $create ? $create : (), @table_defs, @view_defs,
        @fk_defs, @trigger_defs, @index_defs, @constraint_defs;
  } else {
    $create .= join(";\n\n", @table_defs, @view_defs, @fk_defs, @index_defs, @constraint_defs);
    $create .= ";\n\n";

    # If wantarray is not set we have to add "/" in this statement
    # DBI->do() needs them omitted
    # triggers may NOT end with a semicolon but a "/" instead
    $create .= "$_/\n\n" for @trigger_defs;
    return $create;
  }
}

sub create_table {
  my ($table, $options) = @_;
  my $qt           = $options->{quote_table_names};
  my $qf           = $options->{quote_field_names};
  my $table_name   = $table->name;
  my $table_name_q = quote($table_name, $qt);

  my $item = '';
  my $drop;
  my (@create, @field_defs, @constraint_defs, @fk_defs, @trigger_defs);

  push @create, "--\n-- Table: $table_name\n--"
      unless $options->{no_comments};
  push @create, qq[DROP TABLE $table_name_q CASCADE CONSTRAINTS]
      if $options->{add_drop_table};

  my (%field_name_scope, @field_comments);
  for my $field ($table->get_fields) {
    debug("ORA: Creating field " . $field->name . "(" . $field->data_type . ")");
    my ($field_create, $field_defs, $trigger_defs, $field_comments)
        = create_field($field, $options, \%field_name_scope);
    push @create,         @$field_create   if ref $field_create;
    push @field_defs,     @$field_defs     if ref $field_defs;
    push @trigger_defs,   @$trigger_defs   if ref $trigger_defs;
    push @field_comments, @$field_comments if ref $field_comments;
  }

  #
  # Table options
  #
  my @table_options;
  for my $opt ($table->options) {
    if (ref $opt eq 'HASH') {
      my ($key, $value) = each %$opt;
      if (ref $value eq 'ARRAY') {
        push @table_options,
            "$key\n(\n"
            . join(
              "\n", map {"  $_->[0]\t$_->[1]"}
              map { [ each %$_ ] } @$value
            ) . "\n)";
      } elsif (!defined $value) {
        push @table_options, $key;
      } else {
        push @table_options, "$key    $value";
      }
    }
  }

  #
  # Table constraints
  #
  for my $c ($table->get_constraints) {
    my $constr = create_constraint($c, $options);
    if ($constr) {
      if ($c->type eq FOREIGN_KEY) {    # FK defs always come later as alters
        push @fk_defs, sprintf("ALTER TABLE %s ADD %s", $table_name_q, $constr);
      } else {
        push @constraint_defs, $constr;
      }
    }
  }

  #
  # Index Declarations
  #
  my @index_defs = ();
  for my $index ($table->get_indices) {
    my $index_name = $index->name || '';
    my $index_type = $index->type || NORMAL;
    my @fields     = map { quote($_, $qf) } $index->fields;
    next unless @fields;
    debug("ORA: Creating $index_type index on fields (" . join(', ', @fields) . ") named $index_name");
    my @index_options;
    for my $opt ($index->options) {
      if (ref $opt eq 'HASH') {
        my ($key, $value) = each %$opt;
        if (ref $value eq 'ARRAY') {
          push @table_options,
              "$key\n(\n"
              . join(
                "\n", map {"  $_->[0]\t$_->[1]"}
                map { [ each %$_ ] } @$value
              ) . "\n)";
        } elsif (!defined $value) {
          push @index_options, $key;
        } else {
          push @index_options, "$key    $value";
        }
      }
    }
    my $index_options = @index_options ? "\n" . join("\n", @index_options) : '';

    if ($index_type eq PRIMARY_KEY) {
      $index_name
          = $index_name
          ? mk_name($index_name)
          : mk_name($table_name, 'pk');
      $index_name = quote($index_name, $qf);
      push @field_defs, 'CONSTRAINT ' . $index_name . ' PRIMARY KEY ' . '(' . join(', ', @fields) . ')';
    } elsif ($index_type eq NORMAL or $index_type eq UNIQUE) {
      push @index_defs, create_index($index, $options, $index_options);
    } else {
      warn "Unknown index type ($index_type) on table $table_name.\n"
          if $WARN;
    }
  }

  if (my @table_comments = $table->comments) {
    for my $comment (@table_comments) {
      next unless $comment;
      $comment = __PACKAGE__->_quote_string($comment);
      push @field_comments, "COMMENT ON TABLE $table_name_q is\n $comment"
          unless $options->{no_comments};
    }
  }

  my $table_options = @table_options ? "\n" . join("\n", @table_options) : '';
  push @create,
        "CREATE TABLE $table_name_q (\n"
      . join(",\n", map {"  $_"} @field_defs, ($options->{delay_constraints} ? () : @constraint_defs))
      . "\n)$table_options";

  @constraint_defs = map {"ALTER TABLE $table_name_q ADD $_"} @constraint_defs;

  if ($WARN) {
    if (%truncated) {
      warn "Truncated " . keys(%truncated) . " names:\n";
      warn "\t" . join("\n\t", sort keys %truncated) . "\n";
    }
  }

  return \@create, \@fk_defs, \@trigger_defs, \@index_defs, ($options->{delay_constraints} ? \@constraint_defs : []);
}

sub alter_field {
  my ($from_field, $to_field, $options) = @_;

  my $qt = $options->{quote_table_names};
  my ($field_create, $field_defs, $trigger_defs, $field_comments)
      = create_field($to_field, $options, {});

  # Fix ORA-01442
  if (!$from_field->is_nullable && $to_field->is_nullable) {
    if ($from_field->data_type =~ /text/) {
      die 'Cannot alter CLOB field in this way';
    } else {
      @$field_defs = map { $_ .= ' NULL' } @$field_defs;
    }
  } elsif (!$from_field->is_nullable && !$to_field->is_nullable) {
    @$field_defs = map { s/ NOT NULL//; $_ } @$field_defs;
  }

  my $table_name = quote($to_field->table->name, $qt);

  return 'ALTER TABLE ' . $table_name . ' MODIFY ( ' . join('', @$field_defs) . ' )';
}

sub drop_field {
  my ($old_field, $options) = @_;
  my $qi         = $options->{quote_identifiers};
  my $table_name = quote($old_field->table->name, $qi);

  my $out = sprintf('ALTER TABLE %s DROP COLUMN %s', $table_name, quote($old_field->name, $qi));

  return $out;
}

sub add_field {
  my ($new_field, $options) = @_;

  my $qt = $options->{quote_table_names};
  my ($field_create, $field_defs, $trigger_defs, $field_comments)
      = create_field($new_field, $options, {});

  my $table_name = quote($new_field->table->name, $qt);

  my $out = sprintf('ALTER TABLE %s ADD ( %s )', $table_name, join('', @$field_defs));
  return $out;
}

sub create_field {
  my ($field, $options, $field_name_scope) = @_;
  my $qf = $options->{quote_field_names};
  my $qt = $options->{quote_table_names};

  my (@create, @field_defs, @trigger_defs, @field_comments);

  my $table_name   = $field->table->name;
  my $table_name_q = quote($table_name, $qt);

  #
  # Field name
  #
  my $field_name   = mk_name($field->name, '', $field_name_scope, 1);
  my $field_name_q = quote($field_name, $qf);
  my $field_def    = quote($field_name, $qf);
  $field->name($field_name);

  #
  # Datatype
  #
  my $check;
  my $data_type = lc $field->data_type;
  my @size      = $field->size;
  my %extra     = $field->extra;
  my $list      = $extra{'list'} || [];
  my $commalist = join(', ', map { __PACKAGE__->_quote_string($_) } @$list);

  if ($data_type eq 'enum') {
    $check     = "CHECK ($field_name_q IN ($commalist))";
    $data_type = 'varchar2';
  } elsif ($data_type eq 'set') {

    # XXX add a CHECK constraint maybe
    # (trickier and slower, than enum :)
    $data_type = 'varchar2';
  } else {
    if (defined $translate{$data_type}) {
      if (ref $translate{$data_type} eq "ARRAY") {
        ($data_type, $size[0]) = @{ $translate{$data_type} };
      } else {
        $data_type = $translate{$data_type};
      }
    }
    $data_type ||= 'varchar2';
  }

  # ensure size is not bigger than max size oracle allows for data type
  if (defined $max_size{$data_type}) {
    for (my $i = 0; $i < scalar @size; $i++) {
      my $max
          = ref($max_size{$data_type}) eq 'ARRAY'
          ? $max_size{$data_type}->[$i]
          : $max_size{$data_type};
      $size[$i] = $max if $size[$i] > $max;
    }
  }

  #
  # Fixes ORA-02329: column of datatype LOB cannot be
  # unique or a primary key
  #
  if ($data_type eq 'clob' && $field->is_primary_key) {
    $data_type = 'varchar2';
    $size[0] = 4000;
    warn "CLOB cannot be a primary key, changing to VARCHAR2\n"
        if $WARN;
  }

  if ($data_type eq 'clob' && $field->is_unique) {
    $data_type = 'varchar2';
    $size[0] = 4000;
    warn "CLOB cannot be a unique key, changing to VARCHAR2\n"
        if $WARN;
  }

  #
  # Fixes ORA-00907: missing right parenthesis
  #
  if ($data_type =~ /(date|clob)/i) {
    undef @size;
  }

  #
  # Fixes ORA-00906: missing right parenthesis
  # if size is 0 or undefined
  #
  for (qw/varchar2/) {
    if ($data_type =~ /^($_)$/i) {
      $size[0] ||= $max_size{$_};
    }
  }

  $field_def .= " $data_type";
  if (defined $size[0] && $size[0] > 0) {
    $field_def .= '(' . join(',', @size) . ')';
  }

  #
  # Default value
  #
  my $default = $field->default_value;
  if (defined $default) {
    debug("ORA: Handling default value: $default");
    #
    # Wherein we try to catch a string being used as
    # a default value for a numerical field.  If "true/false,"
    # then sub "1/0," otherwise just test the truthity of the
    # argument and use that (naive?).
    #
    if (ref $default and defined $$default) {
      $default = $$default;
    } elsif (ref $default) {
      $default = 'NULL';
    } elsif ($data_type =~ /^number$/i
      && $default !~ /^-?\d+$/
      && $default !~ m/null/i) {
      if ($default =~ /^true$/i) {
        $default = "'1'";
      } elsif ($default =~ /^false$/i) {
        $default = "'0'";
      } else {
        $default = $default ? "'1'" : "'0'";
      }
    } elsif (
      $data_type =~ /date/
      && ( $default eq 'current_timestamp'
        || $default eq 'now()')
    ) {
      $default = 'SYSDATE';
    } else {
      $default
          = $default =~ m/null/i
          ? 'NULL'
          : __PACKAGE__->_quote_string($default);
    }

    $field_def .= " DEFAULT $default",;
  }

  #
  # Not null constraint
  #
  unless ($field->is_nullable) {
    debug("ORA: Field is NOT NULL");
    $field_def .= ' NOT NULL';
  }

  $field_def .= " $check" if $check;

  #
  # Auto_increment
  #
  if ($field->is_auto_increment) {
    debug("ORA: Handling auto increment");
    my $base_name    = $table_name . "_" . $field_name;
    my $seq_name     = quote(mk_name($base_name, 'sq'), $qt);
    my $trigger_name = quote(mk_name($base_name, 'ai'), $qt);

    push @create, qq[DROP SEQUENCE $seq_name] if $options->{add_drop_table};
    push @create, "CREATE SEQUENCE $seq_name";
    my $trigger
        = "CREATE OR REPLACE TRIGGER $trigger_name\n"
        . "BEFORE INSERT ON $table_name_q\n"
        . "FOR EACH ROW WHEN (\n"
        . " new.$field_name_q IS NULL"
        . " OR new.$field_name_q = 0\n" . ")\n"
        . "BEGIN\n"
        . " SELECT $seq_name.nextval\n"
        . " INTO :new."
        . $field_name_q . "\n"
        . " FROM dual;\n"
        . "END;\n";

    push @trigger_defs, $trigger;
  }

  push @field_defs, $field_def;

  if (my $comment = $field->comments) {
    debug("ORA: Handling comment");
    $comment =~ __PACKAGE__->_quote_string($comment);
    push @field_comments, "COMMENT ON COLUMN $table_name_q.$field_name_q is\n $comment;"
        unless $options->{no_comments};
  }

  return \@create, \@field_defs, \@trigger_defs, \@field_comments;

}

sub drop_table {
  my ($table, $options) = @_;

  my $qi                      = $options->{quote_identifiers};
  my @foreign_key_constraints = grep { $_->type eq 'FOREIGN KEY' } $table->get_constraints;
  my @statements;
  for my $constraint (@foreign_key_constraints) {
    push @statements, alter_drop_constraint($constraint, $options);
  }

  return @statements, 'DROP TABLE ' . quote($table, $qi);
}

sub alter_create_index {
  my ($index, $options) = @_;
  return create_index($index, $options);
}

sub create_index {
  my ($index, $options, $index_options) = @_;
  $index_options = $index_options || '';
  my $qf         = $options->{quote_field_names} || $options->{quote_identifiers};
  my $qt         = $options->{quote_table_names} || $options->{quote_identifiers};
  my $index_name = $index->name                  || '';
  $index_name
      = $index_name
      ? mk_name($index_name)
      : mk_name($index->table, $index_name || 'i');
  return join(' ',
    map { $_ || () } 'CREATE',
    lc $index->type eq 'normal' ? 'INDEX'                 : $index->type . ' INDEX',
    $index_name                 ? quote($index_name, $qf) : '',
    'ON',
    quote($index->table, $qt),
    '(' . join(', ', map { quote($_, $qf) } $index->fields) . ")$index_options");
}

sub alter_drop_index {
  my ($index, $options) = @_;
  return 'DROP INDEX ' . $index->name;
}

sub alter_drop_constraint {
  my ($c, $options) = @_;
  my $qi         = $options->{quote_identifiers};
  my $table_name = quote($c->table->name, $qi);
  my @out        = ('ALTER', 'TABLE', $table_name, 'DROP',);
  if ($c->name) {
    push @out, ('CONSTRAINT', quote($c->name, $qi));
  } elsif ($c->type eq PRIMARY_KEY) {
    push @out, 'PRIMARY KEY';
  }
  return join(' ', @out);
}

sub alter_create_constraint {
  my ($c, $options) = @_;
  my $qi         = $options->{quote_identifiers};
  my $table_name = quote($c->table->name, $qi);
  return join(' ', 'ALTER TABLE', $table_name, 'ADD', create_constraint($c, $options));
}

sub create_constraint {
  my ($c, $options) = @_;

  my $qt           = $options->{quote_table_names};
  my $qf           = $options->{quote_field_names};
  my $table        = $c->table;
  my $table_name   = $table->name;
  my $table_name_q = quote($table_name, $qt);
  my $name         = $c->name || '';
  my @fields       = map { quote($_, $qf) } $c->fields;
  my @rfields      = map { quote($_, $qf) } $c->reference_fields;

  return undef if !@fields && $c->type ne 'CHECK';

  my $definition;

  if ($c->type eq PRIMARY_KEY) {
    debug("ORA: Creating PK constraint on fields (" . join(', ', @fields) . ")");

    # create a name if delay_constraints
    $name ||= mk_name($table_name, 'pk')
        if $options->{delay_constraints};
    $name       = quote($name, $qf);
    $definition = ($name ? "CONSTRAINT $name " : '') . 'PRIMARY KEY (' . join(', ', @fields) . ')';
  } elsif ($c->type eq UNIQUE) {

    # Don't create UNIQUE constraints identical to the primary key
    if (my $pk = $table->primary_key) {
      my $u_fields  = join(":", @fields);
      my $pk_fields = join(":", $pk->fields);
      next if $u_fields eq $pk_fields;
    }

    if ($name) {

      # Force prepend of table_name as ORACLE doesn't allow duplicate
      # CONSTRAINT names even for different tables (ORA-02264)
      $name = mk_name("${table_name}_$name", 'u')
          unless $name =~ /^$table_name/;
    } else {
      $name = mk_name($table_name, 'u');
    }
    debug("ORA: Creating UNIQUE constraint on fields (" . join(', ', @fields) . ") named $name");
    $name = quote($name, $qf);

    for my $f ($c->fields) {
      my $field_def = $table->get_field($f) or next;
      my $dtype     = $translate{
        ref $field_def->data_type eq "ARRAY"
        ? $field_def->data_type->[0]
        : $field_def->data_type
          }
          or next;
      if ($WARN && $dtype =~ /clob/i) {
        warn "Oracle will not allow UNIQUE constraints on "
            . "CLOB field '"
            . $field_def->table->name . '.'
            . $field_def->name . ".'\n";
      }
    }

    $definition = "CONSTRAINT $name UNIQUE " . '(' . join(', ', @fields) . ')';
  } elsif ($c->type eq CHECK_C) {
    $name ||= mk_name($name || $table_name, 'ck');
    $name = quote($name, $qf);
    my $expression = $c->expression || '';
    debug("ORA: Creating CHECK constraint on fields (" . join(', ', @fields) . ") named $name");
    $definition = "CONSTRAINT $name CHECK ($expression)";
  } elsif ($c->type eq FOREIGN_KEY) {
    $name = mk_name(join('_', $table_name, $c->fields) . '_fk');
    $name = quote($name, $qf);
    my $on_delete = uc($c->on_delete || '');

    $definition = "CONSTRAINT $name FOREIGN KEY ";

    if (@fields) {
      $definition .= '(' . join(', ', @fields) . ')';
    }

    my $ref_table = quote($c->reference_table, $qt);
    debug("ORA: Creating FK constraint on fields (" . join(', ', @fields) . ") named $name referencing $ref_table");
    $definition .= " REFERENCES $ref_table";

    if (@rfields) {
      $definition .= ' (' . join(', ', @rfields) . ')';
    }

    if ($c->match_type) {
      $definition .= ' MATCH ' . ($c->match_type =~ /full/i) ? 'FULL' : 'PARTIAL';
    }

    if ($on_delete && $on_delete ne "RESTRICT") {
      $definition .= ' ON DELETE ' . $c->on_delete;
    }
  }

  return $definition ? $definition : undef;
}

sub create_view {
  my ($view, $options) = @_;
  my $qt        = $options->{quote_table_names};
  my $view_name = quote($view->name, $qt);
  my $extra     = $view->extra;

  my $view_type    = 'VIEW';
  my $view_options = '';
  if (my $materialized = $extra->{materialized}) {
    $view_type = 'MATERIALIZED VIEW';
    $view_options .= ' ' . $materialized;
  }

  my @create;
  push @create, qq[DROP $view_type $view_name]
      if $options->{add_drop_view};

  push @create, sprintf("CREATE %s %s%s AS\n%s", $view_type, $view_name, $view_options, $view->sql);

  return \@create;
}

sub mk_name {
  my $basename = shift || '';
  my $type     = shift || '';
  $type = '' if $type =~ /^\d/;
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
    substr($name, $max_id_length - 2) = ""
        if length($name) >= $max_id_length - 1;
    $name .= sprintf("%02d", $prev++);

    warn "The name '$name_orig' has been changed to ", "'$name' to make it unique.\n"
        if $WARN;

    $scope->{$name_orig}++;
  }

  $scope->{$name}++;
  return $name;
}

1;

sub quote {
  my ($name, $q) = @_;
  return $name unless $q && $name;
  $name =~ s/\Q$quote_char/$quote_char$quote_char/g;
  return "$quote_char$name$quote_char";
}

# -------------------------------------------------------------------
# All bad art is the result of good intentions.
# Oscar Wilde
# -------------------------------------------------------------------

=pod

=head1 CREDITS

Mad props to Tim Bunce for much of the logic stolen from his "mysql2ora"
script.

=head1 AUTHORS

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>,
Alexander Hartmaier E<lt>abraxxa@cpan.orgE<gt>,
Fabien Wernli E<lt>faxmodem@cpan.orgE<gt>.

=head1 SEE ALSO

SQL::Translator, DDL::Oracle, mysql2ora.

=cut
