package # hide from pause
  SQL::Translator::Schema::Graph::Edge;

use strict;
use warnings;

use Class::MakeMethods::Template::Hash (
  new => ['new'],
  scalar => [ qw( type ) ],
  array => [ qw( traversals ) ],
  object => [
          'thisfield'    => {class => 'SQL::Translator::Schema::Field'}, #FIXME
          'thatfield'    => {class => 'SQL::Translator::Schema::Field'}, #FIXME
          'thisnode'     => {class => 'SQL::Translator::Schema::Graph::Node'},
          'thatnode'     => {class => 'SQL::Translator::Schema::Graph::Node'},

         ],
);

sub flip {
  my $self = shift;

#warn "self thisfield: ".$self->thisfield->name;
#warn "self thatfield: ".$self->thatfield->name;

  return SQL::Translator::Schema::Graph::Edge->new( thisfield => $self->thatfield,
                                       thatfield => $self->thisfield,
                                       thisnode  => $self->thatnode,
                                       thatnode  => $self->thisnode,
                                       type => $self->type eq 'import' ? 'export' : 'import'
                                      );
}

1;
