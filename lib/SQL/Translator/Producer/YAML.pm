package SQL::Translator::Producer::YAML;

# -------------------------------------------------------------------
# $Id: YAML.pm,v 1.1 2003-10-08 16:33:13 dlc Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 darren chamberlain <darren@cpan.org>,
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
use vars qw($VERSION);
$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;

use SQL::Translator::Utils qw(header_comment);

sub produce {
    my $translator  = shift;
    my $schema      = $translator->schema;

    return 
        join "\n" => 
            '--- #YAML:1.0',
            #header_comment('', '# '),
            map { view_table($_) } $schema->get_tables;
}

sub view_table {
    my $table = shift;

    return
        sprintf "%s:\n%s\n",
            $table->name,
            join "\n" =>
                map { "    $_" }
                map { view_field($_) } $table->get_fields;
}

sub view_field {
    my $field = shift;

    return
        sprintf("%s: %s" => $field->name),
        map {
            sprintf "    %s: %s" => $_->[0], view($_->[1])
        } (
            [ 'order' =>   $field->order        ],
            [ 'name'  =>   $field->name         ],
            [ 'type'  =>   $field->data_type    ],
            [ 'size'  => [ $field->size  ]      ],
            [ 'extra' => { $field->extra }      ],
        );
}

sub view {
    my $thingie = shift;

    {   ''       => sub { $_[0] },
        'SCALAR' => sub { ${$_[0]} },
        'ARRAY'  => sub { join "\n    - $_", @{$_[0]} },
        'HASH'   => sub { join "\n    " => map { "$_: $_[0]->{$_}" } keys %{$_[0]} },
    }->{ref $thingie}->($thingie);
}

1;
