package SQL::Translator::XMI::Parser::V10;

# -------------------------------------------------------------------
# $Id: V10.pm,v 1.1 2003-09-29 12:02:36 grommit Exp $
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

SQL::Translator::XMI::Parser::V10 - Version 1.0 parser.

=cut

use strict;
use 5.006_001;
use vars qw/$VERSION/;
$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;

use base qw(SQL::Translator::XMI::Parser);

my $spec10 = {};

$spec10->{class} = {
    name   => "class",
    plural => "classes",
	isRoot  => 1,
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
		#{ 
        #    name  => "datatype",
        #    path  => 'xmiDeref(Foundation.Core.StructuralFeature.type/Foundation.Core.Classifier)/Foundation.Core.DataType/Foundation.Core.ModelElement.name/text()',
        #},
    ],
};

__PACKAGE__->XmiSpec($spec10);

#-----------------------------------------------------------------------------

sub get_classes {
	print "******************* HELLO 1.0 ********************\n";
	shift->_get_classes(@_);
}

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

=head1 LICENSE

This package is free software and is provided "as is" without express or
implied warranty. It may be used, redistributed and/or modified under the
terms of either;

a) the Perl Artistic License.

See F<http://www.perl.com/perl/misc/Artistic.html>

b) the terms of the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version.

=cut
