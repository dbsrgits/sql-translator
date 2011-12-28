package SQL::Translator::Parser::DBI::SQLite;

=head1 NAME

SQL::Translator::Parser::DBI::SQLite - parser for DBD::SQLite

=head1 SYNOPSIS

See SQL::Translator::Parser::DBI.

=head1 DESCRIPTION

Queries the "sqlite_master" table for schema definition.  The schema
is held in this table simply as CREATE statements for the database
objects, so it really just builds up a string of all these and passes
the result to the regular SQLite parser.  Therefore there is no gain
(at least in performance) to using this module over simply dumping the
schema to a text file and parsing that.

=cut

use strict;
use warnings;
use DBI;
use SQL::Translator::Parser::SQLite;
use Data::Dumper;

our ( $DEBUG, @EXPORT_OK );
our $VERSION = '1.59';
$DEBUG   = 0 unless defined $DEBUG;

sub parse {
    my ( $tr, $dbh ) = @_;

    my $create = join(";\n",
        map { $_ || () }
        @{ $dbh->selectcol_arrayref('select sql from sqlite_master') },
    );
    $create .= ";";
    $tr->debug( "create =\n$create\n" );

    my $schema = $tr->schema;

    SQL::Translator::Parser::SQLite::parse( $tr, $create );
    return 1;
}

1;

# -------------------------------------------------------------------
# Where man is not nature is barren.
# William Blake
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

SQL::Translator::Parser::SQLite.

=cut
