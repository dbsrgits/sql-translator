package Turnkey::Package;

use strict;
use Class::MakeMethods::Template::Hash (
  new => [ 'new' ],
  'array' => [ qw( many ) ],
  hash_of_arrays => [ qw( one2one one2many many2one many2many) ],
  scalar => [ qw( base name order primary_key primary_key_accessor table) ],
);


#  get_set => [ qw(order base name table primary_key primary_key_accessor) ],
#  new_with_init => 'new',
#;

sub init {
}

1;

package SQL::Translator::Producer::Turnkey;

# -------------------------------------------------------------------
# $Id: Turnkey.pm,v 1.4 2003-08-29 08:25:31 allenday Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Allen Day <allenday@ucla.edu>,
#                    Brian O'Connor <boconnor@ucla.edu>,
#                    Ying Zhang <zyolive@yahoo.com>
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
$VERSION = sprintf "%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/;
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
    local $DEBUG      = $t->debug;
    my $no_comments   = $t->no_comments;
    my $schema        = $t->schema;
    my $args          = $t->producer_args;
    my $db_user       = $args->{'db_user'} || '';
    my $db_pass       = $args->{'db_pass'} || '';
    my $main_pkg_name = $args->{'main_pkg_name'} ||
	                    $t->format_package_name('DBI');
    my $header        = header_comment(__PACKAGE__, "# ");
    my $parser_type   = ( split /::/, $t->parser_type )[-1];
    my $from          = $CDBI_auto_pkgs{ $parser_type } || '';
    my $dsn           = $args->{'dsn'} || sprintf( 'dbi:%s:_',
                            $CDBI_auto_pkgs{ $parser_type }
                            ? $CDBI_auto_pkgs{ $parser_type } : $parser_type
                        );
    my $sep           = '# ' . '-' x 67;

    #
    # Identify "link tables" (have only PK and FK fields).
    #
    my %linkable;
    my %linktable;
	my %packages;
	my $order;

	#
	# build package objects
	#
	foreach my $table ($schema->get_tables){
	  die __PACKAGE__." table ".$table->name." doesn't have a primary key!" unless $table->primary_key;
	  die __PACKAGE__." table ".$table->name." can't have a composite primary key!" if ($table->primary_key->fields)[1];


	  my $package = Turnkey::Package->new();
	  $packages{ $table->name } = $package;

	  $package->order( ++$order );
	  $package->name( $t->format_package_name($table->name) );
	  $package->base( $main_pkg_name );
	  $package->table( $table );
	  $package->primary_key( ($table->primary_key->fields)[0] );
	  # Primary key may have a differenct accessor method name
	  $package->primary_key_accessor(
									 defined($t->format_pk_name) ? $t->format_pk_name->( $package->name, $package->primary_key )
									                             : undef
									);

	  foreach my $field ($table->get_fields){
		next unless $field->is_foreign_key;

		$package->push_many( $field->foreign_key_reference->reference_table );
	  }
	}

	#
	# identify FK relationships
	#
	foreach my $maylink ( $schema->get_tables ){
	  foreach my $left ($schema->get_tables){
		foreach my $right ($schema->get_tables){

		  next if $left->name eq $right->name;

		  my $lpackage = $packages{$left->name};
		  my $rpackage = $packages{$right->name};

		  my($link,$lconstraints,$rconstraints) = @{ $maylink->can_link($left,$right) };
warn $left->name, "\t", $maylink->name, "\t", $right->name if $link ne '0';

		  #one FK to one FK
		  if( $link eq 'one2one'){
warn "\tone2one";
			$lpackage->one2one_push($rpackage->name, [$rpackage, $maylink]);
			$rpackage->one2one_push($lpackage->name, [$lpackage, $maylink]);

		  #one FK to many FK
		  } elsif( $link eq 'one2many'){
warn "\tone2many";
			$lpackage->one2many_push($rpackage->name, [$rpackage, $maylink]);
			$rpackage->many2one_push($lpackage->name, [$lpackage, $maylink]);

		  #many FK to one FK
		  } elsif( $link eq 'many2one'){
warn "\tmany2one";
			$lpackage->many2one_push($rpackage->name, [$rpackage, $maylink]);
			$rpackage->one2many_push($lpackage->name, [$lpackage, $maylink]);

		  #many FK to many FK
		  } elsif( $link eq 'many2many'){
warn "\tmany2many";
warn $left->name;
warn $right->name;
			$lpackage->many2many_push($rpackage->name, [$rpackage, $maylink]);
			$rpackage->many2many_push($lpackage->name, [$lpackage, $maylink]);

		  } else {
			#not linkable
		  }
		}
	  }
	}

    #
    # create methods
    #
	foreach my $package_from (values %packages){
	  next unless $package_from->table->is_data;

	  my %linked;

	  my %o2o = $package_from->one2one;
warn Dumper(%o2o);
	  my %o2m = $package_from->one2many;
warn Dumper(%o2m);
	  my %m2o = $package_from->many2one;
warn Dumper(%m2o);
	  my %m2m = $package_from->many2many;
warn Dumper(%m2m);

	  foreach my $package_to (keys %{ $package_from->one2one }){
		$package_to = $packages{$package_to};
		foreach my $bridge ( $package_from->one2one($package_to->name) ){
		  $bridge->[3] = $t->format_fk_name ? $t->format_fk_name->(
																 $package_from->one2one($package_to->name)->[1]->name,
																 $package_to->primary_key
																).'s'
									      : $package_from->one2one($package_to->name)->[1]->name .'_'.
									        $package_to->primary_key .'s';
		}
	  }

	  foreach my $package_to (keys %{ $package_from->one2many }){
		$package_to = $packages{$package_to};
		foreach my $bridge ( $package_from->one2many($package_to->name) ){
		  $bridge->[3] = $t->format_fk_name ? $t->format_fk_name->(
																 $package_from->one2many($package_to->name)->[1]->name,
																 $package_to->primary_key
																).'s'
									      : $package_from->one2many($package_to->name)->[1]->name .'_'.
									        $package_to->primary_key .'s';
		}
	  }

	  foreach my $package_to (keys %{ $package_from->many2one }){
		$package_to = $packages{$package_to};
		foreach my $bridge ( $package_from->many2one($package_to->name) ){
		  $bridge->[3] = $t->format_fk_name ? $t->format_fk_name->(
																 $package_from->many2one($package_to->name)->[1]->name,
																 $package_to->primary_key
																).'s'
									      : $package_from->many2one($package_to->name)->[1]->name .'_'.
									        $package_to->primary_key .'s';
		}
	  }

	  foreach my $package_to (keys %{ $package_from->many2many }){
		$package_to = $packages{$package_to};
		foreach my $bridge ( $package_from->many2many($package_to->name) ){
		  $bridge->[3] = $t->format_fk_name ? $t->format_fk_name->(
																 $package_from->many2many($package_to->name)->[1]->name,
																 $package_to->primary_key
																).'s'
									      : $package_from->many2many($package_to->name)->[1]->name .'_'.
									        $package_to->primary_key .'s';
		}
	  }




# 		#if one possible traversal via link table
# 		if (scalar(@rk_fields) == 1 and scalar(@lk_fields) == 1) {
# 		  foreach my $rk_field (@rk_fields) {
# 			push @{ $packages{ $package->name }{'has_many'}{$link}{'link_one_one'} },
# 			  "sub ".$linkmethodname." { my \$self = shift; ".
# 				"return map \$_->".
# 				  ($schema->get_table($link)->primary_key->fields)[0].
# 					", \$self->".$linkable{$table_from->name}{$link}->name.
# 					  "_".$rk_field." }\n\n";
# 		  }
# 		  #NOTE: we need to rethink the link method name, as the cardinality
# 		  #has shifted on us.
# 		} elsif (scalar(@rk_fields) == 1) {
# 		  foreach my $rk_field (@rk_fields) {
# 			# ADD CALLBACK FOR PLURALIZATION MANGLING HERE
# 			push @{ $packages{ $package->name }{'has_many'}{ $link }{'link_many_one'} },
# 			  "sub " . $linkable{$table_from->name}{$link}->name .
# 				"s { my \$self = shift; return \$self->" .
# 				  $linkable{$table_from->name}{$link}->name . "_" .
# 					$rk_field . "(\@_) }\n\n";
# 		  }
# 		} elsif (scalar(@lk_fields) == 1) {
# 		  #these will be taken care of on the other end...
# 		} else {
# 		  #many many many.  need multiple iterations here, data structure revision
# 		  #to handle N FK sources.  This code has not been tested and likely doesn't
# 		  #work here
# 		  foreach my $rk_field (@rk_fields) {
# 			# ADD CALLBACK FOR PLURALIZATION MANGLING HERE
# 			push @{ $packages{ $package->name }{'has_many'}{ $link }{'link_many_many'} },
# 			  "sub " . $linkable{$table_from->name}{$link}->name . "_" . $rk_field .
# 				"s { my \$self = shift; return \$self->" .
# 				  $linkable{$table_from->name}{$link}->name . "_" .
# 					$rk_field . "(\@_) }\n\n";
# 		  }
# 		}
# 	  }


# 	  #
# 	  # Use foreign keys to set up "has_a/has_many" relationships.
# 	  #
#         foreach my $field ( $table_from->get_fields ) {
#             if ( $field->is_foreign_key ) {
#                 my $table_name = $table_from->name;
#                 my $field_name = $field->name;
#                 my $fk_method  = $t->format_fk_name($table_name, $field_name);
#                 my $fk         = $field->foreign_key_reference;
#                 my $ref_table  = $fk->reference_table;
#                 my $ref_pkg    = $t->format_package_name($ref_table);
#                 my $ref_field  = ($fk->reference_fields)[0];

#                 push @{ $packages{ $package->name }{'has_a'} },
#                     $package->name."->has_a( $field_name => '$ref_pkg');\n".
#                     "sub $fk_method { return shift->$field_name }\n\n"
#                 ;
				
				
#                 #
#                 # If this table "has a" to the other, then it follows 
#                 # that the other table "has many" of this one, right?
#                 #
# 				# No... there is the possibility of 1-1 cardinality

# 				#if there weren't M-M relationships via the has_many
# 				#being set up here, create nice pluralized method alias
# 				#rather for user as alt. to ugly tablename_fieldname name
# 				if(! $packages{ $ref_pkg }{ 'has_many' }{ $table_from->name } ){
# 				  # ADD CALLBACK FOR PLURALIZATION MANGLING HERE
# 				  #push @{ $packages{ $ref_pkg }{'has_many'}{ $table_name } },
# 				#	"sub $table_name\s {\n    return shift->$table_name\_$field_name\n}\n\n";
# 				  push @{ $packages{ $ref_pkg }{'has_many'}{ $table_from->name }{'fk_pluralized'} },
# 					{ table_name => $table_from->name, field_name => $field_name };

# 				#else ugly
# 				} else {
# 				}

# 				#push @{ $packages{ $ref_pkg }{'has_many'}{ $table_name } },
# 				#  "$ref_pkg->has_many(\n    '${table_name}_${field_name}', ".
# 				#  "'$table_pkg_name' => '$field_name'\n);\n\n";
# 				push @{ $packages{ $ref_pkg }{'has_many'}{ $table_name }{pluralized} },
# 				  { ref_pkg => $ref_pkg, table_pkg_name => $package->name, table_name => $table_from->name, field_name => $field_name };
# 			  }
#	  	}
 	}

	my %metadata;
	$metadata{"packages"} = \%packages;
	$metadata{"linkable"} = \%linkable;
	return(translateForm($t, \%metadata));
}

###########################################
# Here documents for the tt2 templates    #
###########################################

my $turnkey_atom_tt2 = <<'EOF';
[% ###### DOCUMENT START ###### %]

[% FOREACH package = linkable %]

##############################################

package Durian::Atom::[% package.key FILTER ucfirst %];

[% pname = package.key FILTER ucfirst%]
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
	if(ref($dbobject) eq 'Durian::Model::[% package.key FILTER ucfirst %]') {
		return(_render_record($dbobject));
	}
	else { return(_render_list($dbobject)); }
}

sub _render_record {
	my $dbobject = shift;
	my @output = ();
	my $row = {};
	my $field_hash = {};
	[% FOREACH field = packages.$pkey.columns_essential %]
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
	my @objects = $dbobject->[% package.key %]s;
	foreach my $object (@objects)
    {
		my $row = {};
	    my $field_hash = {};
	  [% FOREACH field = packages.$pkey.columns_essential %]
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

my $turnkey_dbi_tt2 = <<EOF;
[% #######  MACRO START ###### %]

[% MACRO printPackage(package) BLOCK %]
# --------------------------------------------
package [% package.pkg_name %];
use base '[% package.base %]';
use Class::DBI::Pager;

[% package.pkg_name %]->set_up_table('[% package.table %]');
[% package.pkg_name %]->columns(Primary => qw/[% printList(package.columns_primary) %]/);
[% package.pkg_name %]->columns(Essential => qw/[% printList(package.columns_essential) %]/);

[% printPKAccessors(package.columns_primary, package.table) %]
[% printHasMany(package.has_many, package.table) %]
[% printHasA(package.has_a, package.pkg_name) %]

[% END %]

[% MACRO printPKAccessors(array, name) BLOCK %]
#
# Primary key accessor
#
[% FOREACH item = array %]
sub [% name %] {
  shift->[% item %];
}
[% END %]
[% END %]

[% MACRO printHasMany(hash, name) BLOCK %]
#
# Has Many
#
[% FOREACH group = hash %][% FOREACH item = group.value %][% FOREACH arr = item.value %]
# Key: [% group.key %]
# Relationship: [% item.key %]
  [% IF item.key == 'fk_pluralized' %]
sub [% arr.table_name -%]s {
      return shift->[% arr.table_name %]_[% arr.field_name %]
	};
  [% ELSIF item.key == 'pluralized' %]
[% arr.ref_pkg %]->has_many('[% arr.table_name %]_[% arr.field_name %]', '[% arr.table_pkg_name %]' => '[% arr.field_name %]');
  [% ELSIF item.key == 'link_one_one' %]
    [% FOREACH line = item.value %]
[% line %]
    [% END %]
  [% ELSIF item.key == 'link_many_one' %]
    [% FOREACH line = item.value %]
[% line %]
    [% END %]
  [% ELSIF item.key == 'link_many_many' %]
    [% FOREACH line = item.value %]
[% line %]
    [% END %]
  [% END %]

[% END %][% END %][% END %][% END %]

[% MACRO printHasA(hash, pkg_name) BLOCK %]
#
# Has A
#
[% #name %]
[% FOREACH item = hash %][% item %]
[% END %][% END %]

[% MACRO printList(array) BLOCK %][% FOREACH item = array %][% item %] [% END %][% END %]


[% ###### DOCUMENT START ###### %]

package Durian::Model::DBI;

# Created by SQL::Translator::Producer::ClassDBI
# Template used AutoDBI.tt2

use strict;
use base qw(Class::DBI::Pg);

Durian::Model::DBI->set_db('Main', '[% db_str  %]', '[% db_user %]', '[% db_pass %]');

[% FOREACH package = packages %]
    [% printPackage(package.value) %]
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
[% FOREACH package = linkable %]
  <atom class="Durian::Atom::[% package.key FILTER ucfirst %]"  name="[% package.key FILTER ucfirst %]" xlink:label="[% package.key FILTER ucfirst %]Atom"/>
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
  [- FOREACH package = linkable -]
    [% CASE '[- package.key FILTER ucfirst -]' %]
      [% render[- package.key FILTER ucfirst -]Atom(atom.render(dbobject)) %]
  [- END -]
    [% CASE DEFAULT %]
      [% renderlist(atom.render(dbobject)) %]
[% END %]
[- FOREACH package = linkable -]
[% MACRO render[- package.key FILTER ucfirst -]Atom(lstArr) BLOCK %]
  [% FOREACH record = lstArr %]
    [% fields = record.data %]
    [- pname = package.key FILTER ucfirst -]
    [- pkey = "Durian::Model::${pname}" -]
    [- FOREACH field = packages.$pkey.columns_essential -]
      <tr><td><b>[- field -]</b></td><td>[% fields.[- field -] %]</td></tr>
    [- END -]
    [% id = record.id %]
    <tr><td><a href="?id=[% id %];class=Durian::Model::[- package.key FILTER ucfirst -]">Link</a></td><td></td></tr>
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
  my $output = shift;
  my $args = $t->producer_args;
  my $tt2     = $args->{'template'};
  my $tt2Ref;

     if ($tt2 eq 'atom')     { $tt2Ref = \$turnkey_atom_tt2;     }
  elsif ($tt2 eq 'classdbi') { $tt2Ref = \$turnkey_dbi_tt2;      }
  elsif ($tt2 eq 'xml')      { $tt2Ref = \$turnkey_xml_tt2;      }
  elsif ($tt2 eq 'template') { $tt2Ref = \$turnkey_template_tt2; }
  else                       { die __PACKAGE__." didn't recognize your template option: $tt2" }

  my $vars = {
				packages  => $output->{packages},
			    linkable  => $output->{linkable},
			    linktable => $output->{linktable},
			    db_str    => $args->{db_str},
			    db_user   => $args->{db_user},
			    db_pass   => $args->{db_pass},
  };
  my $config = {
      EVAL_PERL    => 1,               # evaluate Perl code blocks
  };

  # create Template object
  my $template = Template->new($config);

  my $result;
  # specify input filename, or file handle, text reference, etc.
  # process input template, substituting variables
  $template->process($tt2Ref, $vars, \$result) || die $template->error();
  return($result);
}

1;

# -------------------------------------------------------------------

=pod

=head1 NAME

SQL::Translator::Producer::ClassDBI - create Class::DBI classes from schema

=head1 SYNOPSIS

Use this producer as you would any other from SQL::Translator.  See
L<SQL::Translator> for details.

This package utilizes SQL::Translator\'s formatting methods
format_package_name(), format_pk_name(), format_fk_name(), and
format_table_name() as it creates classes, one per table in the schema
provided.  An additional base class is also created for database connectivity
configuration.  See L<Class::DBI> for details on how this works.

=head1 AUTHORS

Allen Day E<lt>allenday@ucla.eduE<gt>
Ying Zhang E<lt>zyolive@yahoo.comE<gt>,
Ken Y. Clark E<lt>kclark@cpan.orgE<gt>,
Brian O\'Connor E<lt>brian.oconnor@excite.comE<gt>.
