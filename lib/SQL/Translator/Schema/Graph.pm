package SQL::Translator::Schema::Graph;

use strict;

use Data::Dumper;

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
  'scalar' => [ qw( baseclass ) ],
  'number --counter' => [ qw( order ) ],
);

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

	$node->order($self->order_incr());
	$node->name( $self->translator->format_package_name($table->name) );
	$node->base( $self->baseclass );
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
	  next unless $field->is_foreign_key;

	  my $that = $self->node($field->foreign_key_reference->reference_table);

	  #this means we have an incomplete schema
	  next unless $that;

	  my $edge = Edge->new(
						   type => 'import',
						   thisnode => $node,
						   thisfield => $field,
						   thatnode => $that,
						   thatfield => ($field->foreign_key_reference->reference_fields)[0]
						  );


	  $node->has($that->name, $node->has($that->name)+1);
	  $that->many($node->name, $that->many($node->name)+1);

	  $node->push_edges( $edge );
	  $that->push_edges( $edge->flip );
	}
  }

  #
  # type MM relationships
  #
  foreach my $lnode (sort $self->node_values){
	next if $lnode->table->is_data;
	foreach my $inode1 (sort $self->node_values){
	  next if $inode1 eq $lnode;

	  my @inode1_imports = grep { $_->type eq 'import' and $_->thatnode eq $inode1 } $lnode->edges;
	  next unless @inode1_imports;

	  foreach my $inode2 (sort $self->node_values){
		my %i = map {$_->thatnode->name => 1} grep { $_->type eq 'import'} $lnode->edges;
		if(scalar(keys %i) == 1) {
		} else {
		  last if $inode1 eq $inode2;
		}

		next if $inode2 eq $lnode;
		my @inode2_imports =  grep { $_->type eq 'import' and $_->thatnode eq $inode2 } $lnode->edges;
		next unless @inode2_imports;

		my $cedge = CompoundEdge->new();
		$cedge->via($lnode);

		$cedge->push_edges( map {$_->flip} grep {$_->type eq 'import' and ($_->thatnode eq $inode1 or $_->thatnode eq $inode2)} $lnode->edges);

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

		$inode1->push_compoundedges($cedge);
		$inode2->push_compoundedges($cedge) unless $inode1 eq $inode2;

	  }
	}
  }
}

1;
