package SQL::Translator::Parser::XML::XMI;

# -------------------------------------------------------------------
# $Id: XMI.pm,v 1.2 2003-09-08 12:27:29 grommit Exp $
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

=head1 NAME

SQL::Translator::Parser::XML::XMI - Parser to create Schema from UML
Class diagrams stored in XMI format.

=cut

# -------------------------------------------------------------------

use strict;

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

use Data::Dumper;
use Exporter;
use base qw(Exporter);
@EXPORT_OK = qw(parse);

use base qw/SQL::Translator::Parser/;  # Doesnt do anything at the mo!
use SQL::Translator::Utils 'debug';
use XML::XPath;
use XML::XPath::XMLParser;


# Custom XPath functions
#-----------------------------------------------------------------------------

#
# Pass a nodeset. If the first node has an xmi.idref attrib then return
# the nodeset for that id
#
sub XML::XPath::Function::xmideref {
    my $self = shift;
    my ($node, @params) = @_;
    if (@params > 1) {
        die "xmideref() function takes one or no parameters\n";
    }
    elsif (@params) {
        my $nodeset = shift(@params);
        return $nodeset unless $nodeset->size;
        $node = $nodeset->get_node(1);
    }
    die "xmideref() needs an Element node." 
    unless $node->isa("XML::XPath::Node::Element");

    my $id = $node->getAttribute("xmi.idref") or return $node;
    return $node->getRootNode->find('//*[@xmi.id="'.$id.'"]');
}

sub XML::XPath::Function::hello {
    return XML::XPath::Literal->new("Hello World");
}



# Parser
#-----------------------------------------------------------------------------

#
# is_visible( {ELEMENT|VIS_OF_THING}, VISLEVEL)
#
# Returns true or false for whether the visibility of something e.g. Class,
# Attribute, is visible at the level given.
#
{
    my %vislevel = (
        public => 1,
        protected => 2,
        private => 3,
    );

    sub is_visible {
        my ($arg, $vis) = @_;
        return 1 unless $vis;
        my $foo;
        die "is_visible : Needs something to test" unless $arg;
        if ( $arg->isa("XML::XPath::Node::Element") ) {
            $foo = $arg->getAttribute("visibility");
        }
        else {
            $foo = $arg;
        }
        return 1 if $vislevel{$vis} >= $vislevel{$foo};
        return 0;
    }
}

sub parse {
    my ( $translator, $data ) = @_;
    local $DEBUG    = $translator->debug;
    my $schema      = $translator->schema;
    my $pargs       = $translator->parser_args;

    debug "Visibility Level:$pargs->{visibility}" if $DEBUG;

    my $xp = XML::XPath->new(xml => $data);
    $xp->set_namespace("UML", "org.omg.xmi.namespace.UML");
    #
    # TODO
    # - Options to set the initial context node so we don't just
    #   blindly do all the classes. e.g. Select a diag name to do.

    #
    # Work our way through the classes, creating tables. We only
    # want class with xmi.id attributes and not the refs to them,
    # which will have xmi.idref attributes.
    #
    my @nodes = $xp->findnodes('//UML:Class[@xmi.id]');

    debug "Found ".scalar(@nodes)." Classes: ".join(", ",
        map {$_->getAttribute("name")} @nodes) if $DEBUG;

    for my $classnode (@nodes) {
        # Only process classes with <<Table>> and name
        next unless my $classname = $classnode->getAttribute("name");
        next unless !$pargs->{visibility}
            or is_visible($classnode, $pargs->{visibility});

        my $stereotype = "".$classnode->find(
            'xmideref(UML:ModelElement.stereotype/UML:Stereotype)/@name');
        next unless $stereotype eq "Table";

        # Add the table
        debug "Adding class: $classname as table:$classname" if $DEBUG;
        my $table = $schema->add_table(name=>$classname)
            or die "Schema Error: ".$schema->error;

        #
        # Fields from Class attributes
        #
        # name data_type size default_value is_nullable
        # is_auto_increment is_primary_key is_foreign_key comments
        #
        foreach my $attrnode ( $classnode->findnodes(
            'UML:Classifier.feature/UML:Attribute[@xmi.id]',)
        ) {
            next unless my $fieldname = $attrnode->getAttribute("name");
            next unless !$pargs->{visibility}
                or is_visible($attrnode, $pargs->{visibility});

            my $stereotype = "".$attrnode->findvalue(
                'xmideref(UML:ModelElement.stereotype/UML:Stereotype)/@name');
            my %data = (
                name => $fieldname,
                data_type => "".$attrnode->find(
                  'xmideref(UML:StructuralFeature.type/UML:DataType)/@name'),
                is_primary_key => $stereotype eq "PK" ? 1 : 0,
                #is_foreign_key => $stereotype eq "FK" ? 1 : 0,
            );
            if ( my @body = $attrnode->findnodes(
                'UML:Attribute.initialValue/UML:Expression/@body') 
            ) {
                $data{default_value} = $body[0]->getData;
            }

            debug "Adding field:",Dumper(\%data);
            my $field = $table->add_field( %data ) or die $schema->error;

            $table->primary_key( $field->name ) if $data{'is_primary_key'};
            #
            # TODO:
            # - We should be able to make the table obj spot this when
            #   we use add_field.
            #
        }

    } # Classes loop

    return 1;
}

1;

# -------------------------------------------------------------------

=pod

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::XML::XMI;

  my $translator     = SQL::Translator->new(
      from           => 'XML-XMI',
      to             => 'MySQL',
      filename       => 'schema.xmi',
      show_warnings  => 1,
      add_drop_table => 1,
  );

  print $obj->translate;

=head1 DESCRIPTION

=head2 UML Data Modeling

To tell the parser which Classes are tables give them a <<Table>> stereotype.

Any attributes of the class will be used as fields. The datatype of the
attribute must be a UML datatype and not an object, with the datatype's name
being used to set the data_type value in the schema.

Primary keys are attributes marked with <<PK>> stereotype.

=head2 XMI Format

The parser has been built using XMI generated by PoseidonUML 2beta, which
says it uses UML 2. So the current conformance is down to Poseidon's idea
of XMI!

=head1 ARGS

=over 4

=item visibility

 visibilty=public|protected|private

What visibilty of stuff to translate. e.g when set to 'public' any private
and package Classes will be ignored and not turned into tables. Applies
to Classes and Attributes.

If not set or false (the default) no checks will be made and everything is
translated.

=back

=head1 BUGS

Seems to be slow. I think this is because the XMI files can get pretty
big and complex, especially all the diagram info.

=head1 TODO

B<field sizes> Don't think UML does this directly so may need to include
it in the datatype names.

B<table_visibility and field_visibility args> Seperate control over what is 
parsed, setting visibility arg will set both.

Everything else! Relations, fkeys, constraints, indexes, etc...

=head1 AUTHOR

Mark D. Addison E<lt>mark.addison@itn.co.ukE<gt>.

=head1 SEE ALSO

perl(1), SQL::Translator, XML::XPath, SQL::Translator::Producer::XML::SQLFairy,
SQL::Translator::Schema.

=cut
