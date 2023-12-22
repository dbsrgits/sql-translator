package SQL::Translator::Generator::DDL::SQLite;

=head1 NAME

SQL::Translator::Generator::DDL::SQLite - A Moo based SQLite DDL generation
engine.

=head1 DESCRIPTION

I<documentation volunteers needed>

=cut

use Moo;

has quote_chars => (is => 'ro', default => sub { +[qw(" ")] });

with 'SQL::Translator::Generator::Role::Quote';
with 'SQL::Translator::Generator::Role::DDL';

sub name_sep {q(.)}

sub _build_type_map {
  +{
    set   => 'varchar',
    bytea => 'blob',
  };
}

sub _build_sizeless_types {
  +{
    text => 1,
    blob => 1,
  };
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
  };
}

sub _build_unquoted_defaults {
  +{
    NULL              => 1,
    'now()'           => 1,
    CURRENT_TIMESTAMP => 1,
  };
}

sub nullable { () }

sub _ipk {
  my ($self, $field) = @_;

  my $pk        = $field->table->primary_key;
  my @pk_fields = $pk ? $pk->fields : ();

  $field->is_primary_key
      && scalar @pk_fields == 1
      && ($field->data_type =~ /int(eger)?$/i
        || ($field->data_type =~ /^number?$/i && $field->size !~ /,/));
}

sub field_autoinc {
  my ($self, $field) = @_;

  return (
    (
              ($field->extra->{auto_increment_type} || '') eq 'monotonic'
          and $self->_ipk($field)
          and $field->is_auto_increment
    )
    ? 'AUTOINCREMENT'
    : ''
  );
}

sub field {
  my ($self, $field) = @_;

  return join ' ', $self->field_comments($field), $self->field_name($field),
      (
        $self->_ipk($field)
        ? ('INTEGER PRIMARY KEY')
        : ($self->field_type($field))
      ),
      ($self->field_autoinc($field) || ()), $self->field_nullable($field),
      $self->field_default(
        $field,
        {
          NULL                => 1,
          'now()'             => 1,
          'CURRENT_TIMESTAMP' => 1,
        }
      ),
      ;
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
