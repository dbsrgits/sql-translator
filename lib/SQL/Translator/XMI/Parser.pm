package SQL::Translator::XMI::Parser;

=pod

=head1 NAME

SQL::Translator::XMI::Parser

=cut

use strict;
use 5.006_001;
our $VERSION = "0.01";

use XML::XPath;
use XML::XPath::XMLParser;
use Storable qw/dclone/;

# Spec
#=============================================================================
#
# Describes the 2 xmi formats 1.2 and 1.0. Neither is complete!
#
# NB The names of the data keys MUST be the same for both specs so the
# data structures returned are the same.
#
# There is currently no way to set the data key name for attrib_data, it just
# uses the attribute name from the XMI. This isn't a problem at the moment as
# xmi1.0 names all these things with tags so we don't need the attrib data!
# Also use of names seems to be consistant between the versions.
#

my $SPECS = {};

my $spec12 = $SPECS->{"1.2"} = {};

$spec12->{class} = {
    name    => "class",
    plural  => "classes",
	isRoot  => 1,
    default_path => '//UML:Class[@xmi.id]',
    attrib_data => 
        [qw/name visibility isSpecification isRoot isLeaf isAbstract isActive/],
    path_data => [
        { 
            name  => "stereotype",
            path  => 'xmiDeref(UML:ModelElement.stereotype/UML:Stereotype)/@name',
            default => "",
        },
    ],
    kids => [
        { 
            name  => "attributes",
            # name in data returned
            path  => "UML:Classifier.feature/UML:Attribute",
            class => "attribute", 
            # Points to class in spec. get_attributes() called to parse it and
            # adds filter_attributes to the args for get_classes().
            multiplicity => "*",
            # How many we get back. Use '1' for 1 and '*' for lots.
			# TODO If not set then decide depening on the return?
        },
        {
            name  => "operations",
            path  => "UML:Classifier.feature/UML:Operation",
            class => "operation", 
            multiplicity => "*",
        },
        {
            name  => "taggedValues",
            path  => 'UML:ModelElement.taggedValue/UML:TaggedValue',
            class => "taggedValue",
            multiplicity => "*",
			map => "name",
        	# Add a _map_taggedValues to the data. Its a hash of the name data
			# which refs the normal list of kids
		},
    ],
};

$spec12->{taggedValue} = {
    name   => "taggedValue",
    plural => "taggedValues",
    default_path => '//UML:TaggedValue[@xmi.id]',
    attrib_data  => [qw/isSpecification/],
    path_data => [
        { 
            name  => "dataValue",
            path  => 'UML:TaggedValue.dataValue/text()',
        },
        { 
            name  => "name",
            path  => 'xmiDeref(UML:TaggedValue.type/UML:TagDefinition)/@name',
        },
    ],
};

$spec12->{attribute} = {
    name => "attribute",
    plural => "attributes",
    default_path => '//UML:Classifier.feature/UML:Attribute[@xmi.id]',
    attrib_data => 
        [qw/name visibility isSpecification ownerScope/],
    path_data => [
        { 
            name  => "stereotype",
            path  => 'xmiDeref(UML:ModelElement.stereotype/UML:Stereotype)/@name',
            default => "",
        },
        { 
            name  => "datatype",
            path  => 'xmiDeref(UML:StructuralFeature.type/UML:DataType)/@name',
        },
        { 
            name  => "initialValue",
            path  => 'UML:Attribute.initialValue/UML:Expression/@body',
        },
    ],
    kids => [
        { 
            name  => "taggedValues",
            path  => 'UML:ModelElement.taggedValue/UML:TaggedValue',
            class => "taggedValue", 
            multiplicity => "*",
			map => "name",
        },
    ],
};

$spec12->{operation} = {
    name => "operation",
    plural => "operations",
    default_path => '//UML:Classifier.feature/UML:Operation[@xmi.id]',
    attrib_data => 
        [qw/name visibility isSpecification ownerScope isQuery
            concurrency isRoot isLeaf isAbstract/],
    path_data => [
        { 
            name  => "stereotype",
            path  => 'xmiDeref(UML:ModelElement.stereotype/UML:Stereotype)/@name',
            default => "",
        },
    ],
    kids => [
        { 
            name  => "parameters",
            path  => "UML:BehavioralFeature.parameter/UML:Parameter",
            class => "parameter", 
            multiplicity => "*",
        },
        { 
            name  => "taggedValues",
            path  => 'UML:ModelElement.taggedValue/UML:TaggedValue',
            class => "taggedValue", 
            multiplicity => "*",
			map => "name",
        },
    ],
};

$spec12->{parameter} = {
    name   => "parameter",
    plural => "parameters",
    default_path => '//UML:Parameter[@xmi.id]',
    attrib_data  => [qw/name isSpecification kind/],
    path_data => [
        { 
            name  => "stereotype",
            path  => 'xmiDeref(UML:ModelElement.stereotype/UML:Stereotype)/@name',
            default => "",
        },
        { 
            name  => "datatype",
            path  => 'xmiDeref(UML:StructuralFeature.type/UML:DataType)/@name',
        },
    ],
};

#-----------------------------------------------------------------------------

my $spec10 = $SPECS->{"1.0"} = {};

$spec10->{class} = {
    name   => "class",
    plural => "classes",
    default_path => '//Foundation.Core.Class[@xmi.id]',
    attrib_data => [],
    path_data => [
        { 
            name  => "name",
            path  => 'Foundation.Core.ModelElement.name/text()',
        },
        { 
            name => "visibility",
            path => 'Foundation.Core.ModelElement.visibility/@xmi.value',
        },
        { 
            name => "isSpecification",
            path => 'Foundation.Core.ModelElement.isSpecification/@xmi.value',
        },
        { 
            name => "isRoot",
            path => 'Foundation.Core.GeneralizableElement.isRoot/@xmi.value',
        },
        { 
            name => "isLeaf",
            path => 'Foundation.Core.GeneralizableElement.isLeaf/@xmi.value',
        },
        { 
            name => "isAbstract",
            path => 'Foundation.Core.GeneralizableElement.isAbstract/@xmi.value',
        },
        { 
            name => "isActive",
            path => 'Foundation.Core.Class.isActive/@xmi.value',
        },
    ],
    kids => [
	    { 
            name  => "attributes",
            path  => 
                'Foundation.Core.Classifier.feature/Foundation.Core.Attribute',
            class => "attribute", 
            multiplicity => "*",
        },
    #    { 
    #        name  => "operations",
    #        path  => "UML:Classifier.feature/UML:Operation",
    #        class => "operation", 
    #        multiplicity => "*",
    #    },
    ],
};

$spec10->{attribute} = {
    name => "attribute",
    plural => "attributes",
    default_path => '//Foundation.Core.Attribute[@xmi.id]',
    path_data => [
        {
            name  => "name",
            path  => 'Foundation.Core.ModelElement.name/text()',
        },
        {
            name => "visibility",
            path => 'Foundation.Core.ModelElement.visibility/@xmi.value',
        },
        {
            name => "isSpecification",
            path => 'Foundation.Core.ModelElement.isSpecification/@xmi.value',
        },
        {
            name => "ownerScope",
            path => 'Foundation.Core.Feature.ownerScope/@xmi.value',
        },
		{
            name  => "initialValue",
            path  => 'Foundation.Core.Attribute.initialValue/Foundation.Data_Types.Expression/Foundation.Data_Types.Expression.body/text()',
        },
		# {
        #     name  => "datatype",
        #     path  => 'xmiDeref(Foundation.Core.StructuralFeature.type/Foundation.Core.Classifier)/Foundation.Core.DataType/Foundation.Core.ModelElement.name/text()',
        # },
    ],
};

#=============================================================================

#
# How this works!
#=================
#
# The parser supports xmi1.0 and xmi1.2 based on the specs above. At new() time
# the version is read from the XMI tag and picks out a spec e.g.
# $SPECS->{"1.2"} and feeds it to mk_gets() which returns a hash ref of subs
# (think strategy pattern), one for each entry in the specs hash. This is held
# in $self->{xmi_get_}.
#
# When the class is use'd it sets dispatch methods with
# mk_get_dispatch() that return the call using the corresponding sub in
# $self->{xmi_get_}. e.g.
#
# sub get_classes    { $_[0]->{xmi_get_}{classes}->(@_); }
# sub get_attributes { $_[0]->{xmi_get_}{attributes}->(@_); }
# sub get_classes    { $_[0]->{xmi_get_}{classes}->(@_); }
#
# The names for the data keys in the specs must match up so that we get the
# same data structure for each version.
#

# Class setup
foreach ( values %$SPECS ) { init_specs($_) };
mk_get_dispatch();

# Build lookups etc. Its important that each spec item becomes self contained
# so we can build good closures, therefore we do all the lookups 1st.
sub init_specs {
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

# Generate get_* subs to dispach the calls to the subs held in $me->{xmi_get_}
sub mk_get_dispatch {
    foreach ( values %{$SPECS->{"1.2"}} ) {
        my $name = $_->{plural};
        no strict "refs";

        # get_ on parser
        my $code = sub { 
            $_[0]->{xmi_get_}{$name}->(@_); 
        };
        *{"get_$name"} = $code;
    }
}

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
    
    # Work out the version of XMI we have and generate the get subs to parse it
    my $xmiv = $args{xmi_version}
	    || "".$xp->findvalue('/XMI/@xmi.version')
        || die "Can't find XMI version";
    $me->{xmi_get_} = mk_gets($SPECS->{$xmiv});
    
    return bless $me, $class;
}


# Returns hashref of get subs from set of specs e.g. $SPECS->{"1.2"}
#
# TODO
# * Add a memoize so we don't keep regenerating the subs for every use.
sub mk_gets {
    my $specs = shift;
    my $gets;
    foreach ( values %$specs ) {
        # Clone from specs so we get a proper closure.
        my $spec = dclone($_);
        
        # Add the sub
        $gets->{$spec->{plural}} = mk_get($spec);
    }
    return $gets;
}

# 
# mk_get
#
# Generates and returns a get_ sub for the spec given. e.g. give it
# $SPECS->{"1.2"}->{classes} to get the code for xmi 1.2 get_classes. So, if
# you want to change how the get methods work do it here!
#
# The get methods made have the args described in the docs and 2 private args
# used internally, to call other get methods from paths in the spec.
#
# NB: DO NOT use publicly as you will break the version independance. e.g. When
# using _xpath you need to know which version of XMI to use. This is handled by
# the use of different paths in the specs.
#
#  _context => The context node to use, if not given starts from root.
#
#  _xpath   => The xpath to use for finding stuff.
#
use Data::Dumper;
sub mk_get {
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

} # /mk_get

sub _mk_map {
	my ($kids,$key) = @_;
	my $map = {};
	foreach (@$kids) {
		$map->{$_->{$key}} = $_ if exists $_->{$key};
	}
	return $map;
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

The Parser adds the following extra XPath functions for use in the SPECS.

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

=head1 LICENSE

This package is free software and is provided "as is" without express or
implied warranty. It may be used, redistributed and/or modified under the
terms of either;

a) the Perl Artistic License.

See F<http://www.perl.com/perl/misc/Artistic.html>

b) the terms of the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version.

=cut
