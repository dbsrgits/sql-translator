package SQL::Translator::Role::Error;

=head1 NAME

SQL::Translator::Role::Error - Error setter/getter for objects and classes

=head1 SYNOPSIS

In the class consuming the role:

    package Foo;
    use Moo;
    with qw(SQL::Translator::Role::Error);

    sub foo {
        ...
        return $self->error("Something failed")
            unless $some_condition;
        ...
    }

In code using the class:

    Foo->foo or die Foo->error;
    # or
    $foo->foo or die $foo->error;

=head1 DESCRIPTION

This L<Moo::Role> provides a method for getting and setting error on a
class or object.

=cut

use Moo::Role;
use Sub::Quote qw(quote_sub);

has _ERROR => (
  is       => 'rw',
  accessor => 'error',
  init_arg => undef,
  default  => quote_sub(q{ '' }),
);

=head1 METHODS

=head2 $object_or_class->error([$message])

If called with an argument, sets the error message and returns undef,
otherwise returns the message.

As an implementation detail, for compatibility with L<Class::Base>, the
message is stored in C<< $object->{_ERROR} >> or C<< $Class::ERROR >>,
depending on whether the invocant is an object.

=cut

around error => sub {
  my ($orig, $self) = (shift, shift);

  # Emulate horrible Class::Base API
  unless (ref($self)) {
    my $errref = do { no strict 'refs'; \${"${self}::ERROR"} };
    return $$errref unless @_;
    $$errref = $_[0];
    return undef;
  }

  return $self->$orig unless @_;
  $self->$orig(@_);
  return undef;
};

=head1 SEE ALSO

=over

=item *

L<Class::Base/Error Handling>

=back

=cut

1;
