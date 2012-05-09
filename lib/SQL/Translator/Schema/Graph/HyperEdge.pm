package # hide from pause
  SQL::Translator::Schema::Graph::HyperEdge;

use strict;
use warnings;
use base qw(SQL::Translator::Schema::Graph::Edge);

use Class::MakeMethods::Template::Hash (
  'array_of_objects -class SQL::Translator::Schema::Field' => [ qw( thisviafield thatviafield thisfield thatfield) ], #FIXME
  'array_of_objects -class SQL::Translator::Schema::Graph::Node'                  => [ qw( thisnode thatnode ) ],
  object => [ 'vianode' => {class => 'SQL::Translator::Schema::Graph::Node'} ],
);

1;
