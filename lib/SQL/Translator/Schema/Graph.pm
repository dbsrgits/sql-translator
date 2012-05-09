package # hide from pause
  SQL::Translator::Schema::Graph;
use strict;
use warnings;

use Carp;
carp(
  'SQL::Translator::Schema::Graph appears to be dead unmaintained and untested '
. 'code. It will remain a part of the SQL::Translator distribution for some '
. 'time, but eventually will be cleaned away. Please file a bug or contact the '
. 'maintainers and let them know you are still using this functionality'
);


use base 'Class::Base';

use Data::Dumper;
local $Data::Dumper::Maxdepth = 3;

use SQL::Translator::Schema::Graph::Node;
use SQL::Translator::Schema::Graph::Edge;
use SQL::Translator::Schema::Graph::Port;
use SQL::Translator::Schema::Graph::CompoundEdge;
use SQL::Translator::Schema::Graph::HyperEdge;

use constant Node => 'SQL::Translator::Schema::Graph::Node';
use constant Edge => 'SQL::Translator::Schema::Graph::Edge';
use constant Port => 'SQL::Translator::Schema::Graph::Port';
use constant CompoundEdge => 'SQL::Translator::Schema::Graph::CompoundEdge';
use constant HyperEdge => 'SQL::Translator::Schema::Graph::HyperEdge';

use Class::MakeMethods::Template::Hash (
  'new --and_then_init' => 'new',
  object => [
   'translator' => {class => 'SQL::Translator'},
  ],
  'hash' => [ qw( node ) ],
  'number --counter' => [ qw( order ) ],
);

our $DEBUG;
$DEBUG = 0 unless defined $DEBUG;

sub init {
  my $self = shift;

  #
  # build package objects
  #
  foreach my $table ($self->translator->schema->get_tables){
   die __PACKAGE__." table ".$table->name." doesn't have a primary key!" unless $table->primary_key;
   die __PACKAGE__." table ".$table->name." can't have a composite primary key!" if ($table->primary_key->fields)[1];

   my $node = Node->new();

   $self->node_push($table->name => $node);

   if ($table->is_trivial_link) { $node->is_trivial_link(1); }
   else { $node->is_trivial_link(0); }

   $node->order($self->order_incr());
   $node->name( $self->translator->format_package_name($table->name) );
   $node->table( $table );
   $node->primary_key( ($table->primary_key->fields)[0] );

   # Primary key may have a differenct accessor method name
   $node->primary_key_accessor(
                        defined($self->translator->format_pk_name)
                        ? $self->translator->format_pk_name->( $node->name, $node->primary_key )
                        : undef
                        );
  }

  foreach my $node ($self->node_values){
   foreach my $field ($node->table->get_fields){
     if (!$field->is_foreign_key && !$field->is_primary_key) { $node->data_fields->{$field->name} = 1; }
     elsif($field->is_foreign_key) {
     my $that = $self->node($field->foreign_key_reference->reference_table);

     #this means we have an incomplete schema
     next unless $that;

     my $edge = Edge->new(
                     type => 'import',
                     thisnode => $node,
                     thisfield => $field,
                     thatnode => $that,
                     #can you believe this sh*t just to get a field obj?
                     thatfield => $self->translator->schema->get_table($field->foreign_key_reference->reference_table)->get_field(($field->foreign_key_reference->reference_fields)[0])
                    );

     $node->edgecount($that->name, $node->edgecount($that->name)+1);

     $node->has($that->name, $node->has($that->name)+1);
     $that->many($node->name, $that->many($node->name)+1);

     $that->edgecount($node->name, $that->edgecount($node->name)+1);

          #warn "\t" . $node->name . "\t" . $node->edgecount($that->name);
     $node->push_edges( $edge );
     $that->push_edges( $edge->flip );
      }
   }

    #warn Dumper($node->edgecount());
    #warn "*****";
  }

  #
  # type MM relationships
  #
  #foreach linknode
  foreach my $lnode (sort $self->node_values){
   next if $lnode->table->is_data;
   foreach my $inode1 (sort $self->node_values){
     #linknode can't link to itself
     next if $inode1 eq $lnode;

     my @inode1_imports = grep { $_->type eq 'import' and $_->thatnode eq $inode1 } $lnode->edges;
     next unless @inode1_imports;

     foreach my $inode2 (sort $self->node_values){
      #linknode can't link to itself
      next if $inode2 eq $lnode;

      #identify tables that import keys to linknode
      my %i = map {$_->thatnode->name => 1} grep { $_->type eq 'import'} $lnode->edges;

      if(scalar(keys %i) == 1) {
      } else {
        last if $inode1 eq $inode2;
      }

      my @inode2_imports =  grep { $_->type eq 'import' and $_->thatnode eq $inode2 } $lnode->edges;
      next unless @inode2_imports;

      my $cedge = CompoundEdge->new();
      $cedge->via($lnode);

      #warn join ' ', map {$_->thisfield->name} map {$_->flip} $lnode->edges;
      #warn join ' ', map {$_->thisfield->name} $lnode->edges;
      #warn join ' ', map {$_->thisfield->name} map {$_->flip} grep {$_->type eq 'import'} $lnode->edges;
      #warn join ' ', map {$_->thatfield->name} map {$_->flip} grep {$_->type eq 'import'} $lnode->edges;
      $cedge->push_edges(
                     map {$_->flip}
                     grep {$_->type eq 'import'
                           and
                         ($_->thatnode eq $inode1 or $_->thatnode eq $inode2)
                         } $lnode->edges
                    );

      if(scalar(@inode1_imports) == 1 and scalar(@inode2_imports) == 1){
        $cedge->type('one2one');

        $inode1->via($inode2->name,$inode1->via($inode2->name)+1);
        $inode2->via($inode1->name,$inode2->via($inode1->name)+1);
      }
      elsif(scalar(@inode1_imports)  > 1 and scalar(@inode2_imports) == 1){
        $cedge->type('many2one');

        $inode1->via($inode2->name,$inode1->via($inode2->name)+1);
        $inode2->via($inode1->name,$inode2->via($inode1->name)+1);
      }
      elsif(scalar(@inode1_imports) == 1 and scalar(@inode2_imports)  > 1){
        #handled above
      }
      elsif(scalar(@inode1_imports)  > 1 and scalar(@inode2_imports)  > 1){
        $cedge->type('many2many');

        $inode1->via($inode2->name,$inode1->via($inode2->name)+1);
        $inode2->via($inode1->name,$inode2->via($inode1->name)+1);
      }
#warn Dumper($cedge);

      $inode1->push_compoundedges($cedge);
      $inode2->push_compoundedges($cedge) unless $inode1 eq $inode2;
#        if($inode1->name ne $inode2->name){
#          my $flipped_cedge = $cedge;
#          foreach my $flipped_cedge_edge ($flipped_cedge->edges){
#            warn Dumper $flipped_cedge_edge;
#            warn "\t". Dumper $flipped_cedge_edge->flip;
#          }
#        }
     }
   }
  }

  my $graph = $self; #hack

  #
  # create methods
  #
  # this code needs to move to Graph.pm
  foreach my $node_from ($graph->node_values) {

    next unless $node_from->table->is_data or !$node_from->table->is_trivial_link;

    foreach my $cedge ( $node_from->compoundedges ) {

      my $hyperedge = SQL::Translator::Schema::Graph::HyperEdge->new();

      my $node_to;
      foreach my $edge ($cedge->edges) {
        if ($edge->thisnode->name eq $node_from->name) {
          $hyperedge->vianode($edge->thatnode);

          if ($edge->thatnode->name ne $cedge->via->name) {
            $node_to ||= $graph->node($edge->thatnode->table->name);
          }

          $hyperedge->push_thisnode($edge->thisnode);
          $hyperedge->push_thisfield($edge->thisfield);
          $hyperedge->push_thisviafield($edge->thatfield);

        } else {
          if ($edge->thisnode->name ne $cedge->via->name) {
            $node_to ||= $graph->node($edge->thisnode->table->name);
          }
          $hyperedge->push_thatnode($edge->thisnode);
          $hyperedge->push_thatfield($edge->thisfield);
          $hyperedge->push_thatviafield($edge->thatfield);
        }
        $self->debug($edge->thisfield->name);
        $self->debug($edge->thatfield->name);
      }

      if ($hyperedge->count_thisnode == 1 and $hyperedge->count_thatnode == 1) {
        $hyperedge->type('one2one');
      } elsif ($hyperedge->count_thisnode  > 1 and $hyperedge->count_thatnode == 1) {
        $hyperedge->type('many2one');
      } elsif ($hyperedge->count_thisnode == 1 and $hyperedge->count_thatnode  > 1) {
        $hyperedge->type('one2many');
      } elsif ($hyperedge->count_thisnode  > 1 and $hyperedge->count_thatnode  > 1) {
        $hyperedge->type('many2many');
      }

      $self->debug($_) foreach sort keys %::SQL::Translator::Schema::Graph::HyperEdge::;

      #node_to won't always be defined b/c of multiple edges to a single other node
      if (defined($node_to)) {
        $self->debug($node_from->name);
        $self->debug($node_to->name);

        if (scalar($hyperedge->thisnode) > 1) {
          $self->debug($hyperedge->type ." via ". $hyperedge->vianode->name);
          my $i = 0;
          foreach my $thisnode ( $hyperedge->thisnode ) {
            $self->debug($thisnode->name .' '.
                        $hyperedge->thisfield_index(0)->name .' -> '.
                        $hyperedge->thisviafield_index($i)->name .' '.
                        $hyperedge->vianode->name .' '.
                        $hyperedge->thatviafield_index(0)->name .' <- '.
                        $hyperedge->thatfield_index(0)->name .' '.
                        $hyperedge->thatnode_index(0)->name ."\n"
                       );
            $i++;
          }
        }
        #warn Dumper($hyperedge) if $hyperedge->type eq 'many2many';
        $node_from->push_hyperedges($hyperedge);
      }
    }
  }

}

1;
