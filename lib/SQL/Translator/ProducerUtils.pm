package SQL::Translator::ProducerUtils;

use Moo;
use Sub::Quote 'quote_sub';

# this should be ro, but I have to modify it in BUILD so bleh
has quote_chars => ( is => 'rw' );

has name_sep    => (
   is => 'ro',
   default => quote_sub q{ '.' },
);

sub BUILD {
   my $self = shift;

   unless (ref($self->quote_chars)) {
      if ($self->quote_chars) {
         $self->quote_chars([$self->quote_chars])
      } else {
         $self->quote_chars([])
      }
   }

   $self
}

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
