package SQL::Translator::Producer::XML;

# -------------------------------------------------------------------
# $Id: XML.pm,v 1.5 2003-01-27 17:04:48 dlc Exp $
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

=head1 NAME

SQL::Translator::Producer::XML - XML output

=head1 SYNOPSIS

  use SQL::Translator::Producer::XML;

=head1 DESCRIPTION

Meant to create some sort of usable XML output.

=cut

use strict;
use vars qw[ $VERSION $XML ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/;

# -------------------------------------------------------------------
sub produce {
    my ( $translator, $data ) = @_;
    my $indent = 0;
    aggregate( '<schema>', $indent );
    
    $indent++;
    for my $table ( 
        map  { $_->[1] }
        sort { $a->[0] <=> $b->[0] }
        map  { [ $_->{'order'}, $_ ] }
        values %$data
    ) { 
        aggregate( '<table>', $indent );
        $indent++;

        aggregate( "<name>$table->{'table_name'}</name>", $indent );
        aggregate( "<order>$table->{'order'}</order>", $indent );

        #
        # Fields
        #
        aggregate( '<fields>', $indent );
        for my $field ( 
            map  { $_->[1] }
            sort { $a->[0] <=> $b->[0] }
            map  { [ $_->{'order'}, $_ ] }
            values %{ $table->{'fields'} }
        ) {
            aggregate( '<field>', ++$indent );
            $indent++;

            for my $key ( keys %$field ) {
                my $val = defined $field->{ $key } ? $field->{ $key } : '';
                   $val = ref $val eq 'ARRAY' ? join(',', @$val) : $val;
                aggregate( "<$key>$val</$key>", $indent );
            }

            $indent--;
            aggregate( "</field>", $indent-- );
        }
        aggregate( "</fields>", $indent );

        #
        # Indices
        #
        aggregate( '<indices>', $indent );
        for my $index ( @{ $table->{'indices'} } ) {
            aggregate( '<index>', ++$indent );
            $indent++;

            for my $key ( keys %$index ) {
                my $val = defined $index->{ $key } ? $index->{ $key } : '';
                   $val = ref $val eq 'ARRAY' ? join(',', @$val) : $val;
                aggregate( "<$key>$val</$key>", $indent );
            }

            $indent--;
            aggregate( "</index>", $indent-- );
        }
        aggregate( "</indices>", $indent );

        $indent--;
        aggregate( "</table>", $indent );
    }

    $indent--;
    aggregate( '</schema>', $indent );

    return $XML;
}

# -------------------------------------------------------------------
sub aggregate {
    my ( $text, $indent ) = @_;
    $XML .= ('  ' x $indent) . "$text\n";
}

1;

# -------------------------------------------------------------------
# The eyes of fire, the nostrils of air,
# The mouth of water, the beard of earth.
# William Blake
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=head1 SEE ALSO

XML::Dumper;

=cut
