package SQL::Translator::Parser::XML::XMI;

# -------------------------------------------------------------------
# $Id: XMI.pm,v 1.10 2003-10-03 13:17:28 grommit Exp $
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

use strict;

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

use Data::Dumper;
use Exporter;
use base qw(Exporter);
@EXPORT_OK = qw(parse);

use base qw/SQL::Translator::Parser/;  # Doesnt do anything at the mo!
use SQL::Translator::Utils 'debug';
use SQL::Translator::XMI::Parser;

# SQLFairy Parser
#-----------------------------------------------------------------------------

# is_visible - Used to check visibility in filter subs
{
    my %vislevel = (
        public => 1,
        protected => 2,
        private => 3,
    );

    sub is_visible {
		my ($nodevis, $vis) = @_;
        $nodevis = ref $_[0] ? $_[0]->{visibility} : $_[0];
        return 1 unless $vis;
        return 1 if $vislevel{$vis} >= $vislevel{$nodevis};
        return 0; 
    }
}

my ($schema, $pargs);

sub parse {
    my ( $translator, $data ) = @_;
    local $DEBUG  = $translator->debug;
    $schema    = $translator->schema;
    $pargs     = $translator->parser_args;
	$pargs->{classes2schema} ||= \&classes2schema;

    debug "Visibility Level:$pargs->{visibility}" if $DEBUG;

	my $xmip = SQL::Translator::XMI::Parser->new(xml => $data);

    # TODO
    # - Options to set the initial context node so we don't just
    #   blindly do all the classes. e.g. Select a diag name to do.

    my $classes = $xmip->get_classes(
        filter => sub {
            return unless $_->{name};
            return unless is_visible($_, $pargs->{visibility});
            return 1;
        },
        filter_attributes => sub {
            return unless $_->{name};
            return unless is_visible($_, $pargs->{visibility});
            return 1;
        },
    );
    debug "Found ".scalar(@$classes)." Classes: ".join(", ",
        map {$_->{"name"}} @$classes) if $DEBUG;
	debug "Model:",Dumper($xmip->{model}) if $DEBUG;

	#
	# Turn the data from get_classes into a Schema
	#
	$pargs->{classes2schema}->($schema, $classes);

    return 1;
}

1;

# Default conversion sub. Makes all classes into tables using all their
# attributes.
sub classes2schema {
	my ($schema, $classes) = @_;

	foreach my $class (@$classes) {
        # Add the table
        debug "Adding class: $class->{name}";
        my $table = $schema->add_table( name => $class->{name} )
            or die "Schema Error: ".$schema->error;

        #
        # Fields from Class attributes
        #
        foreach my $attr ( @{$class->{attributes}} ) {
			my %data = (
                name           => $attr->{name},
                is_primary_key => $attr->{stereotype} eq "PK" ? 1 : 0,
                #is_foreign_key => $stereotype eq "FK" ? 1 : 0,
            );
			$data{default_value} = $attr->{initialValue}
				if exists $attr->{initialValue};
			$data{data_type} = $attr->{_map_taggedValues}{dataType}{dataValue}
				|| $attr->{dataType}{name};
			$data{size} = $attr->{_map_taggedValues}{size}{dataValue};
			$data{is_nullable}=$attr->{_map_taggedValues}{nullable}{dataValue};

            my $field = $table->add_field( %data ) or die $schema->error;
            $table->primary_key( $field->name ) if $data{'is_primary_key'};
        }

    } # Classes loop
}

1;

__END__

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

Translates XMI (UML models in XML format) into Schema. This basic parser
will just pull out all the classes as tables with fields from their attributes.

For more detail you will need to use a UML profile for data modelling. These are
supported by sub parsers. See their docs for details.

=over 4

=item XML::XMI::Rational

The Rational Software UML Data Modeling Profile

=back

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

=head1 XMI Format

Uses either XMI v1.0 or v1.2. The version to use is detected automatically
from the <XMI> tag in the source file.

The parser has been built using XMI 1.2 generated by PoseidonUML 2, which
says it uses UML 2. So the current conformance is down to Poseidon's idea
of XMI! 1.0 support is based on a Rose file, is less complete and has little
testing.


=head1 BUGS

Seems to be slow. I think this is because the XMI files can get pretty
big and complex, especially all the diagram info, and XPath needs to load the
whole tree.

Deleting the diagrams from an XMI1.2 file (make a backup!) will really speed
things up. Remove <UML:Diagram> tags and all their contents.

=head1 TODO

More profiles.

=head1 AUTHOR

Mark D. Addison E<lt>mark.addison@itn.co.ukE<gt>.

=head1 SEE ALSO

perl(1), SQL::Translator, XML::XPath, SQL::Translator::Producer::XML::SQLFairy,
SQL::Translator::Schema.

=cut


