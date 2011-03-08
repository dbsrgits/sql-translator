package SQL::Translator::Shim::Producer::SQLite;

use Moo;
use SQL::Translator::Shim;

use SQL::Translator::Shim::Producer;
with 'SQL::Translator::Shim::Producer';

sub _build_shim { SQL::Translator::Shim->new( quote_chars => ['', ''] ) }

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

sub _build_sizeless_types { +{ text => 1 } }
sub _build_numeric_types { +{ int => 1, tinyint => 1 } }

sub _build_unquoted_defaults {
   +{
       NULL              => 1,
       'now()'           => 1,
       CURRENT_TIMESTAMP => 1,
   }
}

sub nullable { () }

sub field {
   my ($self, $field) = @_;

   return join ' ',
      $self->field_comments($field),
      $self->field_name($field),
      ( $field->is_auto_increment
         ? ( 'INTEGER PRIMARY KEY' )
         : ( $self->field_type($field) )
      ),
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

