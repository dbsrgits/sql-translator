package SQL::Translator::Schema::Graph::Node;

use strict;

use Class::MakeMethods::Template::Hash (
  new => [ 'new' ],
  'array_of_objects -class SQL::Translator::Schema::Graph::Edge' => [ qw( edges ) ],
  'array_of_objects -class SQL::Translator::Schema::Graph::CompoundEdge' => [ qw( compoundedges ) ],
  'array_of_objects -class SQL::Translator::Schema::Graph::HyperEdge' => [ qw( hyperedges ) ],
  'hash' => [ qw( many via has edgecount) ],
  scalar => [ qw( base name order primary_key primary_key_accessor table ) ],
  number => [ qw( order ) ],
);

1;
