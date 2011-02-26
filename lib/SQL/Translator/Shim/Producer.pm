package SQL::Translator::Shim::Producer;

use Moo::Role;

requires '_build_shim';
requires '_build_type_map';
requires 'field_type_size';

has shim => (
   is => 'ro',
   builder => '_build_shim',
);

has type_map => (
   is => 'ro',
   builder => '_build_type_map',
);

# would also be handy to have a required size set if there is such a thing

sub field_name { $_[0]->shim->quote($_[1]->name) }

sub field_nullable { ($_[1]->is_nullable ? 'NULL' : 'NOT NULL' ) }

sub field_default {
  (defined $_[1]->default_value ? 'DEFAULT ' . q(') . $_[1]->default_value . q(') : () )
}

sub field_type {
   my ($self, $field) = @_;

   my $field_type = $field->data_type;
   ($self->type_map->{$field_type} || $field_type).$self->field_type_size($field)
}

1;
