package SQL::Translator::Parser::DBI::SQLite;

# -------------------------------------------------------------------
# Copyright (C) 2002-2009 SQLFairy Authors
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
use DBI;
use SQL::Translator::Parser::SQLite;
use Data::Dumper;

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = '1.59';
$DEBUG   = 0 unless defined $DEBUG;

# -------------------------------------------------------------------
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
