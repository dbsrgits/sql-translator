#!/usr/bin/perl

# -------------------------------------------------------------------
# $Id: auto-viv.cgi,v 1.1 2003-04-24 19:58:39 kycl4rk Exp $
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

=head1 NAME

auto-viv.cgi

=head1 DESCRIPTION

A CGI script for transforming SQL schemas into pictures, either GraphViz
graphs or ER diagrams.  Basically, a simple web-form front-end for the
myriad options available to "auto-dia.pl" and "auto-graph.pl."

=cut

use strict;
use CGI;
use SQL::Translator;

my $q = CGI->new;

eval {
    if ( $q->param ) {
        my $t                =  SQL::Translator->new( 
            from             => $q->param('database'),
            producer_args    => {
                image_type   => $q->param('output_type') || 'png',
                title        => $q->param('title')       || 'Schema',
                natural_join => $q->param('natural_join') eq 'no' ? 0 : 1, 
                join_pk_only => $q->param('natural_join') eq 'pk_only' ? 1 : 0,
                add_color    => $q->param('add_color'),
                skip_fields  => $q->param('skip_fields'),
                show_fk_only => $q->param('show_fk_only'),
                font_size    => $q->param('font_size'),
                no_columns   => $q->param('no_columns'),
                node_shape   => $q->param('node_shape'),
            },
        ) or die SQL::Translator->error;

        my $data;
        if ( $q->param('schema') ) {
            $data = $q->param('schema');
        }
        elsif ( my $fh = $q->upload('schema_file') ) {
            local $/;
            $data = <$fh>;
        }

        die "No schema provided!\n" unless $data;
        $t->data( $data );
        $t->producer( $q->param('do_graph') ? 'GraphViz' : 'Diagram' );
        my $output = $t->translate or die $t->error;

        my $image_type = $q->param('output_type') || 'png';
        print $q->header( -type => "image/$image_type" ), $output;
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
                    'Paste your schema here:',
                    $q->textarea( 
                        -name    => 'schema', 
                        -rows    => 10, 
                        -columns => 60,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Or upload your schema file:',
                    $q->filefield( -name => 'schema_file'),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Database:',
                    $q->radio_group(
                        -name    => 'database',
                        -values  => [ 'MySQL', 'PostgreSQL', 'Oracle' ],
                        -default => 'MySQL',
                        -rows    => 3,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Title:',
                    $q->textfield('title'),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Output Type:',
                    $q->radio_group(
                        -name    => 'output_type',
                        -values  => [ 'png', 'jpeg' ],
                        -default => 'png',
                        -rows    => 2,
                    ),
                ] ),
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
                    'Color:',
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
                    'Show Only Foreign Keys *:',
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
                    'Font Size *:',
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
                    'Number of Columns *:',
                    $q->textfield('no_columns'),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Layout **:',
                    $q->radio_group(
                        -name    => 'layout',
                        -values  => [ qw( dot neato twopi ) ],
                        -default => 'neato',
                        -rows    => 3,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td( [
                    'Node Shape **:',
                    $q->radio_group(
                        -name    => 'node_shape',
                        -values  => [ qw( record plaintext ellipse 
                            circle egg triangle box diamond trapezium 
                            parallelogram house hexagon octagon 
                        ) ],
                        -default => 'ellipse',
                        -rows    => 13,
                    ),
                ] ),
            ),
            $q->Tr( 
                $q->td(
                    { -colspan => 2, -align => 'center' },
                    $q->submit( 
                        -name  => 'do_diagram', 
                        -value => 'Create ER Diagram' 
                    ),
                    $q->submit( 
                        -name  => 'do_graph', 
                        -value => 'Create Graph' 
                    ),
                    $q->br,
                    q[
                        <small>
                        * -- Applies to diagram only<br>
                        ** -- Applies to graph only<br>
                        </small>
                    ],
                ),
            ),
        ),
        $q->end_form,
        $q->end_html;
}

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
