package SQL::Translator::Producer::SqlfXML;

# -------------------------------------------------------------------
# $Id: SqlfXML.pm,v 1.3 2003-08-08 12:30:20 grommit Exp $
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
$VERSION = sprintf "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/;

use Exporter;
use base qw(Exporter);
our @EXPORT_OK = qw(produce);

use IO::Scalar;
use SQL::Translator::Utils qw(header_comment);
use XML::Writer;

my $namespace = 'http://sqlfairy.sourceforge.net/sqlfairy.xml';
my $name = 'sqlt';

{ 
our ($translator,$args,$schema);

sub debug { $translator->debug(@_,"\n"); } # Shortcut.

sub produce {
    $translator = shift;
    $args       = $translator->producer_args;
    $schema  = $translator->schema;

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
        $xml->startTag( [ $namespace => 'table' ] );
        xml_objAttr($xml,$table, qw/name order/);
        
        #
        # Fields
        #
        $xml->startTag( [ $namespace => 'fields' ] );
        for my $field ( $table->get_fields ) {
            debug "    Field:",$field->name;
            $xml->startTag( [ $namespace => 'field' ] );
            xml_objAttr($xml,$field, qw/ 
                     name data_type default_value is_auto_increment 
                     is_primary_key is_nullable is_foreign_key order size
            /);
            $xml->endTag( [ $namespace => 'field' ] );
        }
        $xml->endTag( [ $namespace => 'fields' ] );

        #
        # Indices
        #
        $xml->startTag( [ $namespace => 'indices' ] );
        for my $index ( $table->get_indices ) {
            debug "Index:",$index->name;
            $xml->startTag( [ $namespace => 'index' ] );
            xml_objAttr($xml,$index, qw/fields name options type/);
            $xml->endTag( [ $namespace => 'index' ] );
        }
        $xml->endTag( [ $namespace => 'indices' ] );

        #
        # Constraints
        #
        $xml->startTag( [ $namespace => 'constraints' ] );
        for my $index ( $table->get_constraints ) {
            debug "Constraint:",$index->name;
            $xml->startTag( [ $namespace => 'constraint' ] );
            xml_objAttr($xml,$index, qw/
                    deferrable expression fields match_type name 
                    options on_delete on_update reference_fields
                    reference_table type 
            /);
            $xml->endTag( [ $namespace => 'constraint' ] );
        }
        $xml->endTag( [ $namespace => 'constraints' ] );

        $xml->endTag( [ $namespace => 'table' ] );
    }

    $xml->endTag([ $namespace => 'schema' ]);
    $xml->end;

    return $io;
}

# Takes an xml writer, a Schema:: object and a list of methods and adds the
# XML for those methods.
sub xml_objAttr {
    my ($xml, $obj, @methods) = @_;
    for my $method (@methods) {
        my $val = $obj->$method;
        debug "        ".ref($obj)."->$method=",
              (defined $val ? "'$val'" : "<UNDEF>");
        next unless $args->{emit_empty_tags} || defined $val;
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
