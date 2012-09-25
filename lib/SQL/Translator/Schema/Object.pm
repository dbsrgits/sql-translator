package SQL::Translator::Schema::Object;

=head1 NAME

SQL::Translator::Schema::Object - Base class for SQL::Translator schema objects

=head1 SYNOPSIS

    package SQL::Translator::Schema::Foo;
    use Moo;
    extends 'SQL::Translator::Schema::Object';

=head1 DESCRIPTION

Base class for Schema objects. A Moo class consuming the following
roles.

=over

=item L<SQL::Translator::Role::Error>

Provides C<< $obj->error >>, similar to L<Class::Base>.

=item L<SQL::Translator::Role::BuildArgs>

Removes undefined constructor arguments, for backwards compatibility.

=item L<SQL::Translator::Schema::Role::Extra>

Provides an C<extra> attribute storing a hashref of arbitrary data.

=item L<SQL::Translator::Schema::Role::Compare>

Provides an C<< $obj->equals($other) >> method for testing object
equality.

=back

=cut

use Moo 1.000003;

with qw(
  SQL::Translator::Role::Error
  SQL::Translator::Role::BuildArgs
  SQL::Translator::Schema::Role::Extra
  SQL::Translator::Schema::Role::Compare
);

1;
