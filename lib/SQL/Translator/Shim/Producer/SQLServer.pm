package SQL::Translator::Shim::Producer::SQLServer;

use Moo;
use SQL::Translator::ProducerUtils;

use SQL::Translator::Shim::Producer;
with 'SQL::Translator::Shim::Producer';

sub _build_shim { SQL::Translator::ProducerUtils->new( quote_chars => [qw( [ ] )] ) }

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

has sizeless_types => (
   is => 'ro',
   builder => '_build_sizeless_types',
);

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

sub field_type_size {
   my ($self, $field) = @_;

   ($field->size && !$self->sizeless_types->{$field->data_type}
      ? '(' . $field->size . ')'
      : ''
   )
}

sub field_autoinc { ( $_[1]->is_auto_increment ? 'IDENTITY' : () ) }

1;
