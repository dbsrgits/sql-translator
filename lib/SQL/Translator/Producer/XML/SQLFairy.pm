package SQL::Translator::Producer::XML::SQLFairy;

# -------------------------------------------------------------------
# $Id: SQLFairy.pm,v 1.8 2003-10-21 14:53:08 grommit Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>,
#                    darren chamberlain <darren@cpan.org>,
#                    Chris Mungall <cjm@fruitfly.org>,
#                    Mark Addison <mark.addison@itn.co.uk>.
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

SQL::Translator::Producer::XML::SQLFairy - SQLFairy's default XML format

=head1 SYNOPSIS

  use SQL::Translator;

  my $t              = SQL::Translator->new(
      from           => 'MySQL',
      to             => 'XML-SQLFairy',
      filename       => 'schema.sql',
      show_warnings  => 1,
      add_drop_table => 1,
  );

  print $t->translate;

=head1 ARGS

Takes the following extra producer args.

=over 4

=item * emit_empty_tags

Default is false, set to true to emit <foo></foo> style tags for undef values
in the schema.

=item * attrib_values

Set true to use attributes for values of the schema objects instead of tags.

 <!-- attrib_values => 0 -->
 <table>
   <name>foo</name>
   <order>1</order>
 </table>

 <!-- attrib_values => 1 -->
 <table name="foo" order="1">
 </table>

=back

=head1 DESCRIPTION

Creates XML output of a schema.

=cut

use strict;
use vars qw[ $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/;

use Exporter;
use base qw(Exporter);
@EXPORT_OK = qw(produce);

use IO::Scalar;
use SQL::Translator::Utils qw(header_comment debug);
use XML::Writer;

my $Namespace = 'http://sqlfairy.sourceforge.net/sqlfairy.xml';
my $Name      = 'sqlt';
my $PArgs     = {};

sub produce {
    my $translator  = shift;
    my $schema      = $translator->schema;
    $PArgs          = $translator->producer_args;
    my $io          = IO::Scalar->new;
    my $xml         = XML::Writer->new(
        OUTPUT      => $io,
        NAMESPACES  => 1,
        PREFIX_MAP  => { $Namespace => $Name },
        DATA_MODE   => 1,
        DATA_INDENT => 2,
    );

    $xml->xmlDecl('UTF-8');
    $xml->comment(header_comment('', ''));
    #$xml->startTag([ $Namespace => 'schema' ]);
    xml_obj($xml, $schema,
        tag => "schema", methods => [qw/name database/], end_tag => 0 );

    #
    # Table
    #
    for my $table ( $schema->get_tables ) {
        debug "Table:",$table->name;
		xml_obj($xml, $table,
		 	tag => "table", methods => [qw/name order/], end_tag => 0 );

        #
        # Fields
        #
        $xml->startTag( [ $Namespace => 'fields' ] );
        for my $field ( $table->get_fields ) {
            debug "    Field:",$field->name;
			xml_obj($xml, $field,
				tag     =>"field",
				end_tag => 1,
				methods =>[qw/name data_type default_value is_auto_increment
                    is_primary_key is_nullable is_foreign_key order size
                    comments 
				/],
			);
        }
        $xml->endTag( [ $Namespace => 'fields' ] );

        #
        # Indices
        #
        $xml->startTag( [ $Namespace => 'indices' ] );
        for my $index ( $table->get_indices ) {
            debug "Index:",$index->name;
			xml_obj($xml, $index,
				tag     => "index",
				end_tag => 1,
				methods =>[qw/fields name options type/],
			);
        }
        $xml->endTag( [ $Namespace => 'indices' ] );

        #
        # Constraints
        #
        $xml->startTag( [ $Namespace => 'constraints' ] );
        for my $index ( $table->get_constraints ) {
            debug "Constraint:",$index->name;
			xml_obj($xml, $index,
				tag     => "constraint",
				end_tag => 1,
				methods =>[qw/
                    deferrable expression fields match_type name 
                    options on_delete on_update reference_fields
                    reference_table type/], 
			);
        }
        $xml->endTag( [ $Namespace => 'constraints' ] );

        $xml->endTag( [ $Namespace => 'table' ] );
    }
    
    #
    # Views
    #
    for my $foo ( $schema->get_views ) {
		xml_obj($xml, $foo, tag => "view",
        methods => [qw/name sql fields order/], end_tag => 1 );
    }
    
    #
    # Tiggers
    #
    for my $foo ( $schema->get_triggers ) {
		xml_obj($xml, $foo, tag => "trigger",
        methods => [qw/name perform_action_when database_event fields on_table
        action order/], end_tag => 1 );
    }

    #
    # Procedures
    #
    for my $foo ( $schema->get_procedures ) {
		xml_obj($xml, $foo, tag => "procedure",
        methods => [qw/name sql parameters owner comments order/], end_tag=>1 );
    }
    
    $xml->endTag([ $Namespace => 'schema' ]);
    $xml->end;

    return $io;
}

# -------------------------------------------------------------------
#
# TODO 
# - Doc this sub
# - Should the Namespace be passed in instead of global? Pass in the same
#   as Writer ie [ NS => TAGNAME ]
#
sub xml_obj {
	my ($xml, $obj, %args) = @_;
	my $tag                = $args{'tag'}              || '';
	my $end_tag            = $args{'end_tag'}          || '';
	my $attrib_values      = $PArgs->{'attrib_values'} || '';
	my @meths              = @{ $args{'methods'} };
	my $empty_tag          = 0;

	if ( $attrib_values and $end_tag ) {
		$empty_tag = 1;
		$end_tag   = 0;
	}

	if ( $attrib_values ) {
		my %attr = map { 
			my $val = $obj->$_;
			($_ => ref($val) eq 'ARRAY' ? join(', ', @$val) : $val);
		} @meths;
		foreach ( keys %attr ) { delete $attr{$_} unless defined $attr{$_}; }
        # Convert to array to ensure consistant (ie not hash) ordering of
        # attribs
        my @attr = map { ($_ => $attr{$_}) } sort keys %attr;
        $empty_tag ? $xml->emptyTag( [ $Namespace => $tag ], @attr )
		           : $xml->startTag( [ $Namespace => $tag ], @attr );
	}
	else {
		$xml->startTag( [ $Namespace => $tag ] );
		xml_objAttr( $xml, $obj, @meths );
	}

	$xml->endTag( [ $Namespace => $tag ] ) if $end_tag;
}

# -------------------------------------------------------------------
# Takes an XML writer, a Schema::* object and a list of methods and
# adds the XML for those methods.
#
sub xml_objAttr {
    my ($xml, $obj, @methods) = @_;
    my $emit_empty            = $PArgs->{'emit_empty_tags'};

	for my $method ( sort @methods ) {
        my $val = $obj->$method;
        debug "        ".ref($obj)."->$method=",
              (defined $val ? "'$val'" : "<UNDEF>");
        next unless $emit_empty || defined $val;
        $val = '' if not defined $val;
        $val = ref $val eq 'ARRAY' ? join(',', @$val) : $val;
        debug "        Adding Attr:".$method."='",$val,"'";
        $xml->dataElement( [ $Namespace => $method ], $val );
    }
}

1;

# -------------------------------------------------------------------
# The eyes of fire, the nostrils of air,
# The mouth of water, the beard of earth.
# William Blake
# -------------------------------------------------------------------

=pod

=head1 AUTHORS

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>, 
Darren Chamberlain E<lt>darren@cpan.orgE<gt>, 
Mark Addison E<lt>mark.addison@itn.co.ukE<gt>.

=head1 SEE ALSO

perl(1), SQL::Translator, SQL::Translator::Parser::XML::SQLFairy,
SQL::Translator::Schema, XML::Writer.

=cut
