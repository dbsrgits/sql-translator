package SQL::Translator::Producer::Turnkey;

# -------------------------------------------------------------------
# $Id: Turnkey.pm,v 1.13 2004-01-02 00:17:10 allenday Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Allen Day <allenday@ucla.edu>,
#   Brian O'Connor <brian.oconnor@excite.com>.
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
$VERSION = sprintf "%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 1 unless defined $DEBUG;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Schema::Graph;
use SQL::Translator::Schema::Graph::HyperEdge;
use Log::Log4perl; Log::Log4perl::init('/etc/log4perl.conf');
use Data::Dumper;
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
						 template  => $args->{'template'}      || '',
						 baseclass => $baseclass,
						 db_user   => $args->{'db_user'}       || '',
						 db_pass   => $args->{'db_pass'}       || '',
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


#"Node Data:\n";
#warn Dumper $meta->{nodes};
#exit;

  my $args = $t->producer_args;
  my $type = $meta->{'template'};
  my $tt2;
  $tt2 = template($type);
  my $template = Template->new({
								PRE_CHOMP => 1,
								POST_CHOMP => 0,
								EVAL_PERL => 1
							   });

  my $result;
  $template->process(\$tt2, $meta, \$result) || die $template->error();
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
Brian O\'Connor E<lt>brian.oconnor@excite.comE<gt>.

=cut

sub template {
  my $type = shift;

###########################################
# Here documents for the tt2 templates    #
###########################################

  if($type eq 'dbi'){
	return <<EOF;

# MACRO

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

# MACRO

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
#
# Has Many
#

[% FOREACH edge = edges %]
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
#
# Has Compound Many
#
[% FOREACH cedge = cedges %]
[% FOREACH edge = cedge.edges %]
  [% NEXT IF edge.thisnode.name != name %]
sub [% cedge.via.table.name %]_[% format_fk(edge.thatnode.table.name,edge.thatfield.name) %]s { return shift->[% cedge.via.table.name %]_[% edge.thatfield.name %] }
[% END %]
[% END %]

[% FOREACH h = hedges %]
########## [% h.type %] ##########
  [% IF h.type == 'one2one' %]
sub [% h.thatnode.table.name %]s { my \$self = shift; return map \$_->[% h.thatviafield.name %], \$self->[% h.vianode.table.name %]_[% h.thisviafield.name %] }

  [% ELSIF h.type == 'one2many' %]
    [% thisnode = h.thisnode_index(0) %]
    [% i = 0 %]
    [% FOREACH thatnode = h.thatnode %]
#[% thisnode.name %]::[% h.thisfield_index(0).name %] -> [% h.vianode.name %]::[% h.thisviafield_index(i).name %] ... [% h.vianode.name %]::[% h.thatviafield_index(0).name %] <- [% h.thatnode_index(0).name %]::[% h.thatfield_index(0).name %]
sub [% h.vianode.table.name %]_[% format_fk(h.vianode,h.thatviafield_index(0).name) %]s { my \$self = shift; return map \$_->[% h.thatviafield_index(0).name %], \$self->[% h.vianode.table.name %]_[% h.thisviafield_index(i).name %] }
      [% i = i + 1 %]
    [% END %]

  [% ELSIF h.type == 'many2one' %]
    [% i = 0 %]
    [% FOREACH thisnode = h.thisnode %]
#[% thisnode.name %]::[% h.thisfield_index(0).name %] -> [% h.vianode.name %]::[% h.thisviafield_index(i).name %] ... [% h.vianode.name %]::[% h.thatviafield_index(0).name %] <- [% h.thatnode_index(0).name %]::[% h.thatfield_index(0).name %]
sub [% h.vianode.table.name %]_[% format_fk(h.vianode,h.thisviafield_index(i).name) %]_[% format_fk(h.vianode,h.thatviafield_index(0).name) %]s { my \$self = shift; return map \$_->[% h.thatviafield_index(0).name %], \$self->[% h.vianode.table.name %]_[% h.thisviafield_index(i).name %] }
      [% i = i + 1 %]

    [% END %]

  [% ELSIF h.type == 'many2many' %]
    [% i = 0 %]
    [% FOREACH thisnode = h.thisnode %]
      [% j = 0 %]
      [% FOREACH thatnode = h.thatnode %]
#[% thisnode.name %]::[% h.thisfield_index(i).name %] -> [% h.vianode.name %]::[% h.thisviafield_index(i).name %] ... [% h.vianode.name %]::[% h.thatviafield_index(j).name %] <- [% h.thatnode_index(j).name %]::[% h.thatfield_index(j).name %]
sub [% h.vianode.table.name %]_[% format_fk(h.vianode,h.thisviafield_index(i).name) %]_[% format_fk(h.vianode,h.thatviafield_index(j).name) %]s { my \$self = shift; return map \$_->[% %], \$self->[% %] }
        [% j = j + 1 %]

      [% END %]
      [% i = i + 1 %]
    [% END %]
  [% END %]
[% END %]

[% END %]

[% MACRO printHasFriendly(node) BLOCK %]
#
# Has Friendly
#

[% END %]

[% MACRO printList(array) BLOCK %][% FOREACH item = array %][% item %] [% END %][% END %]
package [% baseclass %];

# Created by SQL::Translator::Producer::Turnkey
# Template used: classdbi

use strict;
use base qw(Class::DBI::Pg);

[% baseclass %]->set_db('Main', '[% db_str  %]', '[% db_user %]', '[% db_pass %]');

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
		return(_render_record($dbobject));
	}
	else { return(_render_list($dbobject)); }
}

sub _render_record {
	my $dbobject = shift;
	my @output = ();
	my $row = {};
	my $field_hash = {};
	[% FOREACH value = node.value.data_fields %]
	[% IF value != 1 %]
    $field_hash->{[% value %]} = $dbobject->[% value %]();
    [% END %]
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
	    [% FOREACH value = node.value.data_fields %]
	    [% IF value != 1 %]
        $field_hash->{[% value %]} = $object->[% value %]();
        [% END %]
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
  <container bgcolor="#FFFFFF" cellpadding="0" cellspacing="0" height="90%" orientation="vertical" type="root" width="100%" xlink:label="RootContainer">
	<container cellpadding="3" cellspacing="0" orientation="horizontal" type="container" height="100%" width="100%" xlink:label="MiddleContainer">
	  <container align="center" cellpadding="2" cellspacing="0" class="leftbar" orientation="vertical" type="minor" width="0%" xlink:label="MidLeftContainer"/>
	  <container cellpadding="0" cellspacing="0" orientation="vertical" width="100%" type="major" xlink:label="MainContainer"/>
	</container>
  </container>

<!-- Atom Classes -->
[% FOREACH node = nodes %]
[% IF !node.value.is_trivial_link %]
  <atom class="Turnkey::Atom::[% node.key FILTER ucfirst %]"  name="[% node.key FILTER ucfirst %]" xlink:label="[% node.key FILTER ucfirst %]Atom"/>
[%- END -%]
[% END %]

<!-- Atom Bindings -->
<atomatombindings>
[% FOREACH focus_atom = nodes %]
[% IF !focus_atom.value.is_trivial_link %]
  [% FOREACH link_atom = focus_atom.value.hyperedges %]
  <atomatombinding xlink:from="#[% focus_atom.key FILTER ucfirst %]Atom" xlink:to="#[% link_atom.thatnode.table.name FILTER ucfirst %]Atom" xlink:label="[% focus_atom.key FILTER ucfirst %]Atom2[% link_atom.thatnode.table.name FILTER ucfirst %]Atom"/>
  [%- END -%]
  [% previous = "" %]
  [% FOREACH link_atom = focus_atom.value.edges %]
  [% IF link_atom.type == 'export' && previous != link_atom.thatnode.table.name && link_atom.thatnode.table.name != "" %]
  <atomatombinding xlink:from="#[% focus_atom.key FILTER ucfirst %]Atom" xlink:to="#[% link_atom.thatnode.table.name FILTER ucfirst %]Atom" xlink:label="[% focus_atom.key FILTER ucfirst %]Atom2[% link_atom.thatnode.table.name FILTER ucfirst %]Atom"/>
  [% previous = link_atom.thatnode.table.name %]
  [% END %]
 [%- END %]
[%- END -%]
[% END %]
</atomatombindings>

<atomcontainerbindings>
[% FOREACH focus_atom = nodes %]
[% IF !focus_atom.value.is_trivial_link %]
  <atomcontainerbindingslayout xlink:label="Turnkey::Model::[% focus_atom.key FILTER ucfirst %]">
  [% FOREACH link_atom = focus_atom.value.hyperedges %]
    <atomcontainerbinding xlink:from="#MidLeftContainer" xlink:label="MidLeftContainer2[% link_atom.thatnode.table.name FILTER ucfirst %]Atom"  xlink:to="#[% link_atom.thatnode.table.name FILTER ucfirst %]Atom"/>
  [%- END%]
  [% previous = "" %]
  [% FOREACH link_atom = focus_atom.value.edges %]
  [% IF link_atom.type == 'export' && previous != link_atom.thatnode.table.name %]
    <atomcontainerbinding xlink:from="#MidLeftContainer" xlink:label="MidLeftContainer2[% link_atom.thatnode.table.name FILTER ucfirst %]Atom"  xlink:to="#[% link_atom.thatnode.table.name FILTER ucfirst %]Atom"/>
  [% previous = link_atom.thatnode.table.name %]
  [% END %]
  [%- END %]
    <atomcontainerbinding xlink:from="#MainContainer"    xlink:label="MainContainer2[% focus_atom.key FILTER ucfirst %]Atom"    xlink:to="#[% focus_atom.key FILTER ucfirst %]Atom"/>
  </atomcontainerbindingslayout>
  [%- END %]
[% END %]
</atomcontainerbindings>

<uribindings>
  <uribinding uri="/" class="Turnkey::Util::Frontpage"/>
</uribindings>

<classbindings>
[% FOREACH focus_atom = nodes %]
[% IF !focus_atom.value.is_trivial_link %]
   <classbinding class="Turnkey::Model::[% focus_atom.key FILTER ucfirst %]" plugin="#[% focus_atom.key FILTER ucfirst %]Atom" rank="0"/>
[%- END -%]
[% END %]
</classbindings>

</Turnkey>
EOF

} elsif($type eq 'template'){
  return <<'EOF';
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
  [- FOREACH node = nodes -]
  [- IF !node.value.is_trivial_link -]
    [% CASE '[- node.key FILTER ucfirst -]' %]
      [% render[- node.key FILTER ucfirst -]Atom(atom.render(dbobject)) %]
  [- END -]
  [- END -]
    [% CASE DEFAULT %]
      [% renderlist(atom.render(dbobject)) %]
[% END %]
[- FOREACH node = nodes -]
[- IF !node.value.is_trivial_link -]
[% MACRO render[- node.key FILTER ucfirst -]Atom(lstArr) BLOCK %]
  [% FOREACH record = lstArr %]
    [% fields = record.data %]
    [- pname = node.key FILTER ucfirst -]
    [- pkey = "Turnkey::Model::${pname}" -]
    [- FOREACH field = node.value.data_fields -]
    [- IF field != "1" -]
      <tr><td><b>[- field -]</b></td><td>[% fields.[- field -] %]</td></tr>
    [- END -]
    [- END -]
    [% id = record.id %]
    <tr><td><a href="?id=[% id %];class=Durian::Model::[- node.key FILTER ucfirst -]">Link</a></td><td></td></tr>
  [% END %]
[% END %]
[- END -]
[- END -]
[% MACRO renderlist(lstArr) BLOCK %]
  [%  FOREACH item = lstArr %]
    <tr>[% item %]</tr>
  [% END %]
[% END %]
EOF

1;

}
}
