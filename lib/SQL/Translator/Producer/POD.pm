package SQL::Translator::Producer::POD;

=head1 NAME

SQL::Translator::Producer::POD - POD producer for SQL::Translator

=head1 SYNOPSIS

  use SQL::Translator;

  my $t = SQL::Translator->new( parser => '...', producer => 'POD', '...' );
  print $t->translate;

=head1 DESCRIPTION

Creates a POD description of each table, field, index, and constraint.
A good starting point for text documentation of a schema.  You can
easily convert the output to HTML or text using "perldoc" or other
interesting formats using Pod::POM or Template::Toolkit's POD plugin.

=cut

use strict;
use warnings;
our $VERSION = '1.59';

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(header_comment);

sub produce {
    my $t           = shift;
    my $schema      = $t->schema;
    my $schema_name = $schema->name || 'Schema';
    my $args        = $t->producer_args;
    my $title       = $args->{'title'} || $schema_name;

    my $pod = "=pod\n\n=head1 DESCRIPTION\n\n$title\n\n=head1 TABLES\n\n";

    for my $table ( $schema->get_tables ) {
        my $table_name = $table->name or next;
        my @fields     = $table->get_fields or next;
        $pod .= "=head2 $table_name\n\n=head3 FIELDS\n\n";

        #
        # Fields
        #
        for my $field ( @fields ) {
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
                    $pod .= "=item * Reference Table = L</" .
                        $c->reference_table . ">\n\n";
                    $pod .= "=item * Reference Fields = " .
                        join(', ', map {"L</$_>"} $c->reference_fields ) .
                        "\n\n";
                }

                if ( my $update = $c->on_update ) {
                    $pod .= "=item * On update = $update\n\n";
                }

                if ( my $delete = $c->on_delete ) {
                    $pod .= "=item * On delete = $delete\n\n";
                }

                $pod .= "=back\n\n";
            }
        }
    }

    my $header = ( map { $_ || () } split( /\n/, header_comment('', '') ) )[0];
       $header =~ s/^Created by //;
    $pod .= "=head1 PRODUCED BY\n\n$header\n\n=cut";

    return $pod;
}

1;

# -------------------------------------------------------------------
# Expect poison from the standing water.
# William Blake
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=head2 CONTRIBUTORS

Jonathan Yu E<lt>frequency@cpan.orgE<gt>

=head1 SEE ALSO

perldoc, perlpod, Pod::POM, Template::Manual::Plugins.

=cut
