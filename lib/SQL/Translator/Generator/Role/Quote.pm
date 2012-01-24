package # hide from pause
  SQL::Translator::Generator::Role::Quote;

use Moo::Role;

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
