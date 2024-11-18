package SQL::Translator::Producer::Storable;

=head1 NAME

SQL::Translator::Producer::Storable - serializes the SQL::Translator::Schema
    object via the Storable module

=head1 SYNOPSIS

  use SQL::Translator;

  my $translator = SQL::Translator->new;
  $translator->producer('Storable');

=head1 DESCRIPTION

This module uses Storable to serialize a schema to a string so that it
can be saved to disk.  Serializing a schema and then calling producers
on the stored can realize significant performance gains when parsing
takes a long time.

=cut

use strict;
use warnings;
our ($DEBUG, @EXPORT_OK);
$DEBUG = 0 unless defined $DEBUG;
our $VERSION = '1.66';

use Storable;
use Exporter;
use base qw(Exporter);

@EXPORT_OK = qw(produce);

sub produce {
  my $t          = shift;
  my $args       = $t->producer_args;
  my $schema     = $t->schema;
  my $serialized = Storable::nfreeze($schema);

  return $serialized;
}

1;

=pod

=head1 AUTHOR

Paul Harrington E<lt>harringp@deshaw.comE<gt>.

=head1 SEE ALSO

SQL::Translator, SQL::Translator::Schema, Storable.

=cut
