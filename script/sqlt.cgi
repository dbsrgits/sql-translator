#!/usr/bin/env perl

# -------------------------------------------------------------------
# Copyright (C) 2002-2009 SQLFairy Authors
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

sqlt.cgi - CGI front-end for SQL::Translator

=head1 DESCRIPTION

Place this script in your "cgi-bin" directory and point your browser
to it.  This script is meant to be a simple graphical interface to 
all the parsers and producers of SQL::Translator.

=cut

# -------------------------------------------------------------------

use strict;
use warnings;
use CGI;
use SQL::Translator;

use vars '$VERSION';
$VERSION = '1.59';

my $q = CGI->new;

eval {
    if ( $q->param ) {
        my $data;
        if ( $q->param('schema') ) {
            $data = $q->param('schema');
        }
        elsif ( my $fh = $q->upload('schema_file') ) {
            local $/;
            $data = <$fh>;
        }
        die "No schema provided!\n" unless $data;

        my $producer    = $q->param('producer');
        my $output_type = $producer eq 'Diagram'
            ? $q->param('diagram_output_type')
            : $producer eq 'GraphViz'
            ? $q->param('graphviz_output_type') 
            : ''
        ;

        my $t                    =  SQL::Translator->new( 
            from                 => $q->param('parser'),
            producer_args        => {
                add_drop_table   => $q->param('add_drop_table'),
                output_type      => $output_type,
                title            => $q->param('title')       || 'Schema',
                natural_join     => $q->param('natural_join') eq 'no' ? 0 : 1, 
                join_pk_only     => $q->param('natural_join') eq 'pk_only' 
                                    ? 1 : 0,
                add_color        => $q->param('add_color'),
                skip_fields      => $q->param('skip_fields'),
                show_fk_only     => $q->param('show_fk_only'),
                font_size        => $q->param('font_size'),
                no_columns       => $q->param('no_columns'),
                node_shape       => $q->param('node_shape'),
                layout           => $q->param('layout')      || '',
                height           => $q->param('height')      || 0,
                width            => $q->param('width')       || 0,
                show_fields      => $q->param('show_fields') || 0,
                ttfile           => $q->upload('template'),
                validate         => $q->param('validate'),
                emit_empty_tags  => $q->param('emit_empty_tags'),
                attrib_values    => $q->param('attrib_values'),
                no_comments      => !$q->param('comments'),
            },
            parser_args => {
                trim_fields      => $q->param('trim_fields'),
                scan_fields      => $q->param('scan_fields'),
                field_separator  => $q->param('fs'),
                record_separator => $q->param('rs'),
            },
        ) or die SQL::Translator->error;

        my $image_type = '';
        my $text_type  = 'plain';
        if ( $output_type =~ /(gif|png|jpeg)/ ) {
            $image_type = $output_type;
        }
        elsif ( $output_type eq 'svg' ) {
            $image_type = 'svg+xml';
        }
        elsif ( $output_type =~ /gd/ ) {
            $image_type = 'png';
        }
        elsif ( $output_type eq 'ps' ) {
            $text_type = 'postscript';
        }
        elsif ( $producer eq 'HTML' ) {
            $text_type = 'html';
        }

        my $header_type = $image_type ? "image/$image_type" : "text/$text_type";

        $t->data( $data );
        $t->producer( $producer );
        my $output = $t->translate or die $t->error;

        print $q->header( -type => $header_type ), $output;
    }
    else {
        show_form( $q );
    }
};

if ( my $error = $@ ) {
    print $q->header, $q->start_html('Error'),
        $q->h1('Error'), $error, $q->end_html;
}

# -------------------------------------------------------------------
sub show_form {
    my $q     = shift;
    my $title = 'SQL::Translator';

    print $q->header, 
        $q->start_html( -title => $title ),
        $q->h1( qq[<a href="http://sqlfairy.sourceforge.net">$title</a>] ),
        $q->start_form(-enctype => 'multipart/form-data'),
        $q->table( { -border => 1 },
            $q->Tr( 
                $q->td( [
                    'Upload your schema file:',
                    $q->filefield( -name => 'schema_file'),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Or paste your schema here:',
                    $q->textarea( 
                        -name    => 'schema', 
                        -rows    => 5, 
                        -columns => 60,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Parser:',
                    $q->radio_group(
                        -name    => 'parser',
                        -values  => [ qw( MySQL PostgreSQL Oracle 
                            Sybase Excel XML-SQLFairy xSV  
                        ) ],
                        -default => 'MySQL',
                        -rows    => 3,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Producer:',
                    $q->radio_group(
                        -name    => 'producer',
                        -values  => [ qw[ ClassDBI Diagram GraphViz HTML
                            MySQL Oracle POD PostgreSQL SQLite Sybase
                            TTSchema XML-SQLFairy
                        ] ],
                        -default => 'GraphViz',
                        -rows    => 3,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td(
                    { -colspan => 2, -align => 'center' },
                    $q->submit( 
                        -name  => 'submit', 
                        -value => 'Submit',
                    )
                ),
            ),
            $q->Tr( 
                $q->th( 
                    { align => 'left', bgcolor => 'lightgrey', colspan => 2 }, 
                    'General Options:' 
                ),
            ),
            $q->Tr( 
                $q->td( [
                    'Validate Schema:',
                    $q->radio_group(
                        -name    => 'validate',
                        -values  => [ 1, 0 ],
                        -labels  => { 
                            1    => 'Yes', 
                            0    => 'No' 
                        },
                        -default => 0,
                        -rows    => 2,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->th( 
                    { align => 'left', bgcolor => 'lightgrey', colspan => 2 }, 
                    'DB Producer Options:' 
                ),
            ),
            $q->Tr( 
                $q->td( [
                    'Add &quot;DROP TABLE&quot; statements:',
                    $q->radio_group(
                        -name    => 'add_drop_table',
                        -values  => [ 1, 0 ],
                        -labels  => { 
                            1    => 'Yes', 
                            0    => 'No' 
                        },
                        -default => 0,
                        -rows    => 2,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Include comments:',
                    $q->radio_group(
                        -name    => 'comments',
                        -values  => [ 1, 0 ],
                        -labels  => { 
                            1    => 'Yes', 
                            0    => 'No' 
                        },
                        -default => 1,
                        -rows    => 2,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->th( 
                    { align => 'left', bgcolor => 'lightgrey', colspan => 2 }, 
                    'HTML/POD/Diagram Producer Options:' 
                ),
            ),
            $q->Tr( 
                $q->td( [
                    'Title:',
                    $q->textfield('title'),
                ] ),
            ),
            $q->Tr( 
                $q->th( 
                    { align => 'left', bgcolor => 'lightgrey', colspan => 2 }, 
                    'TTSchema Producer Options:' 
                ),
            ),
            $q->Tr( 
                $q->td( [
                    'Template:',
                    $q->filefield( -name => 'template'),
                ] ),
            ),
            $q->Tr( 
                $q->th( 
                    { align => 'left', bgcolor => 'lightgrey', colspan => 2 }, 
                    'Graphical Producer Options'
                ),
            ),
            $q->Tr( 
                $q->td( [
                    'Perform Natural Joins:',
                    $q->radio_group(
                        -name       => 'natural_join',
                        -values     => [ 'no', 'yes', 'pk_only' ],
                        -labels     => {
                            no      => 'No',
                            yes     => 'Yes, on all like-named fields',
                            pk_only => 'Yes, but only from primary keys'
                        },
                        -default    => 'no',
                        -rows       => 3,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Skip These Fields in Natural Joins:',
                    $q->textarea(
                        -name    => 'skip_fields',
                        -rows    => 3,
                        -columns => 60,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Show Only Foreign Keys:',
                    $q->radio_group(
                        -name    => 'show_fk_only',
                        -values  => [ 1, 0 ],
                        -default => 0,
                        -labels  => {
                            1    => 'Yes',
                            0    => 'No',
                        },
                        -rows    => 2,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Add Color:',
                    $q->radio_group(
                        -name    => 'add_color',
                        -values  => [ 1, 0 ],
                        -labels  => { 
                            1    => 'Yes', 
                            0    => 'No' 
                        },
                        -default => 1,
                        -rows    => 2,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Show Field Names:',
                    $q->radio_group(
                        -name    => 'show_fields',
                        -values  => [ 1, 0 ],
                        -default => 1,
                        -labels  => {
                            1    => 'Yes',
                            0    => 'No',
                        },
                        -rows    => 2,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->th( 
                    { align => 'left', bgcolor => 'lightgrey', colspan => 2 }, 
                    'Diagram Producer Options'
                ),
            ),
            $q->Tr( 
                $q->td( [
                    'Output Type:',
                    $q->radio_group(
                        -name    => 'diagram_output_type',
                        -values  => [ 'png', 'jpeg' ],
                        -default => 'png',
                        -rows    => 2,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Font Size:',
                    $q->radio_group(
                        -name    => 'font_size',
                        -values  => [ qw( small medium large ) ],
                        -default => 'medium',
                        -rows    => 3,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Number of Columns:',
                    $q->textfield('no_columns'),
                ] ),
            ),
            $q->Tr( 
                $q->th( 
                    { align => 'left', bgcolor => 'lightgrey', colspan => 2 }, 
                    'GraphViz Producer Options'
                ),
            ),
            $q->Tr( 
                $q->td( [
                    'Output Type:',
                    $q->radio_group(
                        -name    => 'graphviz_output_type',
                        -values  => [ qw( canon text ps hpgl pcl mif pic
                            gd gd2 gif jpeg png wbmp cmap ismap imap
                            vrml vtx mp fig svg plain
                        ) ],
                        -default => 'png',
                        -rows    => 4,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Layout:',
                    $q->radio_group(
                        -name    => 'layout',
                        -values  => [ qw( dot neato twopi ) ],
                        -default => 'dot',
                        -rows    => 3,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Node Shape:',
                    $q->radio_group(
                        -name    => 'node_shape',
                        -values  => [ qw( record plaintext ellipse 
                            circle egg triangle box diamond trapezium 
                            parallelogram house hexagon octagon 
                        ) ],
                        -default => 'record',
                        -rows    => 4,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Height:',
                    $q->textfield( -name => 'height' ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Width:',
                    $q->textfield( -name => 'width' ),
                ] ),
            ),
            $q->Tr( 
                $q->th( 
                    { align => 'left', bgcolor => 'lightgrey', colspan => 2 }, 
                    'XML Producer Options:' 
                ),
            ),
            $q->Tr( 
                $q->td( [
                    'Use attributes for values:',
                    $q->radio_group(
                        -name    => 'attrib-values',
                        -values  => [ 1, 0 ],
                        -labels  => { 
                            1    => 'Yes', 
                            0    => 'No' 
                        },
                        -default => 0,
                        -rows    => 2,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Emit Empty Tags:',
                    $q->radio_group(
                        -name    => 'emit-empty-tags',
                        -values  => [ 1, 0 ],
                        -labels  => { 
                            1    => 'Yes', 
                            0    => 'No' 
                        },
                        -default => 0,
                        -rows    => 2,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->th( 
                    { align => 'left', bgcolor => 'lightgrey', colspan => 2 }, 
                    'xSV Parser Options'
                ),
            ),
            $q->Tr( 
                $q->td( [
                    'Field Separator:',
                    $q->textfield( -name => 'fs' ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Record Separator:',
                    $q->textfield( -name => 'rs' ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Trim Whitespace Around Fields:',
                    $q->radio_group(
                        -name    => 'trim_fields',
                        -values  => [ 1, 0 ],
                        -default => 1,
                        -labels  => {
                            1    => 'Yes',
                            0    => 'No',
                        },
                        -rows    => 2,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Scan Fields for Data Type:',
                    $q->radio_group(
                        -name    => 'scan_fields',
                        -values  => [ 1, 0 ],
                        -default => 1,
                        -labels  => {
                            1    => 'Yes',
                            0    => 'No',
                        },
                        -rows    => 2,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td(
                    { -colspan => 2, -align => 'center' },
                    $q->submit( 
                        -name  => 'submit', 
                        -value => 'Submit',
                    )
                ),
            ),
        ),
        $q->end_form,
        $q->end_html;
}

# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

L<perl>,
L<SQL::Translator>

=cut
