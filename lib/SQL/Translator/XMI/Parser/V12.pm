package SQL::Translator::XMI::Parser::V12;

# -------------------------------------------------------------------
# $Id: V12.pm,v 1.3 2003-10-03 13:17:28 grommit Exp $
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

SQL::Translator::XMI::Parser::V12 - Version 1.2 parser.

=cut

use strict;
use 5.006_001;
use vars qw/$VERSION/;
$VERSION = sprintf "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/;

use base qw(SQL::Translator::XMI::Parser);

my $spec12 = {};

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
		{
            name  => "associationEnds",
			path  => '//UML:AssociationEnd.participant/UML:Class[@xmi.idref="${xmi.id}"]/../..',
			# ${xmi.id} is a variable sub from the data defined for this thing.
			# Not standard XPath! Done in the get sub
			class => "AssociationEnd",
            multiplicity => "*",
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
        { 
            name  => "dataType",
            path  => 'xmiDeref(UML:StructuralFeature.type/UML:DataType)',
            class => "dataType", 
            multiplicity => "1",
        },
    ],
};

$spec12->{dataType} = {
    name   => "datatype",
    plural => "datatypes",
    default_path => '//UML:DataType[@xmi.id]',
    attrib_data  =>
        [qw/name visibility isSpecification isRoot isLeaf isAbstract/],
    path_data => [
        { 
            name  => "stereotype",
            path  => 'xmiDeref(UML:ModelElement.stereotype/UML:Stereotype)/@name',
            default => "",
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

$spec12->{association} = {
    name   => "association",
    plural => "associations",
	isRoot => 1,
    default_path => '//UML:Association[@xmi.id]',
    attrib_data  => [qw/name visibility isSpecification isNavigable ordering aggregation targetScope changeability/],
    path_data => [
        {
            name  => "stereotype",
            path  => 'xmiDeref(UML:ModelElement.stereotype/UML:Stereotype)/@name',
            default => "",
        },
	],
	kids => [
        {
            name  => "ends",
            path  => "UML:Association.connection/UML:AssociationEnd",
            class => "AssociationEnd", 
            multiplicity => "*",
        },
    ],
};

$spec12->{AssociationEnd} = {
    name   => "End",
    plural => "Ends",
    default_path => '//UML:AssociationEnd',
    attrib_data  => [qw/name visibility isSpecification isNavigable ordering aggregation targetScope changeability/],
    path_data => [
        {
            name  => "stereotype",
            path  => 'xmiDeref(UML:ModelElement.stereotype/UML:Stereotype)/@name',
            default => "",
        },
        {
            name  => "className",
            path  => 'xmiDeref(UML:AssociationEnd.participant/UML:Class)/@name',
            default => "",
        },
	],
    kids => [
		{
            name  => "association",
            path  => "../..",
            class => "association", 
            multiplicity => "1",
        },
        {
            name  => "participant",
            path  => "xmiDeref(UML:AssociationEnd.participant/UML:Class)",
            class => "class", 
            multiplicity => "1",
        },
    ],
};

# Set the spec and have the get_* methods generated
__PACKAGE__->XmiSpec($spec12);

#-----------------------------------------------------------------------------

# Test override
# sub get_classes {
# 	print "HELLO 1.2\n";
# 	shift->SUPER::get_classes(@_);
# }

1; #===========================================================================

__END__

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

perl(1).

=head1 TODO

=head1 BUGS

=head1 VERSION HISTORY

=head1 AUTHOR

grommit <mark.addison@itn.co.uk>

=cut
