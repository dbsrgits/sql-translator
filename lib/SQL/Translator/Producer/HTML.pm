package SQL::Translator::Producer::HTML;

# -------------------------------------------------------------------
# $Id: HTML.pm,v 1.5 2003-08-14 16:57:17 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>
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
use CGI;
use vars qw[ $VERSION ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(header_comment);

# -------------------------------------------------------------------
sub produce {
    my $t           = shift;
    my $schema      = $t->schema;
    my $schema_name = $schema->name || 'Schema';
    my $args        = $t->producer_args;
    my $q           = CGI->new;
    my $title       = $args->{'title'} || "Description of $schema_name";

    my $html  = $q->start_html( 
        { -title => $title, -bgcolor => 'lightgoldenrodyellow' } 
    ) .  $q->h1( $title ).  '<a name="top">', $q->hr;

    if ( my @table_names = map { $_->name } $schema->get_tables ) {
        $html .= $q->start_table( { -width => '100%' } ).
            $q->Tr( { -bgcolor => 'khaki' }, $q->td( $q->h2('Tables') ) );

        for my $table ( @table_names ) {
            $html .= $q->Tr( $q->td( qq[<a href="#$table">$table</a>] ) );
        }
        $html .= $q->end_table;
    }

    for my $table ( $schema->get_tables ) {
        my $table_name = $table->name or next;
        my @fields     = $table->get_fields or next;
        $html .= $q->table( 
            { -width => '100%' },
            $q->Tr(
                { -bgcolor => 'khaki' },
                $q->td( $q->h3( $table_name ) ) . qq[<a name="$table_name">],
                $q->td( { -align => 'right' }, qq[<a href="#top">Top</a>] )
            )
        );

        #
        # Fields
        #
        $html .= $q->start_table( { -border => 1 } ) . $q->Tr(
            { -bgcolor => 'lightgrey' },
            $q->th( [ 
                'Field Name', 
                'Data Type', 
                'Size', 
                'Default', 
                'Other', 
                'Foreign Key' 
            ] ) 
        );

        for my $field ( @fields ) {
            my $name      = $field->name;
               $name      = qq[<a name="$table_name-$name">$name</a>];
            my $data_type = $field->data_type;
            my $size      = $field->size;
            my $default   = $field->default_value;
            my $comment   = $field->comments || '';

            my $fk;
            if ( $field->is_foreign_key ) {
                my $c = $field->foreign_key_reference;
                my $ref_table = $c->reference_table || '';
                my $ref_field = ($c->reference_fields)[0];
                $fk = 
                qq[<a href="#$ref_table-$ref_field">$ref_table.$ref_field</a>];
            }

            my @other;
            push @other, 'PRIMARY KEY' if $field->is_primary_key;
            push @other, 'UNIQUE'      if $field->is_unique;
            push @other, 'NOT NULL'    unless $field->is_nullable;
            push @other, $comment      if $comment;
            $html .= $q->Tr( $q->td(
                { -bgcolor => 'white' },
                [ $name, $data_type, $size, $default, join(', ', @other), $fk ]
            ) );
        }
        $html .= $q->end_table;

        #
        # Indices
        #
        if ( my @indices = $table->get_indices ) {
            $html .= $q->h3('Indices');
            $html .= $q->start_table( { -border => 1 } ) . $q->Tr(
                { -bgcolor => 'lightgrey' }, 
                $q->th( [ 'Name', 'Fields' ] ) 
            );

            for my $index ( @indices ) {
                $html .= $q->Tr( 
                    { -bgcolor => 'white' },
                    $q->td( [ $index->name, join( ', ', $index->fields ) ] )
                );
            }

            $html .= $q->end_table;
        }

        $html .= $q->hr;
    }

    $html .= qq[Created by <a href="http://sqlfairy.sourceforge.net">].
        qq[SQL::Translator</a>];

    return $html;
}

1;

# -------------------------------------------------------------------
# Always be ready to speak your mind,
# and a base man will avoid you.
# William Blake
# -------------------------------------------------------------------

=head1 NAME

SQL::Translator::Producer::HTML - HTML producer for SQL::Translator

=head1 SYNOPSIS

  use SQL::Translator::Producer::HTML;

=head1 DESCRIPTION

Creates an HTML document describing the tables.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
