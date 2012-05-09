package SQL::Translator::Generator::Role::Quote;

use Moo::Role;

=head1 NAME

SQL::Translator::Generator::Role::Quote - Role for dealing with identifier
quoting.

=head1 DESCRIPTION

I<documentation volunteers needed>

=cut

requires qw(quote_chars name_sep);

sub quote {
  my ($self, $label) = @_;

  return '' unless defined $label;
  return $$label if ref($label) eq 'SCALAR';

  my @quote_chars = @{$self->quote_chars};
  return $label unless scalar @quote_chars;

  my ($l, $r);
  if (@quote_chars == 1) {
    ($l, $r) = (@quote_chars) x 2;
  } elsif (@quote_chars == 2) {
    ($l, $r) = @quote_chars;
  } else {
    die 'too many quote chars!';
  }

  my $sep = $self->name_sep || '';
  # parts containing * are naturally unquoted
  join $sep, map "$l$_$r", ( $sep ? split (/\Q$sep\E/, $label ) : $label )
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
