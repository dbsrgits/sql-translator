package SQL::Translator::Producer::YAML;

# -------------------------------------------------------------------
# $Id: YAML.pm,v 1.3 2003-10-08 22:46:17 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 darren chamberlain <darren@cpan.org>,
#   Ken Y. Clark <kclark@cpan.org>.
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
$VERSION = sprintf "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/;

use YAML qw(Dump);

# -------------------------------------------------------------------
sub produce {
    my $translator  = shift;
    my $schema      = $translator->schema;

    return Dump({
        schema => {
            tables => { 
                map { ($_->name => view_table($_)) } $schema->get_tables,
            },
            views => { 
                map { ($_->name => view_view($_)) } $schema->get_views,
            },
            triggers => { 
                map { ($_->name => view_trigger($_)) } $schema->get_triggers,
            },
            procedures => { 
                map { ($_->name => view_procedure($_)) } 
                $schema->get_procedures,
            },
        }
    });
}

# -------------------------------------------------------------------
sub view_table {
    my $table = shift;
    my $name = $table->name;

    return {
        'name'     => $table->name,
        'order'    => $table->order,
        'options'  => $table->options  || [],
        'comments' => $table->comments || '',
        'fields'   => { 
            map { ($_->name => view_field($_)) } $table->get_fields 
        },
    };
}

# -------------------------------------------------------------------
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

# -------------------------------------------------------------------
sub view_procedure {
    my $procedure = shift;

    return {
        'order'      => scalar $procedure->order,
        'name'       => scalar $procedure->name,
        'sql'        => scalar $procedure->sql,
        'parameters' => scalar $procedure->parameters,
        'owner'      => scalar $procedure->owner,
        'comments'   => scalar $procedure->comments,
    };
}

# -------------------------------------------------------------------
sub view_trigger {
    my $trigger = shift;

    return {
        'order'               => scalar $trigger->order,
        'name'                => scalar $trigger->name,
        'perform_action_when' => scalar $trigger->perform_action_when,
        'database_event'      => scalar $trigger->database_event,
        'fields'              => scalar $trigger->fields,
        'on_table'            => scalar $trigger->on_table,
        'action'              => scalar $trigger->action,
    };
}

# -------------------------------------------------------------------
sub view_view {
    my $view = shift;

    return {
        'order'  => scalar $view->order,
        'name'   => scalar $view->name,
        'sql'    => scalar $view->sql,
        'fields' => scalar $view->fields,
    };
}

1;

=head1 NAME

SQL::Translator::Producer::YAML - A YAML producer for SQL::Translator

=head1 AUTHORS

darren chamberlain E<lt>darren@cpan.orgE<gt>,
Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=cut
