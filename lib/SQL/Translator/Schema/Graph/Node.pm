package SQL::Translator::Schema::Graph::Node;

use strict;

use Class::MakeMethods::Template::Hash (
  new => [ 'new' ],
  'array_of_objects -class SQL::Translator::Schema::Graph::Edge' => [ qw( edges ) ],
  'array_of_objects -class SQL::Translator::Schema::Graph::CompoundEdge' => [ qw( compoundedges ) ],
  'array_of_objects -class SQL::Translator::Schema::Graph::HyperEdge' => [ qw( hyperedges ) ],
  #'hash' => [ qw( many via has edgecount data_fields) ],
  'hash' => [ qw( many via has data_fields) ],
  scalar => [ qw( base name order primary_key primary_key_accessor table is_trivial_link ) ],
  number => [ qw( order ) ],
);

sub edgecount {
  my($self) = shift;

  $self->{_edgecount} ||= {};

  if(scalar(@_) == 1){
    my $k = shift;
    return $self->{_edgecount}{$k};
  } elsif(@_) {
    my %arg = @_;

    foreach my $k (keys %arg){
      #warn $a,"\t",$arg{$k};
      $self->{_edgecount}{$k} = $arg{$k};
    }

    return %arg;
  } else {
    return $self->{_edgecount};
  }
}

1;
