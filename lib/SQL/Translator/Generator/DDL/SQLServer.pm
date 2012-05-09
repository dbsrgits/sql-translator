package SQL::Translator::Generator::DDL::SQLServer;

=head1 NAME

SQL::Translator::Generator::DDL::SQLServer - A Moo based MS SQL Server DDL
generation engine.

=head1 DESCRIPTION

I<documentation volunteers needed>

=cut

use Moo;
use SQL::Translator::Schema::Constants;

with 'SQL::Translator::Generator::Role::Quote';
with 'SQL::Translator::Generator::Role::DDL';

sub quote_chars { [qw([ ])] }
sub name_sep { q(.) }

sub _build_numeric_types {
   +{
      int => 1,
   }
}

sub _build_unquoted_defaults {
   +{
      NULL => 1,
   }
}

sub _build_type_map {
   +{
      date => 'datetime',
      'time' => 'datetime',
   }
}

sub _build_sizeless_types {
   +{ map { $_ => 1 }
         qw( tinyint smallint int integer bigint text bit image datetime ) }
}

sub field {
   my ($self, $field) = @_;

   return join ' ', $self->field_name($field), ($self->field_type($field)||die 'type is required'),
      $self->field_autoinc($field),
      $self->field_nullable($field),
      $self->field_default($field),
}

sub field_autoinc { ( $_[1]->is_auto_increment ? 'IDENTITY' : () ) }

sub primary_key_constraint {
  'CONSTRAINT ' .
    $_[0]->quote($_[1]->name || $_[1]->table->name . '_pk') .
    ' PRIMARY KEY (' .
    join( ', ', map $_[0]->quote($_), $_[1]->fields ) .
    ')'
}

sub index {
  'CREATE INDEX ' .
   $_[0]->quote($_[1]->name || $_[1]->table->name . '_idx') .
   ' ON ' . $_[0]->quote($_[1]->table->name) .
   ' (' . join( ', ', map $_[0]->quote($_), $_[1]->fields ) . ');'
}

sub unique_constraint_single {
  my ($self, $constraint) = @_;

  'CONSTRAINT ' .
   $self->unique_constraint_name($constraint) .
   ' UNIQUE (' . join( ', ', map $self->quote($_), $constraint->fields ) . ')'
}

sub unique_constraint_name {
  my ($self, $constraint) = @_;
  $self->quote($constraint->name || $constraint->table->name . '_uc' )
}

sub unique_constraint_multiple {
  my ($self, $constraint) = @_;

  'CREATE UNIQUE NONCLUSTERED INDEX ' .
   $self->unique_constraint_name($constraint) .
   ' ON ' . $self->quote($constraint->table->name) . ' (' .
   join( ', ', $constraint->fields ) . ')' .
   ' WHERE ' . join( ' AND ',
    map $self->quote($_->name) . ' IS NOT NULL',
    grep { $_->is_nullable } $constraint->fields ) . ';'
}

sub foreign_key_constraint {
  my ($self, $constraint) = @_;

  my $on_delete = uc ($constraint->on_delete || '');
  my $on_update = uc ($constraint->on_update || '');

  # The default implicit constraint action in MSSQL is RESTRICT
  # but you can not specify it explicitly. Go figure :)
  for (map uc $_ || '', $on_delete, $on_update) {
    undef $_ if $_ eq 'RESTRICT'
  }

  'ALTER TABLE ' . $self->quote($constraint->table->name) .
   ' ADD CONSTRAINT ' .
   $self->quote($constraint->name || $constraint->table->name . '_fk') .
   ' FOREIGN KEY' .
   ' (' . join( ', ', map $self->quote($_), $constraint->fields ) . ') REFERENCES '.
   $self->quote($constraint->reference_table) .
   ' (' . join( ', ', map $self->quote($_), $constraint->reference_fields ) . ')'
   . (
     $on_delete && $on_delete ne "NO ACTION"
       ? ' ON DELETE ' . $on_delete
       : ''
   ) . (
     $on_update && $on_update ne "NO ACTION"
       ? ' ON UPDATE ' . $on_update
       : ''
   ) . ';';
}

sub enum_constraint_name {
  my ($self, $field_name) = @_;
  $self->quote($field_name . '_chk' )
}

sub enum_constraint {
  my ( $self, $field_name, $vals ) = @_;

  return (
     'CONSTRAINT ' . $self->enum_constraint_name($field_name) .
       ' CHECK (' . $self->quote($field_name) .
       ' IN (' . join( ',', map qq('$_'), @$vals ) . '))'
  )
}

sub constraints {
  my ($self, $table) = @_;

  (map $self->enum_constraint($_->name, { $_->extra }->{list} || []),
     grep { 'enum' eq lc $_->data_type } $table->get_fields),

  (map $self->primary_key_constraint($_),
     grep { $_->type eq PRIMARY_KEY } $table->get_constraints),

  (map $self->unique_constraint_single($_),
     grep {
       $_->type eq UNIQUE &&
       !grep { $_->is_nullable } $_->fields
     } $table->get_constraints),
}

sub table {
   my ($self, $table) = @_;
   join ( "\n", $self->table_comments($table), '' ) .
   join ( "\n\n",
      'CREATE TABLE ' . $self->quote($table->name) . " (\n".
        join( ",\n",
           map { "  $_" }
           $self->fields($table),
           $self->constraints($table),
        ) .
        "\n);",
        $self->unique_constraints_multiple($table),
        $self->indices($table),
   )
}

sub unique_constraints_multiple {
  my ($self, $table) = @_;
  (map $self->unique_constraint_multiple($_),
     grep {
        $_->type eq UNIQUE &&
        grep { $_->is_nullable } $_->fields
     } $table->get_constraints)
}

sub drop_table {
   my ($self, $table) = @_;
   my $name = $table->name;
   my $q_name = $self->quote($name);
   "IF EXISTS (SELECT name FROM sysobjects WHERE name = '$name' AND type = 'U')" .
      " DROP TABLE $q_name;"
}

sub remove_table_constraints {
   my ($self, $table) = @_;
   my $name = $table->name;
   my $q_name = $self->quote($name);
   "IF EXISTS (SELECT name FROM sysobjects WHERE name = '$name' AND type = 'U')" .
   " ALTER TABLE $q_name NOCHECK CONSTRAINT all;"
}

sub drop_tables {
   my ($self, $schema) = shift;

   if ($self->add_drop_table) {
      my @tables = sort { $b->order <=> $a->order } $schema->get_tables;
      return join "\n", (
         ( $self->add_comments ? (
         '--',
         '-- Turn off constraints',
         '--',
         '',
         ) : () ),
         (map $self->remove_table_constraints($_), @tables),
         ( $self->add_comments ? (
         '--',
         '-- Drop tables',
         '--',
         '',
         ) : () ),
         (map $self->drop_table($_), @tables),
      )
   }
   return '';
}

sub foreign_key_constraints {
   my ($self, $schema) = @_;
   ( map $self->foreign_key_constraint($_),
     grep { $_->type eq FOREIGN_KEY }
     map $_->get_constraints,
     $schema->get_tables )
}

sub schema {
   my ($self, $schema) = @_;

   $self->header_comments .
      $self->drop_tables($schema) .
      join("\n\n", map $self->table($_), grep { $_->name } $schema->get_tables) .
      "\n" . join "\n", $self->foreign_key_constraints($schema)
}

1;

=head1 AUTHORS

See the included AUTHORS file:
L<http://search.cpan.org/dist/SQL-Translator/AUTHORS>

=head1 COPYRIGHT

Copyright (c) 2012 the SQL::Translator L</AUTHORS> as listed above.

=head1 LICENSE

This code is free software and may be distributed under the same terms as Perl
itself.

=cut
