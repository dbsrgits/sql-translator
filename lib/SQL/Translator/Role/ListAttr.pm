package SQL::Translator::Role::ListAttr;

use warnings;
use strict;

=head1 NAME

SQL::Translator::Role::ListAttr - context-sensitive list attributes

=head1 SYNOPSIS

    package Foo;
	use Moo;
	use SQL::Translator::Role::ListAttr;

	with ListAttr foo => ( uniq => 1, append => 1 );

=head1 DESCRIPTION

This package provides a variable L<Moo::Role> for context-sensitive list
attributes.

=cut

use SQL::Translator::Utils qw(parse_list_arg ex2err uniq);
use Sub::Quote             qw(quote_sub);

use Package::Variant (
  importing => {
    'Moo::Role' => [],
  },
  subs => [qw(has around)],
);

=head1 FUNCTIONS

=head2 ListAttr $name => %parameters;

Returns a L<Moo::Role> providing an arrayref attribute named C<$name>,
and wrapping the accessor to provide context-sensitivity both for
setting and getting.  If no C<builder> or C<default> is provided, the
default value is the empty list.

On setting, the arguments are parsed using
L<SQL::Translator::Utils/parse_list_arg>, and the accessor will return
an array reference or a list, depending on context.

=head3 Parameters

=over

=item append

If true, the setter will append arguments to the existing ones, rather
than replacing them.

=item uniq

If true, duplicate items will be removed, keeping the first one seen.

=item may_throw

If accessing the attribute might L<throw|SQL::Translator::Utils/throw>
an exception (e.g. from a C<builder> or C<isa> check), this should be
set to make the accessor store the exception using
L<SQL::Translator::Role::Error> and return undef.

=item undef_if_empty

If true, and the list is empty, the accessor will return C<undef>
instead of a reference to an empty in scalar context.

=back

Unknown parameters are passed through to the L<has|Moo/has> call for
the attribute.

=cut

sub make_variant {
  my ($class, $target_package, $name, %arguments) = @_;

  my $may_throw      = delete $arguments{may_throw};
  my $undef_if_empty = delete $arguments{undef_if_empty};
  my $append         = delete $arguments{append};
  my $coerce
      = delete $arguments{uniq}
      ? sub { [ uniq @{ parse_list_arg($_[0]) } ] }
      : \&parse_list_arg;

  has($name => (
    is => 'rw',
    (!$arguments{builder} ? (default => quote_sub(q{ [] }),) : ()),
    coerce => $coerce,
    %arguments,
  ));

  around(
    $name => sub {
      my ($orig, $self) = (shift, shift);
      my $list = parse_list_arg(@_);
      $self->$orig([ @{ $append ? $self->$orig : [] }, @$list ])
          if @$list;

      my $return;
      if ($may_throw) {
        $return = ex2err($orig, $self) or return;
      } else {
        $return = $self->$orig;
      }
      my $scalar_return = !@{$return} && $undef_if_empty ? undef : $return;
      return wantarray ? @{$return} : $scalar_return;
    }
  );
}

=head1 SEE ALSO

=over

=item L<SQL::Translator::Utils>

=item L<SQL::Translator::Role::Error>

=back

=cut

1;
