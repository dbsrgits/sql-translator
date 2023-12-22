package SQL::Translator::Types;

use warnings;
use strict;

=head1 NAME

SQL::Translator::Types - Type checking functions

=head1 SYNOPSIS

    package Foo;
    use Moo;
    use SQL::Translator::Types qw(schema_obj enum);

    has foo => ( is => 'rw', isa => schema_obj('Trigger') );
    has bar => ( is => 'rw', isa => enum([qw(baz quux quuz)], {
        msg => "Invalid value for bar: '%s'", icase => 1,
    });

=head1 DESCRIPTIONS

This module exports functions that return coderefs suitable for L<Moo>
C<isa> type checks.
Errors are reported using L<SQL::Translator::Utils/throw>.

=cut

use SQL::Translator::Utils qw(throw);
use Scalar::Util           qw(blessed);

use Exporter qw(import);
our @EXPORT_OK = qw(schema_obj enum);

=head1 FUNCTIONS

=head2 schema_obj($type)

Returns a coderef that checks that its arguments is an object of the
class C<< SQL::Translator::Schema::I<$type> >>.

=cut

sub schema_obj {
  my ($class) = @_;
  my $name = lc $class;
  $class = 'SQL::Translator::Schema' . ($class eq 'Schema' ? '' : "::$class");
  return sub {
    throw("Not a $name object")
        unless blessed($_[0])
        and $_[0]->isa($class);
  };
}

=head2 enum(\@strings, [$msg | \%parameters])

Returns a coderef that checks that the argument is one of the provided
C<@strings>.

=head3 Parameters

=over

=item msg

L<sprintf|perlfunc/sprintf> string for the error message.
If no other parameters are needed, this can be provided on its own,
instead of the C<%parameters> hashref.
The invalid value is passed as the only argument.
Defaults to C<Invalid value: '%s'>.

=item icase

If true, folds the values to lower case before checking for equality.

=item allow_undef

If true, allow C<undef> in addition to the specified strings.

=item allow_false

If true, allow any false value in addition to the specified strings.

=back

=cut

sub enum {
  my ($values, $args) = @_;
  $args ||= {};
  $args = { msg => $args } unless ref($args) eq 'HASH';
  my $icase  = !!$args->{icase};
  my %values = map { ($icase ? lc : $_) => undef } @{$values};
  my $msg    = $args->{msg} || "Invalid value: '%s'";
  my $extra_test
      = $args->{allow_undef} ? sub { defined $_[0] }
      : $args->{allow_false} ? sub { !!$_[0] }
      :                        undef;

  return sub {
    my $val = $icase ? lc $_[0] : $_[0];
    throw(sprintf($msg, $val))
        if (!defined($extra_test) || $extra_test->($val))
        && !exists $values{$val};
  };
}

1;
