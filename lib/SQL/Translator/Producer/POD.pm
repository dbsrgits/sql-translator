package SQL::Translator::Producer::POD;

# -------------------------------------------------------------------
# $Id: POD.pm,v 1.1 2003-06-09 05:37:04 kycl4rk Exp $
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
use vars qw[ $VERSION ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(header_comment);

# -------------------------------------------------------------------
sub produce {
    my $t           = shift;
    my $schema      = $t->schema;
    my $schema_name = $schema->name || 'Schema';
    my $args        = $t->producer_args;

    my $pod = "=pod\n\n=head1 DESCRIPTION\n\n$schema_name\n\n=head1 TABLES\n\n";

    for my $table ( $schema->get_tables ) {
        my $table_name = $table->name or next;
        my @fields     = $table->get_fields or next;
        $pod .= "=head2 $table_name\n\n=head3 FIELDS\n\n";

        #
        # Fields
        #
        for my $field ( $table->get_fields ) {
            $pod .= "=head4 " . $field->name . "\n\n=over 4\n\n";

            my $data_type = $field->data_type;
            my $size      = $field->size;
            $data_type   .= "($size)" if $size;

            $pod .= "=item * $data_type\n\n";
            $pod .= "=item * PRIMARY KEY\n\n" if $field->is_primary_key;

            my $default = $field->default_value;
            $pod .= "=item * Default '$default' \n\n" if defined $default;

            $pod .= sprintf( "=item * Nullable '%s' \n\n",
                $field->is_nullable ? 'Yes' : 'No' );

            $pod .= "=back\n\n";
        }

        #
        # Indices
        #
        if ( my @indices = $table->get_indices ) {
            $pod .= "=head3 INDICES\n\n";
            for my $index ( @indices ) {
                $pod .= "=head4 " . $index->type . "\n\n=over 4\n\n";
                $pod .= "=item * Fields = " . 
                    join(', ', $index->fields ) . "\n\n";
                $pod .= "=back\n\n";
            }
        }

        #
        # Constraints
        #
        if ( my @constraints = $table->get_constraints ) {
            $pod .= "=head3 CONSTRAINTS\n\n";
            for my $c ( @constraints ) {
                $pod .= "=head4 " . $c->type . "\n\n=over 4\n\n";
                $pod .= "=item * Fields = " . 
                    join(', ', $c->fields ) . "\n\n";

                if ( $c->type eq FOREIGN_KEY ) {
                    $pod .= "=item * Reference Table = " . 
                        $c->reference_table . "\n\n";
                    $pod .= "=item * Reference Fields = " . 
                        join(', ', $c->reference_fields ) . "\n\n";
                }

                if ( my $update = $c->on_update ) {
                    $pod .= "=item * On update = $update";
                }

                if ( my $delete = $c->on_delete ) {
                    $pod .= "=item * On delete = $delete";
                }

                $pod .= "=back\n\n";
            }
        }
    }

    $pod .= "=head1 PRODUCED BY\n\n" . header_comment('', ''). "=cut";
    return $pod;
}

1;

# -------------------------------------------------------------------
# Expect poison from the standing water.
# William Blake
# -------------------------------------------------------------------

=head1 NAME

SQL::Translator::Producer::POD - POD producer for SQL::Translator

=head1 SYNOPSIS

  use SQL::Translator::Producer::POD;

=head1 DESCRIPTION

Creates a POD description of each table, field, index, and constraint.  
A good starting point for text documentation of a schema.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=head1 SEE ALSO

perldoc perlpod.

=cut
