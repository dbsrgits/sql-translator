package SQL::Translator::Generator::DDL::SQLite;

=head1 NAME

SQL::Translator::Generator::DDL::SQLite - A Moo based SQLite DDL generation
engine.

=head1 DESCRIPTION

I<documentation volunteers needed>

=cut
use Carp;
use Moo;

has quote_chars => (is=>'ro', default=>sub { +[qw(" ")] } );

with 'SQL::Translator::Generator::Role::Quote';
with 'SQL::Translator::Generator::Role::DDL';

sub name_sep { q(.) }

sub _build_type_map {
   +{
      set   => 'varchar',
      bytea => 'blob',
   }
}

sub _build_sizeless_types {
   +{
      text => 1,
      blob => 1,
   }
}
sub _build_numeric_types {
   +{
      int                => 1,
      integer            => 1,
      tinyint            => 1,
      smallint           => 1,
      mediumint          => 1,
      bigint             => 1,
      'unsigned big int' => 1,
      int2               => 1,
      int8               => 1,
      numeric            => 1,
      decimal            => 1,
      boolean            => 1,
      real               => 1,
      double             => 1,
      'double precision' => 1,
      float              => 1,
   }
}

sub _build_unquoted_defaults {
   +{
       NULL              => 1,
       'now()'           => 1,
       CURRENT_TIMESTAMP => 1,
   }
}

sub nullable { () }

sub field_autoinc {
  my ($self,$field) = @_;
  my $pk = $field->table->primary_key;
  my @pk_fields = $pk ? $pk->fields : ();
 
  if ( $field->is_auto_increment && scalar @pk_fields > 1 ){
    croak sprintf
      "SQLite doen't support auto increment with more then one primary key. Problem has occurred by table '%s' and column '%s'",
      $field->table->name,
      $field->name
      ;
  }
 
  ( $_[1]->is_auto_increment ? 'AUTOINCREMENT' : () ) 
}

sub primary_key_constraint {
  my ($self,$table) = @_;
  my $pk = $table->primary_key;
  my @pk_fields = $pk ? $pk->fields : ();
  return () if (scalar @pk_fields < 2);

  return 'PRIMARY KEY ('
    . join(', ', map $self->quote($_), @pk_fields)
    . ')';
}

sub field_type_and_single_pk {
  my ($self, $field) = @_;
  my $pk = $field->table->primary_key;
  my @pk_fields = $pk ? $pk->fields : ();
  my $field_type = $self->field_type($field);

  if ( $field->is_primary_key && scalar @pk_fields == 1){
    # Convert int(xx), number, .. to INTEGER. This is important for backward 
    # compatibility and conversion from database to database.
    if (  $field->data_type =~ /int(eger)?$/i 
       || ( $field->data_type =~ /^number?$/i && $field->size !~ /,/ )
    ){
      $field_type = 'INTEGER';
    }
    
    return $field_type . ' PRIMARY KEY';
  }
  return $field_type;
}


sub field {
   my ($self, $field) = @_;

   return join ' ',
      $self->field_comments($field),
      $self->field_name($field),
      $self->field_type_and_single_pk($field),
      $self->field_autoinc($field),
      $self->field_nullable($field),
      $self->field_default($field, {
         NULL => 1,
         'now()' => 1,
         'CURRENT_TIMESTAMP' => 1,
      }),
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
