package Turnkey::Node;

use strict;
use Class::MakeMethods::Template::Hash (
  new => [ 'new' ],
  'array_of_objects -class Turnkey::Edge' => [ qw( edges ) ],
  'array_of_objects -class Turnkey::CompoundEdge' => [ qw( compoundedges ) ],
  'array_of_objects -class Turnkey::HyperEdge' => [ qw( hyperedges ) ],
  'hash' => [ qw( many via has) ],
  scalar => [ qw( base name order primary_key primary_key_accessor table) ],
);


package Turnkey::Edge;

use strict;
use Class::MakeMethods::Template::Hash (
  new => ['new'],
  scalar => [ qw( type ) ],
  array => [ qw( traversals ) ],
  object => [
			 'thisfield'    => {class => 'SQL::Translator::Schema::Field'},
			 'thatfield'    => {class => 'SQL::Translator::Schema::Field'},
			 'thisnode'     => {class => 'Turnkey::Node'},
			 'thatnode'     => {class => 'Turnkey::Node'},

			],
);

sub flip {
  my $self = shift;
  return Turnkey::Edge->new( thisfield => $self->thatfield,
							 thatfield => $self->thisfield,
							 thisnode  => $self->thatnode,
							 thatnode  => $self->thisnode,
							 type => $self->type eq 'import' ? 'export' : 'import'
						   );
}


package Turnkey::HyperEdge;

use strict;
use base qw(Turnkey::Edge);
use Class::MakeMethods::Template::Hash (
  'array_of_objects -class SQL::Translator::Schema::Field' => [ qw( thisviafield thatviafield thisfield thatfield) ],
  'array_of_objects -class Turnkey::Node'                  => [ qw( thisnode thatnode ) ],
  object => [ 'vianode' => {class => 'Turnkey::Node'} ],
);


package Turnkey::CompoundEdge;

use strict;
use base qw(Turnkey::Edge);
use Class::MakeMethods::Template::Hash (
  new => ['new'],
  object => [
			 'via'  => {class => 'Turnkey::Node'},
			],
  'array_of_objects -class Turnkey::Edge' => [ qw( edges ) ],
);


package SQL::Translator::Producer::Turnkey;

use strict;
use vars qw[ $VERSION $DEBUG ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 1 unless defined $DEBUG;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(header_comment);
use Data::Dumper;
use Template;

my %CDBI_auto_pkgs = (
    MySQL      => 'mysql',
    PostgreSQL => 'Pg',
    Oracle     => 'Oracle',
);

# -------------------------------------------------------------------
sub produce {
    my $t             = shift;
	my $create        = undef;
    my $no_comments   = $t->no_comments;
    my $schema        = $t->schema;
    my $args          = $t->producer_args;

	my $parser_type   = (split /::/, $t->parser_type)[-1];

    local $DEBUG      = $t->debug;

	my %meta          = (
						 format_fk => $t->format_fk_name,
						 template  => $args->{'template'}      || '',
						 baseclass => $args->{'main_pkg_name'} || $t->format_package_name('DBI'),
						 db_user   => $args->{'db_user'}       || '',
						 db_pass   => $args->{'db_pass'}       || '',
						 parser    => $t->parser_type,
						 producer  => __PACKAGE__,
						 dsn       => $args->{'dsn'} || sprintf( 'dbi:%s:_', $CDBI_auto_pkgs{ $parser_type }
																 ? $CDBI_auto_pkgs{ $parser_type }
																 : $parser_type
															   )
						 );


	#
	# build package objects
	#
	my %nodes;
	my $order;
	foreach my $table ($schema->get_tables){

	  die __PACKAGE__." table ".$table->name." doesn't have a primary key!" unless $table->primary_key;
	  die __PACKAGE__." table ".$table->name." can't have a composite primary key!" if ($table->primary_key->fields)[1];

	  my $node = Turnkey::Node->new();
	  $nodes{ $table->name } = $node;

	  $node->order( ++$order );
	  $node->name( $t->format_package_name($table->name) );
	  $node->base( $meta{'baseclass'} );
	  $node->table( $table );
	  $node->primary_key( ($table->primary_key->fields)[0] );
	  # Primary key may have a differenct accessor method name
	  $node->primary_key_accessor(
								  defined($t->format_pk_name)
								  ? $t->format_pk_name->( $node->name, $node->primary_key )
								  : undef
								 );
	}

	foreach my $node (values %nodes){
	  foreach my $field ($node->table->get_fields){
		next unless $field->is_foreign_key;

		my $that = $nodes{ $field->foreign_key_reference->reference_table };
		#this means we have an incomplete schema
		next unless $that;

		my $edge = Turnkey::Edge->new(
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
	foreach my $lnode (sort values %nodes){
	  next if $lnode->table->is_data;
	  foreach my $inode1 (sort values %nodes){
		next if $inode1 eq $lnode;

		my @inode1_imports = grep { $_->type eq 'import' and $_->thatnode eq $inode1 } $lnode->edges;
		next unless @inode1_imports;

		foreach my $inode2 (sort values %nodes){
		  my %i = map {$_->thatnode->name => 1} grep { $_->type eq 'import'} $lnode->edges;
		  if(scalar(keys %i) == 1) {
		  } else {
			last if $inode1 eq $inode2;
		  }

		  next if $inode2 eq $lnode;
		  my @inode2_imports =  grep { $_->type eq 'import' and $_->thatnode eq $inode2 } $lnode->edges;
		  next unless @inode2_imports;

 		  my $cedge = Turnkey::CompoundEdge->new();
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

    #
    # create methods
    #
	foreach my $node_from (values %nodes){
	  next unless $node_from->table->is_data;
	  foreach my $cedge ( $node_from->compoundedges ){
		my $hyperedge = Turnkey::HyperEdge->new;

		my $node_to;

		foreach my $edge ($cedge->edges){
		  if($edge->thisnode->name eq $node_from->name){
			$hyperedge->vianode($edge->thatnode);

			if($edge->thatnode->name ne $cedge->via->name){
			  $node_to ||= $nodes{ $edge->thatnode->table->name };
			}

			  $hyperedge->push_thisnode($edge->thisnode);
			  $hyperedge->push_thisfield($edge->thisfield);
			  $hyperedge->push_thisviafield($edge->thatfield);

		  } else {

			if($edge->thisnode->name ne $cedge->via->name){
			  $node_to ||= $nodes{ $edge->thisnode->table->name };
			}

			  $hyperedge->push_thatnode($edge->thisnode);
			  $hyperedge->push_thatfield($edge->thisfield);
			  $hyperedge->push_thatviafield($edge->thatfield);
		  }
		}

		   if($hyperedge->count_thisnode == 1 and $hyperedge->count_thatnode == 1){ $hyperedge->type('one2one')   }
		elsif($hyperedge->count_thisnode  > 1 and $hyperedge->count_thatnode == 1){ $hyperedge->type('many2one')  }
		elsif($hyperedge->count_thisnode == 1 and $hyperedge->count_thatnode  > 1){ $hyperedge->type('one2many')  }
		elsif($hyperedge->count_thisnode  > 1 and $hyperedge->count_thatnode  > 1){ $hyperedge->type('many2many') }

#warn $node_from->name ."\t". $node_to->name ."\t". $hyperedge->type ."\t". $hyperedge->vianode->name;

		$node_from->push_hyperedges($hyperedge);
	  }
 	}

	$meta{"nodes"} = \%nodes;
	return(translateForm($t, \%meta));
}

###########################################
# Here documents for the tt2 templates    #
###########################################

my $turnkey_dbi_tt2 = <<EOF;
[% MACRO printPackage(node) BLOCK %]
# --------------------------------------------

package [% node.name %];
use base '[% node.base %]';
use Class::DBI::Pager;

[% node.name %]->set_up_table('[% node.table.name %]');
[% printPKAccessors(node.primary_key, node.table.name) %]
[% printHasA(node.edges, node) %]
[% printHasMany(node.edges, node) %]
[% printHasCompound(node.compoundedges, node.hyperedges, node.name) %]
[% END %]

[% MACRO printPKAccessors(array, name) BLOCK %]
#
# Primary key accessors
#
[% FOREACH item = array %]
sub id { shift->[% item %] }
sub [% name %] { shift->[% item %] }
[% END %]
[% END %]

[% MACRO printHasA(edges, name) BLOCK %]
#
# Has A
#
[% FOREACH edge = edges %]
  [%- IF edge.type == 'import' -%]
[% node.name %]->has_a([% edge.thisfield.name %] => '[% edge.thatnode.name %]');
    [%- IF node.has(edge.thatnode.name) < 2 %]
sub [% edge.thatnode.table.name %] { return shift->[% edge.thisfield.name %] }
    [%- ELSE %]
sub [% format_fk(edge.thisnode.table.name,edge.thisfield.name) %] { return shift->[% edge.thisfield.name %] }
    [%- END %]
  [%- END %]
[% END %]
[% END %]

[% MACRO printHasMany(edges, node) BLOCK %]
#
# Has Many
#
[% FOREACH edge = edges %]
  [%- IF edge.type == 'export' -%]
[% node.name %]->has_many([% edge.thatnode.table.name %]_[% edge.thatfield.name %], '[% edge.thatnode.name %]' => '[% edge.thatfield.name %]');
    [%- IF node.via(edge.thatnode.name) >= 1 %]
sub [% edge.thatnode.table.name %]_[% format_fk(edge.thatnode.table.name,edge.thatfield.name) %]s { return shift->[% edge.thatnode.table.name %]_[% edge.thatfield.name %] }
    [%- ELSIF edge.thatnode.table.is_data %]
sub [% edge.thatnode.table.name %]s { return shift->[% edge.thatnode.table.name %]_[% edge.thatfield.name %] }
    [%- END %]
  [%- END %]
[% END %]
[% END %]

[% MACRO printHasCompound(cedges,hedges,name) BLOCK %]
#
# Has Compound Many
#
[% FOREACH cedge = cedges %]
[% FOREACH edge = cedge.edges %]
  [%- NEXT IF edge.thisnode.name != name -%]
sub [% cedge.via.table.name %]_[% format_fk(edge.thatnode.table.name,edge.thatfield.name) %]s { return shift->[% cedge.via.table.name %]_[% edge.thatfield.name %] }
[% END %]
[% END %]
[% FOREACH h = hedges %]
  [%- NEXT IF h.thisnode.name != name -%]
  [%- IF h.type == 'one2one' %]
1sub [% h.thatnode.table.name %]s { my \$self = shift; return map \$_->[% h.thatviafield.name %], \$self->[% h.vianode.table.name %]_[% h.thisviafield.name %] }
  [%- ELSIF h.type == 'one2many' %]
2
  [%- ELSIF h.type == 'many2one' %]
3sub [% h.thatnode.table.name %]s { my \$self = shift; return map \$_->[% h.thatviafield.name %], \$self->[% h.vianode.table.name %]_[% h.thisviafield.name %] }
  [%- ELSIF h.type == 'many2many' %]
4
  [%- END %]
[% END %]
[% END %]

[% MACRO printList(array) BLOCK %][% FOREACH item = array %][% item %] [% END %][% END %]
package [% baseclass %];

# Created by SQL::Translator::Producer::Turnkey
# Template used: classdbi

use strict;
use base qw(Class::DBI::Pg);

Durian::Model::DBI->set_db('Main', '[% db_str  %]', '[% db_user %]', '[% db_pass %]');

[% FOREACH node = nodes %]
    [% printPackage(node.value) %]
[% END %]
EOF

my $turnkey_atom_tt2 = <<'EOF';
[% ###### DOCUMENT START ###### %]

[% FOREACH node = linkable %]

##############################################

package Durian::Atom::[% node.key FILTER ucfirst %];

[% pname = node.key FILTER ucfirst%]
[% pkey = "Durian::Model::${pname}" %]

use base qw(Durian::Atom);
use Data::Dumper;

sub can_render {
	return 1;
}

sub render {
	my $self = shift;
	my $dbobject = shift;
    # Assumption here that if it's not rendering on it's own dbobject
    # then it's a list. This will be updated when AtomLists are implemented -boconnor
	if(ref($dbobject) eq 'Durian::Model::[% node.key FILTER ucfirst %]') {
		return(_render_record($dbobject));
	}
	else { return(_render_list($dbobject)); }
}

sub _render_record {
	my $dbobject = shift;
	my @output = ();
	my $row = {};
	my $field_hash = {};
	[% FOREACH field = nodes.$pkey.columns_essential %]
	$field_hash->{[% field %]} = $dbobject->[% field %]();
    [% END %]
	$row->{data} = $field_hash;
	$row->{id} = $dbobject->id();
	push @output, $row;
	return(\@output);
}

sub _render_list {
	my $dbobject = shift;
	my @output = ();
	my @objects = $dbobject->[% node.key %]s;
	foreach my $object (@objects)
    {
		my $row = {};
	    my $field_hash = {};
	  [% FOREACH field = nodes.$pkey.columns_essential %]
		$field_hash->{[% field %]} = $object->[% field %]();
	  [% END %]
		$row->{data} = $field_hash;
	    $row->{id} = $object->id();
	    push @output, $row;
    }
	return(\@output);
}

sub head {
	return 1;
}

1;

[% END %]
EOF

my $turnkey_xml_tt2 = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Durian SYSTEM "Durian.dtd">
<Durian>

<!-- The basic layout is fixed -->
  <container bgcolor="#FFFFFF" cellpadding="0" cellspacing="0" height="90%" orientation="vertical" type="root" width="100%" xlink:label="RootContainer">
	<container cellpadding="3" cellspacing="0" orientation="horizontal" type="container" height="100%" width="100%" xlink:label="MiddleContainer">
	  <container align="center" cellpadding="2" cellspacing="0" class="leftbar" orientation="vertical" type="minor" width="0%" xlink:label="MidLeftContainer"/>
	  <container cellpadding="0" cellspacing="0" orientation="vertical" width="100%" type="major" xlink:label="MainContainer"/>
	</container>
  </container>

<!-- Atom Classes -->
[% FOREACH node = linkable %]
  <atom class="Durian::Atom::[% node.key FILTER ucfirst %]"  name="[% node.key FILTER ucfirst %]" xlink:label="[% node.key FILTER ucfirst %]Atom"/>
[%- END -%]

<!-- Atom Bindings -->
<atomatombindings>
[% FOREACH focus_atom = linkable %]
  [% FOREACH link_atom = focus_atom.value %]
  <atomatombinding xlink:from="#[% focus_atom.key FILTER ucfirst %]Atom" xlink:to="#[% link_atom.key FILTER ucfirst %]Atom" xlink:label="[% focus_atom.key FILTER ucfirst %]Atom2[% link_atom.key FILTER ucfirst %]Atom"/>
  [%- END -%]
[%- END -%]
</atomatombindings>

<atomcontainerbindings>
[% FOREACH focus_atom = linkable %]
  <atomcontainerbindingslayout xlink:label="Durian::Model::[% focus_atom.key FILTER ucfirst %]">
  [% FOREACH link_atom = focus_atom.value %]
    <atomcontainerbinding xlink:from="#MidLeftContainer" xlink:label="MidLeftContainer2[% link_atom.key FILTER ucfirst %]Atom"  xlink:to="#[% link_atom.key FILTER ucfirst %]Atom"/>
  [%- END -%]
  <atomcontainerbinding xlink:from="#MainContainer"    xlink:label="MainContainer2[% focus_atom.key FILTER ucfirst %]Atom"    xlink:to="#[% focus_atom.key FILTER ucfirst %]Atom"/>
  </atomcontainerbindingslayout>
  [%- END -%]
</atomcontainerbindings>

<uribindings>
  <uribinding uri="/" class="Durian::Util::Frontpage"/>
</uribindings>

<classbindings>
[% FOREACH focus_atom = linkable %]
   <classbinding class="Durian::Model::[% focus_atom.key FILTER ucfirst %]" plugin="#[% focus_atom.key FILTER ucfirst %]Atom" rank="0"/>
[%- END -%]

</classbindings>

</Durian>
EOF

my $turnkey_template_tt2 = <<'EOF';
[% TAGS [- -] %]
[% MACRO renderpanel(panel,dbobject) BLOCK %]
  <!-- begin panel: [% panel.label %] -->
  <table border="0" width="[% panel.width %]" height="[% panel.height %]" bgcolor="[% panel.bgcolor %]" valign="top" cellpadding="[% panel.cellpadding %]" cellspacing="[% panel.cellspacing %]" align="[% panel.align %]" valign="[% panel.valign %]">
    <tr>
    [% FOREACH p = panel.containers %]
      [% IF p.can_render(panel) %]
        <td valign="top" class="[% p.class %]" align="[% panel.align %]" height="[% p.height || 1 %]" width="[% p.width %]">
          [% IF p.type == 'Container' %]
            [% renderpanel(p,dbobject) %]
          [% ELSE %]
            <table cellpadding="0" cellspacing="0" align="left" height="100%" width="100%">
              [% IF p.name %]
                <tr bgcolor="#4444FF" height="1">
                  <td><font color="#FFFFFF">[% p.name %][% IF panel.type == 'major' %]: [% dbobject.name %][% END %]</font></td>
                  <td align="right" width="0"><!--<nobr><img src="/images/v.gif"/><img src="/images/^.gif"/>[% IF p.delible == 'yes' %]<img src="/images/x.gif"/>[% END %]</nobr>--></td>
                </tr>
              [% END %]
              <tr><td colspan="2" bgcolor="#FFFFFF">
              <!-- begin atom: [% p.label %] -->
              <table cellpadding="0" cellspacing="0" align="left" height="100%" width="100%"><!-- [% ref(atom) %] [% ref(dbobject) %] -->
                [% renderatom(p,dbobject) %] <!-- used to be renderplugin(p,panel) -->
              </table>
            </table>
          [% END %]
        </td>
        [% IF panel.orientation == 'vertical' %]
          </tr><tr>
        [% END %]
      [% END %]
    [% END %]
    </tr>
  </table>
  <!-- end panel: [% panel.label %] -->
[% END %]
[% MACRO renderatom(atom, dbobject) SWITCH atom.name %]
  [- FOREACH node = linkable -]
    [% CASE '[- node.key FILTER ucfirst -]' %]
      [% render[- node.key FILTER ucfirst -]Atom(atom.render(dbobject)) %]
  [- END -]
    [% CASE DEFAULT %]
      [% renderlist(atom.render(dbobject)) %]
[% END %]
[- FOREACH node = linkable -]
[% MACRO render[- node.key FILTER ucfirst -]Atom(lstArr) BLOCK %]
  [% FOREACH record = lstArr %]
    [% fields = record.data %]
    [- pname = node.key FILTER ucfirst -]
    [- pkey = "Durian::Model::${pname}" -]
    [- FOREACH field = nodes.$pkey.columns_essential -]
      <tr><td><b>[- field -]</b></td><td>[% fields.[- field -] %]</td></tr>
    [- END -]
    [% id = record.id %]
    <tr><td><a href="?id=[% id %];class=Durian::Model::[- node.key FILTER ucfirst -]">Link</a></td><td></td></tr>
  [% END %]
[% END %]
[- END -]
[% MACRO renderlist(lstArr) BLOCK %]
  [%  FOREACH item = lstArr %]
    <tr>[% item %]</tr>
  [% END %]
[% END %]
EOF


sub translateForm
{
  my $t = shift;
  my $meta = shift;
#  my $output = shift;
  my $args = $t->producer_args;
  my $tt2     = $meta->{'template'};
  my $tt2Ref;

     if ($tt2 eq 'atom')     { $tt2Ref = \$turnkey_atom_tt2;     }
  elsif ($tt2 eq 'classdbi') { $tt2Ref = \$turnkey_dbi_tt2;      }
  elsif ($tt2 eq 'xml')      { $tt2Ref = \$turnkey_xml_tt2;      }
  elsif ($tt2 eq 'template') { $tt2Ref = \$turnkey_template_tt2; }
  else                       { die __PACKAGE__." didn't recognize your template option: $tt2" }

  my $config = {
      EVAL_PERL    => 1,               # evaluate Perl code blocks
  };

  # create Template object
  my $template = Template->new($config);

  my $result;
  # specify input filename, or file handle, text reference, etc.
  # process input template, substituting variables
  $template->process($tt2Ref, $meta, \$result) || die $template->error();
  return($result);
}

1;

# -------------------------------------------------------------------

=pod

=head1 NAME

SQL::Translator::Producer::Turnkey - create Turnkey classes from schema

=head1 SYNOPSIS

Creates output for use with the Turnkey project.

=head1 SEE ALSO

L<http://turnkey.sourceforge.net>.

=head1 AUTHORS

Allen Day E<lt>allenday@ucla.eduE<gt>
Ying Zhang E<lt>zyolive@yahoo.comE<gt>,
Brian O'Connor E<lt>brian.oconnor@excite.comE<gt>.
