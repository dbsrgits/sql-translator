package SQL::Translator::Producer::SqlfXML;

# -------------------------------------------------------------------
# $Id: SqlfXML.pm,v 1.2 2003-08-07 16:53:40 grommit Exp $
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
use vars qw[ $VERSION ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;

use IO::Scalar;
use SQL::Translator::Utils qw(header_comment);
use XML::Writer;

my $namespace = 'http://sqlfairy.sourceforge.net/sqlfairy.xml';
my $name = 'sqlt';

# -------------------------------------------------------------------
sub produce {
    my $translator = shift;
    my $schema     = $translator->schema;
    my $args       = $translator->producer_args;

    my $io          = IO::Scalar->new;
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

    for my $table ( $schema->get_tables ) {
        my $table_name = $table->name or next;
        $xml->startTag   ( [ $namespace => 'table' ] );
        $xml->dataElement( [ $namespace => 'name'  ], $table_name );
        $xml->dataElement( [ $namespace => 'order' ], $table->order );

        #
        # Fields
        #
        $xml->startTag( [ $namespace => 'fields' ] );
        for my $field ( $table->get_fields ) {
            $xml->startTag( [ $namespace => 'field' ] );

            for my $method ( 
                qw[ 
                    name data_type default_value is_auto_increment 
                    is_primary_key is_nullable is_foreign_key order size
                ]
            ) {
                my $val = $field->$method;
                next unless $args->{emit_empty_tags} || defined $val;
                $val = "" if not defined $val;
                $xml->dataElement( [ $namespace => $method ], $val );
            }

            $xml->endTag( [ $namespace => 'field' ] );
        }

        $xml->endTag( [ $namespace => 'fields' ] );

        #
        # Indices
        #
        $xml->startTag( [ $namespace => 'indices' ] );
        for my $index ( $table->get_indices ) {
            $xml->startTag( [ $namespace => 'index' ] );

            for my $method ( qw[ fields name options type ] ) {
                my $val = $index->$method;
                next unless $args->{emit_empty_tags} || defined $val;
                $val = "" if not defined $val;
                $val = ref $val eq 'ARRAY' ? join(',', @$val) : $val;
                $xml->dataElement( [ $namespace => $method ], $val )
            }

            $xml->endTag( [ $namespace => 'index' ] );
        }
        $xml->endTag( [ $namespace => 'indices' ] );

        #
        # Constraints
        #
        $xml->startTag( [ $namespace => 'constraints' ] );
        for my $index ( $table->get_constraints ) {
            $xml->startTag( [ $namespace => 'constraint' ] );

            for my $method ( 
                qw[ 
                    deferrable expression fields match_type name 
                    options on_delete on_update reference_fields
                    reference_table type 
                ] 
            ) {
                my $val = $index->$method;
                next unless $args->{emit_empty_tags} || defined $val;
                $val = "" if not defined $val;
                $val = ref $val eq 'ARRAY' ? join(',', @$val) : $val;
                $xml->dataElement( [ $namespace => $method ], $val )
            }

            $xml->endTag( [ $namespace => 'constraint' ] );
        }
        $xml->endTag( [ $namespace => 'constraints' ] );

        $xml->endTag( [ $namespace => 'table' ] );
    }

    $xml->endTag([ $namespace => 'schema' ]);
    $xml->end;

    return $io;
}

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

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>, darren chamberlain E<lt>darren@cpan.orgE<gt>

=head1 SEE ALSO

perl(1), SQL::Translator, SQL::Translator::Parser::SqlfXML,
SQL::Translator::Schema, XML::Writer.
