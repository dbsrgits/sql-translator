package SQL::Translator::XMI::Parser;

# -------------------------------------------------------------------
# $Id: Parser.pm,v 1.6 2003-10-01 17:45:47 grommit Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Mark Addison <mark.addison@itn.co.uk>,
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

=pod

=head1 NAME

SQL::Translator::XMI::Parser - XMI Parser class for use in SQL Fairy's XMI 
parser.

=cut

use strict;
use 5.006_001;
use vars qw/$VERSION/;
$VERSION = sprintf "%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/;

use Data::Dumper;
use XML::XPath;
use XML::XPath::XMLParser;
use Storable qw/dclone/;

# Spec
#------
# See SQL::Translator::XMI::Parser::V12 and SQL::Translator::XMI::Parser:V10
# for examples.
#
# Hash ref used to describe the 2 xmi formats 1.2 and 1.0. Neither is complete!
#
# NB The names of the data keys MUST be the same for both specs so the
# data structures returned are the same.
#
# TODO
# 
# * There is currently no way to set the data key name for attrib_data, it just
# uses the attribute name from the XMI. This isn't a problem at the moment as
# xmi1.0 names all these things with tags so we don't need the attrib data!
# Also use of names seems to be consistant between the versions.
#
#
# XmiSpec( $spec )
#
# Call as class method to set up the parser from a spec (see above). This
# generates the get_ methods for the version of XMI the spec is for. Called by
# the sub-classes (e.g. V12 and V10) to create parsers for each version.
#
sub XmiSpec {
	my ($me,$spec) = @_;
	_init_specs($spec);
	$me->_mk_gets($spec);
}

# Build lookups etc. Its important that each spec item becomes self contained
# so we can build good closures, therefore we do all the lookups 1st.
sub _init_specs {
	my $specs = shift;

	foreach my $spec ( values %$specs ) {
		# Look up for kids get method
		foreach ( @{$spec->{kids}} ) {
            $_->{get_method} = "get_".$specs->{$_->{class}}{plural};
        }

		# Add xmi.id ti all specs. Everything we want at the moment (in both
		# versions) has an id. The tags that don't seem to be used for
		# structure.
		my $attrib_data = $spec->{attrib_data} ||= [];
		push @$attrib_data, "xmi.id";
	}

}

# Create get methods from spec
#
sub _mk_gets {
    my ($proto,$specs) = @_;
    my $class = ref($proto) || $proto;
    foreach ( values %$specs ) {
        # Clone from specs and sort out the lookups into it so we get a
        # self contained spec to use as a proper closure.
        my $spec = dclone($_);

		# Create _get_* method with get_* as an alias unless the user has
		# defined it. Allows for override. Note the alias is in this package
		# so we can add overrides to both specs.
		no strict "refs";
		my $meth = "_get_$spec->{plural}";
		*{$meth} = _mk_get($spec);
		*{__PACKAGE__."::get_$spec->{plural}"} = sub {shift->$meth(@_);}
		 	unless $class->can("get_$spec->{plural}");
    }
}

#
# Sets up the XML::XPath object and then checks the version of the XMI file and
# blesses its self into either the V10 or V12 class.
#
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %args = @_;
    my $me = {};

    # Create the XML::XPath object
    # TODO Docs recommend we only use 1 XPath object per application
    my $xp;
    foreach (qw/filename xml ioref/) {
        if ($args{$_}) {
            $xp = XML::XPath->new( $_ => $args{$_});
            $xp->set_namespace("UML", "org.omg.xmi.namespace.UML");
            last;
        }
    }
    $me = { xml_xpath => $xp };

    # Work out the version of XMI we have and return as that sub class 
	my $xmiv = $args{xmi_version}
	    || "".$xp->findvalue('/XMI/@xmi.version')
        || die "Can't find XMI version";
	$xmiv =~ s/[.]//g;
	$class = __PACKAGE__."::V$xmiv";
	eval "use $class;";
	die "Failed to load version sub class $class : $@" if $@;

	return bless $me, $class;
}

#
# _mk_get
#
# Generates and returns a get_ sub for the spec given.
# So, if you want to change how the get methods (e.g. get_classes) work do it
# here!
#
# The get methods made have the args described in the docs and 2 private args
# used internally, to call other get methods from paths in the spec.
# NB: DO NOT use publicly as you will break the version independance. e.g. When
# using _xpath you need to know which version of XMI to use. This is handled by
# the use of different paths in the specs.
#
#  _context => The context node to use, if not given starts from root.
#
#  _xpath   => The xpath to use for finding stuff.
#
sub _mk_get {
    my $spec = shift;

    # get_* closure using $spec
    return sub {
	my ($me, %args) = @_;
    my $xp = delete $args{_context} || $me->{xml_xpath};
	my $things;

	my $xpath = $args{_xpath} ||= $spec->{default_path};
#warn "Searching for $spec->{plural} using:$xpath\n";

    my @nodes = $xp->findnodes($xpath);
#warn "None.\n" unless @nodes;
	return unless @nodes;

	for my $node (@nodes) {
#warn "    Found $spec->{name} xmi.id=".$node->getAttribute("xmi.id")." name=".$node->getAttribute("name")."\n";
		my $thing = {};
        # my $thing = { xpNode => $node };

		# Have we seen this before? If so just use the ref we have.
        if ( my $id = $node->getAttribute("xmi.id") ) {
            if ( my $foo = $me->{model}{things}{$id} ) {
#warn "    Reffing from model **********************\n";
                push @$things, $foo; 
				next;
			}
        }

		# Get the Tag attributes
        foreach ( @{$spec->{attrib_data}} ) {
			$thing->{$_} = $node->getAttribute($_);
		}

        # Add the path data
        foreach ( @{$spec->{path_data}} ) {
#warn "          $spec->{name} - $_->{name} using:$_->{path}\n";
            my @nodes = $node->findnodes($_->{path});
            $thing->{$_->{name}} = @nodes ? $nodes[0]->getData
                : (exists $_->{default} ? $_->{default} : undef);
        }

        # Run any filters set
        #
        # Should we do this after the kids as we may want to test them?
        # e.g. test for number of attribs
        if ( my $filter = $args{filter} ) {
            local $_ = $thing;
            next unless $filter->($thing);
        }

        # Add anything with an id to the things lookup
        push @$things, $thing;
		if ( exists $thing->{"xmi.id"} and defined $thing->{"xmi.id"}
            and my $id = $thing->{"xmi.id"} 
        ) {
			$me->{model}{things}{$id} = $thing; }

        # Kids
        #
        foreach ( @{$spec->{kids}} ) {
			my $data;
            my $meth = $_->{get_method};
            my $path = $_->{path};

			# Variable subs on the path from thing
			$path =~ s/\$\{(.*?)\}/$thing->{$1}/g;
			$data = $me->$meth( _context => $node, _xpath => $path,
                filter => $args{"filter_$_->{name}"} );

            if ( $_->{multiplicity} eq "1" ) {
                $thing->{$_->{name}} = shift @$data;
            }
            else {
                my $kids = $thing->{$_->{name}} = $data || [];
				if ( my $key = $_->{"map"} ) {
					$thing->{"_map_$_->{name}"} = _mk_map($kids,$key);
				}
            }
        }
	}

	if ( $spec->{isRoot} ) {
		push(@{$me->{model}{$spec->{plural}}}, $_) foreach @$things;
	}
	return $things;
} # /closure sub

} # /_mk_get

sub _mk_map {
	my ($kids,$key) = @_;
	my $map = {};
	foreach (@$kids) {
		$map->{$_->{$key}} = $_ if exists $_->{$key};
	}
	return $map;
}

sub get_associations {
	my $assoc = shift->_get_associations(@_);
	foreach (@$assoc) {
		next unless defined $_->{ends}; # Wait until we get all of an association
		my @ends = @{$_->{ends}};
		if (@ends != 2) {
			warn "Sorry can't handle otherEnd associations with more than 2 ends"; 
			return $assoc;
		}
		$ends[0]{otherEnd} = $ends[1];
		$ends[1]{otherEnd} = $ends[0];
	}
	return $assoc;
}

1; #===========================================================================


package XML::XPath::Function;

#
# May need to look at doing deref on all paths just to be on the safe side!
#
# Will also want some caching as these calls are expensive as the whole doc
# is used but the same ref will likley be requested lots of times.
#
sub xmiDeref {
    my $self = shift;
    my ($node, @params) = @_;
    if (@params > 1) {
        die "xmiDeref() function takes one or no parameters\n";
    }
    elsif (@params) {
        my $nodeset = shift(@params);
        return $nodeset unless $nodeset->size;
        $node = $nodeset->get_node(1);
    }
    die "xmiDeref() needs an Element node." 
    unless $node->isa("XML::XPath::Node::Element");

    my $id = $node->getAttribute("xmi.idref") or return $node;
    return $node->getRootNode->find('//*[@xmi.id="'.$id.'"]');
}


# compile please
1;

__END__

=head1 SYNOPSIS

 use SQL::Translator::XMI::Parser;
 my $xmip = SQL::Translator::XMI::Parser->new( xml => $xml );
 my $classes = $xmip->get_classes(); 

=head1 DESCRIPTION

Parses XMI files (XML version of UML diagrams) to perl data structures and 
provides hooks to filter the data down to what you want.

=head2 new

Pass in name/value arg of either C<filename>, C<xml> or C<ioref> for the XMI
data you want to parse.

The version of XMI to use either 1.0 or 1.2 is worked out from the file. You
can also use a C<xmi_version> arg to set it explicitley.

=head2 get_* methods

Doc below is for classes method, all the other calls follow this form.

=head2 get_classes( ARGS )

 ARGS     - Name/Value list of args.

 filter   => A sub to filter the node to see if we want it. Has the nodes data,
             before kids are added, referenced to $_. Should return true if you
             want it, false otherwise.
             
             e.g. To find only classes with a "Foo" stereotype.

              filter => sub { return $_->{stereotype} eq "Foo"; }

 filter_attributes => A filter sub to pass onto get_attributes.

 filter_operations => A filter sub to pass onto get_operations.

Returns a perl data structure including all the kids. e.g. 

 {
   'name' => 'Foo',
   'visibility' => 'public',
   'isActive' => 'false',
   'isAbstract' => 'false',
   'isSpecification' => 'false',
   'stereotype' => 'Table',
   'isRoot' => 'false',
   'isLeaf' => 'false',
   'attributes' => [
       {
         'name' => 'fooid',
         'stereotype' => 'PK',
         'datatype' => 'int'
         'ownerScope' => 'instance',
         'visibility' => 'public',
         'initialValue' => undef,
         'isSpecification' => 'false',
       },
       {
         'name' => 'name',
         'stereotype' => '',
         'datatype' => 'varchar'
         'ownerScope' => 'instance',
         'visibility' => 'public',
         'initialValue' => '',
         'isSpecification' => 'false',
       },
   ]
   'operations' => [
       {
         'name' => 'magic',
         'isQuery' => 'false',
         'ownerScope' => 'instance',
         'visibility' => 'public',
         'isSpecification' => 'false',
         'stereotype' => '',
         'isAbstract' => 'false',
         'isLeaf' => 'false',
         'isRoot' => 'false',
         'concurrency' => 'sequential'
         'parameters' => [
             {
               'kind' => 'inout',
               'isSpecification' => 'false',
               'stereotype' => '',
               'name' => 'arg1',
               'datatype' => undef
             },
             {
               'kind' => 'inout',
               'isSpecification' => 'false',
               'stereotype' => '',
               'name' => 'arg2',
               'datatype' => undef
             },
             {
               'kind' => 'return',
               'isSpecification' => 'false',
               'stereotype' => '',
               'name' => 'return',
               'datatype' => undef
             }
         ],
       }
   ],
 }

=head1 XMI XPath Functions

The Parser adds the following extra XPath functions for use in the Specs.

=head2 xmiDeref

Deals with xmi.id/xmi.idref pairs of attributes. You give it an
xPath e.g 'UML:ModelElement.stereotype/UML:stereotype' if the the
tag it points at has an xmi.idref it looks up the tag with that
xmi.id and returns it.

If it doesn't have an xmi.id, the path is returned as normal.

e.g. given

 <UML:ModelElement.stereotype>
     <UML:Stereotype xmi.idref = 'stTable'/>
 </UML:ModelElement.stereotype>
  ...
 <UML:Stereotype xmi.id='stTable' name='Table' visibility='public'
     isAbstract='false' isSpecification='false' isRoot='false' isLeaf='false'>
     <UML:Stereotype.baseClass>Class</UML:Stereotype.baseClass>
 </UML:Stereotype>

Using xmideref(//UML:ModelElement.stereotype/UML:stereotype) would return the
<UML:Stereotype xmi.id = '3b4b1e:f762a35f6b:-7fb6' ...> tag.

Using xmideref(//UML:ModelElement.stereotype/UML:stereotype)/@name would give
"Table".

=head1 SEE ALSO

perl(1).

=head1 TODO

=head1 BUGS

=head1 VERSION HISTORY

=head1 AUTHOR

grommit <mark.addison@itn.co.uk>

=cut
