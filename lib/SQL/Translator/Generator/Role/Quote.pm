package SQL::Translator::Generator::Role::Quote;

use Moo::Role;

=head1 NAME

SQL::Translator::Generator::Role::Quote - Role for dealing with identifier
quoting.

=head1 DESCRIPTION

I<documentation volunteers needed>

=cut

requires qw(quote_chars name_sep);

has escape_char => (
  is      => 'ro',
  lazy    => 1,
  clearer => 1,
  default => sub { $_[0]->quote_chars->[-1] },
);

sub quote {
  my ($self, $label) = @_;

  return '' unless defined $label;
  return $$label if ref($label) eq 'SCALAR';

  my @quote_chars = @{ $self->quote_chars };
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
  my $esc = $self->escape_char;

  # parts containing * are naturally unquoted
  join $sep, map { (my $n = $_) =~ s/\Q$r/$esc$r/g; "$l$n$r" } ($sep ? split(/\Q$sep\E/, $label) : $label);
}

sub quote_string {
  my ($self, $string) = @_;

  return $string unless defined $string;
  $string =~ s/'/''/g;
  return qq{'$string'};
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
