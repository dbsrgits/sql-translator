package SQL::Translator::Parser::DBI::SQLite;

# -------------------------------------------------------------------
# $Id: SQLite.pm,v 1.2 2003-10-03 18:13:32 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>.
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

Queries the "sqlite_master" table for schema definition.

=cut

use strict;
use DBI;
use SQL::Translator::Parser::SQLite;
use Data::Dumper;

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;
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

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>,
Chris Mungall E<lt>cjm@fruitfly.orgE<gt>.

=head1 SEE ALSO

perl(1), Parse::RecDescent, SQL::Translator::Schema.

=cut
