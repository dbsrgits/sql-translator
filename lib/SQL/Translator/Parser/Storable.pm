package SQL::Translator::Parser::Storable;

# $Source: /home/faga/work/sqlfairy_svn/sqlfairy-cvsbackup/sqlfairy/lib/SQL/Translator/Parser/Storable.pm,v $
# $Id: Storable.pm,v 1.1 2003-10-08 18:24:25 phrrngtn Exp $

=head1 NAME

SQL::Translator::Parser::Storable - null parser for Schema objects that have already been created.

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::Storable;

  my $translator = SQL::Translator->new;
  $translator->parser("SQL::Translator::Parser::Storable");

=head1 DESCRIPTION

Slurps in a Schema from a Storable file on disk.  You can then turn
the data into a database tables or graphs.

=cut

use strict;
use vars qw($DEBUG $VERSION @EXPORT_OK);
$DEBUG = 0 unless defined $DEBUG;
$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;

use Storable;
use Exporter;
use SQL::Translator::Utils qw(debug normalize_name);

use base qw(Exporter);

@EXPORT_OK = qw(parse);

sub parse {
    my ($translator, $data) = @_;

    $translator->{'schema'} = Storable::thaw($data)
        if defined($data);

    $translator->{'schema'} = Storable::retrieve($translator->filename)
        if defined($translator->filename);

    return 1;
}

1;

=pod

=head1 SEE ALSO

SQL::Translator::Parser::Excel;

=head1 AUTHORS

Paul Harrington <harringp@deshaw.com>

=cut
