package SQL::Translator::Producer::YAML;

# -------------------------------------------------------------------
# $Id: YAML.pm,v 1.2 2003-10-08 17:27:40 dlc Exp $
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
$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;

use YAML qw(Dump);

sub produce {
    my $translator  = shift;
    my $schema      = $translator->schema;

    return Dump({
        schema => {
            map { ($_->name => view_table($_)) } $schema->get_tables
        }
    });
}

sub view_table {
    my $table = shift;
    my $name = $table->name;

    return {
        map { ($_->name => view_field($_)) } $table->get_fields
    };
}

sub view_field {
    my $field = shift;

    return {
        'order' => scalar $field->order,
        'name'  => scalar $field->name,
        'type'  => scalar $field->data_type,
        'size'  => [ $field->size ],
        'extra' => { $field->extra },
    };
}

1;

=head1 NAME

SQL::Translator::Producer::YAML - A YAML producer for SQL::Translator
