package SQL::Translator::Parser::Storable;

# $Source: /home/faga/work/sqlfairy_svn/sqlfairy-cvsbackup/sqlfairy/lib/SQL/Translator/Parser/Storable.pm,v $
# $Id: Storable.pm,v 1.2 2003-10-08 20:35:52 phrrngtn Exp $

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
$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;

use Storable;
use Exporter;
use SQL::Translator::Utils qw(debug normalize_name);

use base qw(Exporter);

@EXPORT_OK = qw(parse);

sub parse {
    my ($translator, $data) = @_;

    if (defined($data)) {
        $translator->{'schema'} = Storable::thaw($data);
        return 1;
    } elsif (defined($translator->filename)) {
        $translator->{'schema'} = Storable::retrieve($translator->filename);
        return 1;
    }

    return 0;
}

1;

=pod

=head1 SEE ALSO

SQL::Translator::Parser::Excel;

=head1 AUTHORS

Paul Harrington <harringp@deshaw.com>

=cut
