package SQL::Translator::Producer::SqlfXML;

# -------------------------------------------------------------------
# $Id: SqlfXML.pm,v 1.4 2003-08-14 12:03:00 grommit Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>,
#                    darren chamberlain <darren@cpan.org>,
#                    Chris Mungall <cjm@fruitfly.org>
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
use warnings;
use vars qw[ $VERSION ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/;

use Exporter;
use base qw(Exporter);
our @EXPORT_OK = qw(produce);

use IO::Scalar;
use SQL::Translator::Utils qw(header_comment);
use XML::Writer;

my $namespace = 'http://sqlfairy.sourceforge.net/sqlfairy.xml';
my $name = 'sqlt';

{ 
our ($translator,$PArgs,$schema);

sub debug { $translator->debug(@_,"\n"); } # Shortcut.

sub produce {
    $translator = shift;
    $PArgs      = $translator->producer_args;
    $schema     = $translator->schema;

    my $io       = IO::Scalar->new;
    my $xml         = XML::Writer->new(
        OUTPUT      => $io,
        NAMESPACES  => 1,
        PREFIX_MAP  => { $namespace => $name },
        DATA_MODE   => 1,
        DATA_INDENT => 2,
    );

    $xml->xmlDecl('UTF-8');
    $xml->comment(header_comment('', ''));
    $xml->startTag([ $namespace => 'schema' ]);

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
        $xml->startTag( [ $namespace => 'fields' ] );
        for my $field ( $table->get_fields ) {
            debug "    Field:",$field->name;
			xml_obj($xml, $field,
				tag     =>"field",
				end_tag => 1,
				methods =>[qw/name data_type default_value is_auto_increment
                     is_primary_key is_nullable is_foreign_key order size
				/],
			);
        }
        $xml->endTag( [ $namespace => 'fields' ] );

        #
        # Indices
        #
        $xml->startTag( [ $namespace => 'indices' ] );
        for my $index ( $table->get_indices ) {
            debug "Index:",$index->name;
			xml_obj($xml, $index,
				tag     => "index",
				end_tag => 1,
				methods =>[qw/fields name options type/],
			);
        }
        $xml->endTag( [ $namespace => 'indices' ] );

        #
        # Constraints
        #
        $xml->startTag( [ $namespace => 'constraints' ] );
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
        $xml->endTag( [ $namespace => 'constraints' ] );

        $xml->endTag( [ $namespace => 'table' ] );
    }

    $xml->endTag([ $namespace => 'schema' ]);
    $xml->end;

    return $io;
}

sub xml_obj {
	my ($xml, $obj, %args) = @_;
	my $tag   = $args{tag};
	my @meths = @{$args{methods}};
	my $attrib_values = $PArgs->{attrib_values};
	my $empty_tag = 0;
	my $end_tag   = $args{end_tag};
	if ( $attrib_values and $end_tag ) {
		$empty_tag = 1;
		$end_tag   = 0;
	}

	if ( $attrib_values ) {
		my %attr = map { 
			my $val = $obj->$_;
			($_ => ref($val) eq 'ARRAY' ? join(", ",@$val) : $val);
		} @meths;
		foreach (keys %attr) { delete $attr{$_} unless defined $attr{$_}; }
		$empty_tag ? $xml->emptyTag( [ $namespace => $tag ], %attr )
		           : $xml->startTag( [ $namespace => $tag ], %attr );
	}
	else {
		$xml->startTag( [ $namespace => $tag ] );
		xml_objAttr($xml,$obj, @meths);
	}
	$xml->endTag( [ $namespace => $tag ] ) if $end_tag;

}

# Takes an xml writer, a Schema::* object and a list of methods and adds the
# XML for those methods.
sub xml_objAttr {
    my ($xml, $obj, @methods) = @_;
    my $emit_empty = $PArgs->{emit_empty_tags};
	for my $method (@methods) {
        my $val = $obj->$method;
        debug "        ".ref($obj)."->$method=",
              (defined $val ? "'$val'" : "<UNDEF>");
        next unless $emit_empty || defined $val;
        $val = "" if not defined $val;
        $val = ref $val eq 'ARRAY' ? join(',', @$val) : $val;
        debug "        Adding Attr:".$method."='",$val,"'";
        $xml->dataElement( [ $namespace => $method ], $val );
    }
}

} # End of our scoped bit

1;

# -------------------------------------------------------------------
# The eyes of fire, the nostrils of air,
# The mouth of water, the beard of earth.
# William Blake
# -------------------------------------------------------------------

=head1 NAME

SQL::Translator::Producer::SqlfXML - XML output

=head1 SYNOPSIS

  use SQL::Translator;

  my $translator = SQL::Translator->new(
      show_warnings  => 1,
      add_drop_table => 1,
  );
  print = $obj->translate(
      from     => "MySQL",
      to       => "SqlfXML",
      filename => "fooschema.sql",
  );

=head1 ARGS

Takes the following extra producer args.

=item emit_empty_tags

Default is false, set to true to emit <foo></foo> style tags for undef values
in the schema.

=item attrib_values

Set true to use attributes for values of the schema objects instead of tags.

 <!-- attrib_values => 0 -->
 <table>
   <name>foo</name>
   <order>1</order>
 </table>
 
 <!-- attrib_values => 1 -->
 <table name="foo" order="1">
 </table>
  
=head1 DESCRIPTION

Creates XML output of a schema.

=head1 TODO

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>, 
darren chamberlain E<lt>darren@cpan.orgE<gt>, 
mark addison E<lt>mark.addison@itn.co.ukE<gt>, 

=head1 SEE ALSO

perl(1), SQL::Translator, SQL::Translator::Parser::SqlfXML,
SQL::Translator::Schema, XML::Writer.
