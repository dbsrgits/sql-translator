package SQL::Translator::Generator::Role::DDL;

=head1 NAME

SQL::Translator::Generator::Role::DDL - Role implementing common parts of
DDL generation.

=head1 DESCRIPTION

I<documentation volunteers needed>

=cut

use Moo::Role;
use SQL::Translator::Utils qw(header_comment);
use Scalar::Util;

requires '_build_type_map';
requires '_build_numeric_types';
requires '_build_unquoted_defaults';
requires '_build_sizeless_types';
requires 'quote';

has type_map => (
   is => 'lazy',
);

has numeric_types => (
   is => 'lazy',
);

has sizeless_types => (
   is => 'lazy',
);

has unquoted_defaults => (
   is => 'lazy',
);

has add_comments => (
   is => 'ro',
);

has add_drop_table => (
   is => 'ro',
);

# would also be handy to have a required size set if there is such a thing

sub field_name { $_[0]->quote($_[1]->name) }

sub field_comments {
   ( $_[1]->comments ? ('-- ' . $_[1]->comments . "\n ") : () )
}

sub table_comments {
   my ($self, $table) = @_;
   if ($self->add_comments) {
      return (
         "",
         "--",
         "-- Table: " . $self->quote($table->name) . "",
         "--",
         map "-- $_", $table->comments
      )
   } else {
      return ()
   }
}

sub field_nullable { ($_[1]->is_nullable ? $_[0]->nullable : 'NOT NULL' ) }

sub field_default {
  my ($self, $field, $exceptions) = @_;

  my $default = $field->default_value;
  return () if !defined $default;

  $default = \"$default"
    if $exceptions and !ref $default and $exceptions->{$default};
  if (ref $default) {
      $default = $$default;
  } elsif (!($self->numeric_types->{lc($field->data_type)} && Scalar::Util::looks_like_number ($default))) {
     $default = "'$default'";
  }
  return ( "DEFAULT $default" )
}

sub field_type {
   my ($self, $field) = @_;

   my $field_type = $field->data_type;
   ($self->type_map->{$field_type} || $field_type).$self->field_type_size($field)
}

sub field_type_size {
   my ($self, $field) = @_;

   ($field->size && !$self->sizeless_types->{$field->data_type}
      ? '(' . $field->size . ')'
      : ''
   )
}

sub fields {
  my ($self, $table) = @_;
  ( map $self->field($_), $table->get_fields )
}

sub indices {
  my ($self, $table) = @_;
  (map $self->index($_), $table->get_indices)
}

sub nullable { 'NULL' }

sub header_comments { header_comment() . "\n" if $_[0]->add_comments }

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
