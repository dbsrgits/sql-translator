package SQL::Translator::Producer::Storable;

# $Source: /home/faga/work/sqlfairy_svn/sqlfairy-cvsbackup/sqlfairy/lib/SQL/Translator/Producer/Storable.pm,v $
# $Id: Storable.pm,v 1.1 2003-10-08 18:24:25 phrrngtn Exp $

=head1 NAME

SQL::Translator::Producer::Storable - null producer for Schema objects that have already been created.

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Producer::Storable;

  my $translator = SQL::Translator->new;
  $translator->producer("SQL::Translator::Producer::Storable");

=head1 DESCRIPTION

Uses Storable to serialize a schema to a string so that it can be
saved on disk or whatever.

=cut

use strict;
use vars qw($DEBUG $VERSION @EXPORT_OK);
$DEBUG = 0 unless defined $DEBUG;
$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;

use Storable;
use Exporter;
use SQL::Translator::Utils qw(debug normalize_name);

use base qw(Exporter);

@EXPORT_OK = qw(produce);

sub produce {
    my $t           = shift;

    my $args        = $t->producer_args;
    my $schema      = $t->schema;
    my $serialized  = Storable::freeze($schema);

    return $serialized;
}

1;

=pod

=head1 AUTHORS

Paul Harrington <harringp@deshaw.com>

=head1 SEE ALSO

SQL::Translator::Parser::Excel;

=cut
