package # hide from pause
  SQL::Translator::Generator::Utils;

use Moo;
use Sub::Quote 'quote_sub';

# this should be ro, but I have to modify it in BUILD so bleh
has quote_chars => ( is => 'rw' );

has name_sep    => (
   is => 'ro',
   default => quote_sub q{ '.' },
);

with 'SQL::Translator::Generator::Role::Quote';

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

1;
