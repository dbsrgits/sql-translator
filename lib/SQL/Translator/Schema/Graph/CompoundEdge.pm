package # hide from pause
  SQL::Translator::Schema::Graph::CompoundEdge;

use strict;
use warnings;
use base qw(SQL::Translator::Schema::Graph::Edge);
use Class::MakeMethods::Template::Hash (
  new => ['new'],
  object => [
          'via'  => {class => 'SQL::Translator::Schema::Graph::Node'},
         ],
  'array_of_objects -class SQL::Translator::Schema::Graph::Edge' => [ qw( edges ) ],
);

1;
