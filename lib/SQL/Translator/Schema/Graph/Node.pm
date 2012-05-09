package # hide from pause
  SQL::Translator::Schema::Graph::Node;

use strict;
use warnings;

use Class::MakeMethods::Template::Hash (
  new => [ 'new' ],
  'array_of_objects -class SQL::Translator::Schema::Graph::Edge' => [ qw( edges ) ],
  'array_of_objects -class SQL::Translator::Schema::Graph::CompoundEdge' => [ qw( compoundedges ) ],
  'array_of_objects -class SQL::Translator::Schema::Graph::HyperEdge' => [ qw( hyperedges ) ],
  #'hash' => [ qw( many via has edgecount data_fields) ],
  #'hash' => [ qw( many via has data_fields) ],
  scalar => [ qw( base name order primary_key primary_key_accessor table is_trivial_link ) ],
  number => [ qw( order ) ],
);

sub many {
  my($self) = shift;

  $self->{_many} ||= {};

  if(scalar(@_) == 1){
    my $k = shift;
    return $self->{_many}{$k} || 0;
  } elsif(@_) {
    my %arg = @_;

    foreach my $k (keys %arg){
      #warn $a,"\t",$arg{$k};
      $self->{_many}{$k} = $arg{$k};
    }

    return %arg;
  } else {
    return $self->{_many};
  }
}

sub via {
  my($self) = shift;

  $self->{_via} ||= {};

  if(scalar(@_) == 1){
    my $k = shift;
    return $self->{_via}{$k} || 0;
  } elsif(@_) {
    my %arg = @_;

    foreach my $k (keys %arg){
      #warn $a,"\t",$arg{$k};
      $self->{_via}{$k} = $arg{$k};
    }

    return %arg;
  } else {
    return $self->{_via};
  }
}

sub has {
  my($self) = shift;

  $self->{_has} ||= {};

  if(scalar(@_) == 1){
    my $k = shift;
    return $self->{_has}{$k} || 0;
  } elsif(@_) {
    my %arg = @_;

    foreach my $k (keys %arg){
      #warn $a,"\t",$arg{$k};
      $self->{_has}{$k} = $arg{$k};
    }

    return %arg;
  } else {
    return $self->{_has};
  }
}

sub edgecount {
  my($self) = shift;

  $self->{_edgecount} ||= {};

  if(scalar(@_) == 1){
    my $k = shift;
    return $self->{_edgecount}{$k} || 0;
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

sub data_fields {
  my($self) = shift;

  $self->{_data_fields} ||= {};

  if(scalar(@_) == 1){
    my $k = shift;
    return $self->{_data_fields}{$k};
  } elsif(@_) {
    my %arg = @_;

    foreach my $k (keys %arg){
      #warn $a,"\t",$arg{$k};
      $self->{_data_fields}{$k} = $arg{$k};
    }

    return %arg;
  } else {
    return $self->{_data_fields};
  }
}

1;
