package SQL::Translator::Producer::Turnkey;

# -------------------------------------------------------------------
# $Id: Turnkey.pm,v 1.45 2004-04-20 01:59:07 boconnor Exp $
# -------------------------------------------------------------------
# Copyright (C) 2002-4 SQLFairy Authors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
# 02111-1307  USA
# -------------------------------------------------------------------

use strict;
use vars qw[ $VERSION $DEBUG ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.45 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 1 unless defined $DEBUG;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Schema::Graph;
use SQL::Translator::Schema::Graph::HyperEdge;
use Log::Log4perl; Log::Log4perl::init('/etc/log4perl.conf');
use Data::Dumper;
$Data::Dumper::Maxdepth = 3;
use Template;

my %producer2dsn = (
    MySQL      => 'mysql',
    PostgreSQL => 'Pg',
    Oracle     => 'Oracle',
);

# -------------------------------------------------------------------
sub produce {
    my $log           = Log::Log4perl->get_logger('SQL.Translator.Producer.Turnkey');

    my $t             = shift;
	my $create        = undef;
    my $args          = $t->producer_args;
    my $no_comments   = $t->no_comments;
	my $baseclass     = $args->{'main_pkg_name'} || $t->format_package_name('DBI');
	my $graph         = SQL::Translator::Schema::Graph->new(translator => $t,
															baseclass => $baseclass
														   );

	my $parser_type   = (split /::/, $t->parser_type)[-1];

    local $DEBUG      = $t->debug;

	my %meta          = (
						 format_fk => $t->format_fk_name,
						 format_package => $t->format_package_name,
						 format_table => $t->format_table_name,
						 template  => $args->{'template'}      || '',
						 baseclass => $baseclass,
						 db_dsn    => $args->{'db_dsn'}       || '',
						 db_user   => $args->{'db_user'}       || '',
						 db_pass   => $args->{'db_pass'}       || '',
						 db_str    => $args->{'db_str'}        || '',
						 parser    => $t->parser_type,
						 producer  => __PACKAGE__,
						 dsn       => $args->{'dsn'} || sprintf( 'dbi:%s:_', $producer2dsn{ $parser_type }
																 ? $producer2dsn{ $parser_type }
																 : $parser_type
															   )
						 );

    #
    # create methods
    #
    # this code needs to move to Graph.pm
	foreach my $node_from ($graph->node_values){

	  next unless $node_from->table->is_data or !$node_from->table->is_trivial_link;

	  foreach my $cedge ( $node_from->compoundedges ){

		my $hyperedge = SQL::Translator::Schema::Graph::HyperEdge->new();

		my $node_to;
		foreach my $edge ($cedge->edges){
		  if($edge->thisnode->name eq $node_from->name){
			$hyperedge->vianode($edge->thatnode);

			if($edge->thatnode->name ne $cedge->via->name){
			  $node_to ||= $graph->node($edge->thatnode->table->name);
			}

			$hyperedge->push_thisnode($edge->thisnode);
			$hyperedge->push_thisfield($edge->thisfield);
			$hyperedge->push_thisviafield($edge->thatfield);

		  } else {
			if($edge->thisnode->name ne $cedge->via->name){
			  $node_to ||= $graph->node($edge->thisnode->table->name);
			}
			$hyperedge->push_thatnode($edge->thisnode);
			$hyperedge->push_thatfield($edge->thisfield);
			$hyperedge->push_thatviafield($edge->thatfield);
		  }
		  $log->debug($edge->thisfield->name);
		  $log->debug($edge->thatfield->name);
		}

		   if($hyperedge->count_thisnode == 1 and $hyperedge->count_thatnode == 1){ $hyperedge->type('one2one')   }
		elsif($hyperedge->count_thisnode  > 1 and $hyperedge->count_thatnode == 1){ $hyperedge->type('many2one')  }
		elsif($hyperedge->count_thisnode == 1 and $hyperedge->count_thatnode  > 1){ $hyperedge->type('one2many')  }
		elsif($hyperedge->count_thisnode  > 1 and $hyperedge->count_thatnode  > 1){ $hyperedge->type('many2many') }

		$log->debug($_) foreach sort keys %::SQL::Translator::Schema::Graph::HyperEdge::;

		#node_to won't always be defined b/c of multiple edges to a single other node
		if(defined($node_to)){
		  $log->debug($node_from->name);
		  $log->debug($node_to->name);

		  if(scalar($hyperedge->thisnode) > 1){
			$log->debug($hyperedge->type ." via ". $hyperedge->vianode->name);
			my $i = 0;
			foreach my $thisnode ( $hyperedge->thisnode ){
			  $log->debug($thisnode->name .' '.
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
	$meta{"nodes"} = $graph->node;
	return(translateForm($t, \%meta));
}

sub translateForm {
  my $t = shift;
  my $meta = shift;

  my $args = $t->producer_args;
  my $type = $meta->{'template'};

  my $template = Template->new({
                                PRE_CHOMP => 1,
                                POST_CHOMP => 0,
                                EVAL_PERL => 1
                               });

  my $tt2;
  $tt2 = template($type);
  my $result;

  if($type eq 'atomtemplate'){
    my %result;
    foreach my $node (values %{ $meta->{'nodes'} }){
      $result = '';
      my $param = { node => $node };
      $template->process(\$tt2, $param, \$result) || die $template->error();
      $result =~ s/^\s*(.+)\s*$/$1/s;
      next unless $result;
      $result{$node->table->name} = $result;
    }
    return \%result;
  } else {
    $template->process(\$tt2, $meta, \$result) || die $template->error();
  }

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
Brian O\'Connor E<lt>boconnor@ucla.comE<gt>.

=cut

sub template {
  my $type = shift;

###########################################
# Here documents for the tt2 templates    #
###########################################

  if($type eq 'dbi'){
	return <<EOF;
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
[% #printHasFriendly(node) %]
[% END %]
[% MACRO printPKAccessors(array, name) BLOCK %]
#
# Primary key accessors
#

[% FOREACH item = array %]
[% IF item != "id" %]sub id { shift->[% item %] }[% END %]
[% IF item != name %]sub [% name %] { shift->[% item %] }[% END %]
[% END %]

[% END %]
[% MACRO printHasA(edges, name) BLOCK %]
[% FOREACH edge = edges %]
[% IF loop.first() %]
#
# Has A
#

[% END %]
  [% IF edge.type == 'import' %]
[% node.name %]->has_a([% edge.thisfield.name %] => '[% edge.thatnode.name %]');
    [% IF node.has(edge.thatnode.name) < 2 %]
sub [% edge.thatnode.table.name %] { return shift->[% edge.thisfield.name %] }
    [% ELSE %]
sub [% format_fk(edge.thisnode.table.name,edge.thisfield.name) %] { return shift->[% edge.thisfield.name %] }
    [% END %]
  [% END %]
[% END %]

[% END %]

[% MACRO printHasMany(edges, node) BLOCK %]
[% FOREACH edge = edges %]
[% IF loop.first() %]
#
# Has Many
#

[% END %]
  [% IF edge.type == 'export' %]
[% node.name %]->has_many('[% edge.thatnode.table.name %]_[% edge.thatfield.name %]', '[% edge.thatnode.name %]' => '[% edge.thatfield.name %]');
    [% IF node.via(edge.thatnode.name) >= 1 %]
sub [% edge.thatnode.table.name %]_[% format_fk(edge.thatnode.table.name,edge.thatfield.name) %]s { return shift->[% edge.thatnode.table.name %]_[% edge.thatfield.name %] }
    [% ELSIF edge.thatnode.table.is_data %]
      [% IF node.edgecount(edge.thatnode.name) > 1 %]
sub [% edge.thatnode.table.name %]_[% format_fk(edge.thatnode.name,edge.thatfield.name) %]s { return shift->[% edge.thatnode.table.name %]_[% edge.thatfield.name %] }
      [% ELSE %]
sub [% edge.thatnode.table.name %]s { return shift->[% edge.thatnode.table.name %]_[% edge.thatfield.name %] }
      [% END %]
    [% END %]

  [% END %]
[% END %]

[% END %]
[% MACRO printHasCompound(cedges,hedges,name) BLOCK %]
[% FOREACH cedge = cedges %]
[% IF loop.first() %]
#
# Has Compound Many
#
[% END %]
[% FOREACH edge = cedge.edges %]
  [% NEXT IF edge.thisnode.name != name %]
sub [% cedge.via.table.name %]_[% format_fk(edge.thatnode.table.name,edge.thatfield.name) %]s { return shift->[% cedge.via.table.name %]_[% edge.thatfield.name %] }
[% END %]
[% END %]

[% seen = 0 %]
[% FOREACH h = hedges %]
  [% NEXT UNLESS h.type == 'one2one' %]
[% IF seen == 0 ; seen = 1 %]########## one2one ###########[% END %]
sub [% h.thatnode.table.name %]s { my \$self = shift; return map \$_->[% h.thatviafield.name %], \$self->[% h.vianode.table.name %]_[% h.thisviafield.name %] }
[% END %]

[% seen = 0 %]
[% FOREACH h = hedges %]
  [% NEXT UNLESS h.type == 'one2many' %]
[% IF seen == 0 ; seen = 1 %]########## one2many ##########[% END %]
  [% thisnode = h.thisnode_index(0) %]
  [% i = 0 %]
  [% FOREACH thatnode = h.thatnode %]
    [% NEXT UNLESS h.thisviafield_index(i).name %]
#[% thisnode.name %]::[% h.thisfield_index(0).name %] -> [% h.vianode.name %]::[% h.thisviafield_index(i).name %] ... [% h.vianode.name %]::[% h.thatviafield_index(0).name %] <- [% h.thatnode_index(0).name %]::[% h.thatfield_index(0).name %]
sub [% h.vianode.table.name %]_[% format_fk(h.vianode,h.thatviafield_index(0).name) %]s { my \$self = shift; return map \$_->[% h.thatviafield_index(0).name %], \$self->[% h.vianode.table.name %]_[% h.thisviafield_index(i).name %] }
    [% i = i + 1 %]
  [% END %]
[% END %]

[% seen = 0 %]
[% FOREACH h = hedges %]
  [% NEXT UNLESS h.type == 'many2one' %]
[% IF seen == 0 ; seen = 1 %]########## many2one ##########[% END %]
  [% i = 0 %]
  [% FOREACH thisnode = h.thisnode %]
#[% thisnode.name %]::[% h.thisfield_index(0).name %] -> [% h.vianode.name %]::[% h.thisviafield_index(i).name %] ... [% h.vianode.name %]::[% h.thatviafield_index(0).name %] <- [% h.thatnode_index(0).name %]::[% h.thatfield_index(0).name %]
sub [% h.vianode.table.name %]_[% format_fk(h.vianode,h.thisviafield_index(i).name) %]_[% format_fk(h.vianode,h.thatviafield_index(0).name) %]s { my \$self = shift; return map \$_->[% h.thatviafield_index(0).name %], \$self->[% h.vianode.table.name %]_[% h.thisviafield_index(i).name %] }
    [% i = i + 1 %]
  [% END %]
[% END %]

[% seen = 0 %]
[% FOREACH h = hedges %]
  [% NEXT UNLESS h.type == 'many2many' %]
[% IF seen == 0 ; seen = 1 %]########## many2many #########[% END %]
  [% i = 0 %]
  [% FOREACH thisnode = h.thisnode %]
    [% j = 0 %]
    [% FOREACH thatnode = h.thatnode %]
#[% thisnode.name %]::[% h.thisfield_index(i).name %] -> [% h.vianode.name %]::[% h.thisviafield_index(i).name %] ... [% h.vianode.name %]::[% h.thatviafield_index(j).name %] <- [% h.thatnode_index(j).name %]::[% h.thatfield_index(j).name %]
sub [% h.vianode.table.name %]_[% format_fk(h.vianode,h.thisviafield_index(i).name) %]_[% format_fk(h.vianode,h.thatviafield_index(j).name) %]s { my \$self = shift; return map \$_->[% h.vianode.table.name %]_[% format_fk(h.vianode,h.thatviafield_index(j).name) %]s, \$self->[% h.vianode.table.name %]_[% format_fk(h.vianode,h.thisviafield_index(i).name) %]s }
      [% j = j + 1 %]
    [% END %]
    [% i = i + 1 %]
  [% END %]
[% END %]

[% END %]
[% MACRO printHasFriendly(node) BLOCK %]
#
# Has Friendly
#
#FIXME, why aren't these being generated?

[% END %]
[% MACRO printList(array) BLOCK %][% FOREACH item = array %][% item %] [% END %][% END %]
package [% baseclass %];

# Created by SQL::Translator::Producer::Turnkey
# Template used: classdbi

use strict;
use Data::Dumper
no warnings 'redefine';
use base qw(Class::DBI::Pg);

[% baseclass %]->set_db('Main', '[% db_dsn  %]', '[% db_user %]', '[% db_pass %]');
sub search_ilike { shift->_do_search(ILIKE => [% "\@\_" %] ) }

# debug method
sub dump {
  my $self = shift;
  my %arg  = @_;
  $arg{indent} ||= 1;
  $arg{depth} ||= 2;
  $Data::Dumper::Maxdepth = $arg{depth} if defined $arg{depth};
  $Data::Dumper::Indent = $arg{indent} if defined $arg{indent};
  return(Dumper($obj));
}

[% FOREACH node = nodes %]
    [% printPackage(node.value) %]
[% END %]
EOF
}


elsif($type eq 'atom'){

  return <<'EOF';
[% ###### DOCUMENT START ###### %]

[% FOREACH node = nodes %]
[% IF !node.value.is_trivial_link %]

##############################################

package Turnkey::Atom::[% node.value.name FILTER replace "Turnkey::Model::", "" %];

[% pname = node.value.name FILTER replace "Turnkey::Model::", "" %]

use base qw(Turnkey::Atom);
use Data::Dumper;

sub can_render {
	return 1;
}

sub render {
	my $self = shift;
	my $dbobject = shift;

	# Assumption here that if it's not rendering on it's own dbobject
	# then it's a list. This will be updated when AtomLists are implemented -boconnor
	if(ref($dbobject) eq 'Turnkey::Model::[% pname %]') {
		$self->focus('yes');
		return(_render_record($dbobject));
	}
	else { return(_render_list($dbobject)); }
}

sub _render_record {
	my $dbobject = shift;
	my @output = ();
	my $row = {};
	my $field_hash = {};

	#data
	[% FOREACH value = node.value.data_fields %]
	[% IF value != 1 %]
	$field_hash->{[% value.key %]} = $dbobject->[% value.key %]();
		[% END %]
	[% END %]

	#keys
	[% FOREACH value = node.value.edges %]
	[% NEXT IF value.type != 'import' %]
	$field_hash->{[% value.thisfield.name %]} = $dbobject->[% value.thisfield.name %]();
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
	foreach my $object (@objects){
		my $row = {};
		my $field_hash = {};

		#data
	[% FOREACH value = node.value.data_fields %]
		[% IF value != 1 %]
		$field_hash->{[% value.key %]} = $object->[% value.key %]();
		[% END %]
	[% END %]

		#keys
		[% FOREACH value = node.value.edges %]
		[% NEXT IF value.type != 'import' %]
		$field_hash->{[% value.thisfield.name %]} = $object->[% value.thisfield.name %]();
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
[% END %]
EOF

} elsif($type eq 'xml'){
  return <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Turnkey SYSTEM "Turnkey.dtd">
<Turnkey>

<!-- The basic layout is fixed -->
  <container orientation="vertical" type="Container" label="RootContainer">
	<container orientation="horizontal" type="Container" label="MiddleContainer">
	  <container align="center" class="leftbar" orientation="vertical" type="minor" label="MidLeftContainer"/>
	  <container orientation="vertical" type="major" label="MainContainer"/>
	</container>
  </container>

<!-- Atom Classes -->
[% FOREACH node = nodes %]
[% IF !node.value.is_trivial_link %]
  <atom class="[% format_table(node.key) %]" name="[% format_table(node.key) %]" label="[% format_table(node.key) %]Atom"/>
[%- END -%]
[% END %]

<!-- Atom Bindings -->
<atomatombindings>
[% FOREACH focus_atom = nodes %]
[% IF !focus_atom.value.is_trivial_link %]
  [% FOREACH link_atom = focus_atom.value.hyperedges %]
  <atomatombinding from="#[% format_table(focus_atom.key) %]Atom" to="#[% format_table(link_atom.thatnode.table.name) %]Atom" label="[% format_table(focus_atom.key) %]Atom2[% format_table(link_atom.thatnode.table.name) %]Atom"/>
  [%- END -%]
  [% previous = "" %]
  [% FOREACH link_atom = focus_atom.value.edges %]
  [% IF link_atom.type == 'export' && previous != link_atom.thatnode.table.name && link_atom.thatnode.table.name != "" %]
  <atomatombinding from="#[% format_table(focus_atom.key) %]Atom" to="#[% format_table(link_atom.thatnode.table.name) %]Atom" label="[% format_table(focus_atom.key) %]Atom2[% format_table(link_atom.thatnode.table.name) %]Atom"/>
  [% previous = link_atom.thatnode.table.name %]
  [% END %]
 [%- END %]
[%- END -%]
[% END %]
</atomatombindings>

<layouts>
[% FOREACH focus_atom = nodes %]
[% IF !focus_atom.value.is_trivial_link %]
  <layout label="[% format_table(focus_atom.key) %]">
  [% FOREACH link_atom = focus_atom.value.hyperedges %]
    <placement from="#MidLeftContainer" label="MidLeftContainer2[% format_table(link_atom.thatnode.table.name) %]Atom"  to="#[% format_table(link_atom.thatnode.table.name) %]Atom"/>
  [%- END%]
  [% previous = "" %]
  [% FOREACH link_atom = focus_atom.value.edges %]
  [% IF link_atom.type == 'export' && previous != link_atom.thatnode.table.name %]
    <placement from="#MidLeftContainer" label="MidLeftContainer2[% format_table(link_atom.thatnode.table.name) %]Atom" to="#[% format_table(link_atom.thatnode.table.name) %]Atom"/>
  [% previous = link_atom.thatnode.table.name %]
  [% END %]
  [%- END %]
    <placement from="#MainContainer" label="MainContainer2[% format_table(focus_atom.key) %]Atom" to="#[% format_table(focus_atom.key) %]Atom"/>
  </layout>
  [%- END %]
[% END %]
</layouts>

<uribindings>
  <uribinding uri="/" class="Turnkey::Util::Frontpage"/>
</uribindings>

<classbindings>
[% FOREACH focus_atom = nodes %]
[% IF !focus_atom.value.is_trivial_link %]
   <classbinding class="[% format_table(focus_atom.key) %]" plugin="#[% format_table(focus_atom.key) %]Atom" rank="0"/>
[%- END -%]
[% END %]
</classbindings>

</Turnkey>
EOF

} elsif($type eq 'template'){
  return <<'EOF';
[% TAGS [- -] %]
[% MACRO renderpanel(panel,name,dbobject) BLOCK %]
  <!-- begin panel: [% panel.label %] -->
    [% FOREACH p = panel.containers %]
      [% IF p.can_render(panel) %]
          [% IF p.type == 'Container' %]
            [% renderpanel(p,name,dbobject) %]
          [% ELSE %]
            [% IF p.type == 'major' %]
             <div class="middle"><div class="column-in">
               [% IF name %]
                   <div class="middle-header">[% name %]</div>
               [% END %]
              <!-- begin atom: [% p.label %] -->
              <table cellpadding="0" cellspacing="0" align="left" height="100%" width="100%"><!-- [% ref(atom) %] [% ref(dbobject) %] -->
                [% renderatom(name,dbobject,p.containers[0]) %]
              </table>
              </div></div>
              <div class="cleaner"></div>
            [% ELSIF p.type == 'minor' %]
             <div class="left"><div class="column-in">
               [% FOREACH atom = p.containers %]
               <div class="left-item">
               [% IF name %]
                   [% linkname = ref(p.containers[0]) %]
                   <div class="box-header">[% atom.name | replace('Turnkey::Atom::', '') %]</div>
               [% END %]
              <!-- begin atom: [% p.label %] -->
              <table cellpadding="0" cellspacing="0" align="left" height="100%" width="100%"><!-- [% ref(atom) %] [% ref(dbobject) %] -->
                [% renderatom(name,dbobject,atom) %]
              </table>
              </div>
              [% END %]
              </div></div>
            [% END %]
          [% END %]
        [% IF panel.orientation == 'vertical' %]
        [% END %]
      [% END %]
    [% END %]

  <!-- end panel: [% panel.label %] -->

[% END %]
[% BLOCK make_linked_dbobject %]
    [% PERL %]
      $stash->set(linked_dbobject => [% class %]->retrieve([% id %]));
    [% END %]
[% END %]
[% MACRO obj2link(obj) SWITCH ref(obj) %]
  [% CASE '' %]
    [% obj %]
  [% CASE DEFAULT %]
    [% IF obj.name %]
      <a href="[% obj2url(obj) %]">[% obj.name %]</a>
    [% ELSE %]
        <a href="[% obj2url(obj) %]">[% obj %]</a>
    [% END %]
[% END %]
[% MACRO obj2url(obj) SWITCH obj %]
  [% CASE DEFAULT %]
    /[% ref(obj) | replace('.+::','') %]/[% obj %]
[% END %]
[% MACRO obj2desc(obj) SWITCH ref(obj) %]
  [% CASE '' %]
    [% obj %]
  [% CASE DEFAULT %]
    [% IF obj.value %]
      [% obj.value %]
    [% ELSE %]
      [% obj %]
    [% END %]
[% END %]
[% MACRO renderatom(name, dbobject, atom) SWITCH name %]
  [- FOREACH node = nodes -]
  [- IF !node.value.is_trivial_link -]
    [% CASE '[- format_table(node.key) -]' %]
      [% INCLUDE [- node.key -].tt2 %]
  [- END -]
  [- END -]
    [% CASE DEFAULT %]
      [% renderlist(atom.render(dbobject)) %]
[% END %]
[% MACRO renderlist(lstArr) BLOCK %]
   <div class="left-item"><ul>
  [% FOREACH item = lstArr %]
    [% class = ref(atom) | replace('::Atom::', '::Model::') %]
    [% id = item.id %]
    [% PROCESS make_linked_dbobject %]
    <li class="minorfocus">[% obj2link(linked_dbobject) %]</li>
  [% END %]
   </ul></div>
[% END %]
EOF

} elsif($type eq 'atomtemplate') {
  return <<'EOF';
[%- TAGS [- -] -%]
[-- IF !node.is_trivial_link --]
[% records  = atom.render(dbobject) %]
[% rowcount = 0 %]
[% IF atom.focus == "yes" %]
[% FOREACH record = records %]
[% fields = record.data %]
  <table>
  [- FOREACH field = node.data_fields -]
  [- IF field != "1" -]
    <tr><td class="dbfieldname">[- field.key -]</td><td class="dbfieldvalue">[% obj2link(fields.[- field.key -]) %]</td></tr>
  [- END -]
  [- END -]
  [- FOREACH field = node.edges -]
  [- NEXT IF field.type != 'import' -]
    <tr><td class="dbfieldname">[- field.thisfield.name -]</td><td class="dbfieldvalue">[% obj2link(fields.[- field.thisfield.name -]) %]</td></tr>
  [- END -]
  [% IF (rowcount > 1) %] <tr><td colspan="2"><hr></td></tr> [% END %]
  [% rowcount = rowcount + 1 %]
  </table>
[% END %]
[% ELSE %]
  <ul>
  [% FOREACH record = atom.render(dbobject) %]
    [% class = ref(atom) | replace('::Atom::', '::Model::') %]
    [% id = record.id #needed by make_linked_dbobject macro %]
    [% PROCESS make_linked_dbobject %]
    <li class="minorfocus">[% obj2link(linked_dbobject) %]</li>
  [% END %]
   </ul>
[% END %]
[- END -]
EOF

}
}

1;
