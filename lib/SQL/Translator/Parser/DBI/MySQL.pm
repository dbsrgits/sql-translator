package SQL::Translator::Parser::DBI::MySQL;

# -------------------------------------------------------------------
# $Id: MySQL.pm,v 1.6 2006-02-22 22:52:51 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2002-4 SQLFairy Authors
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

SQL::Translator::Parser::DBI::MySQL - parser for DBD::mysql

=head1 SYNOPSIS

This module will be invoked automatically by SQL::Translator::Parser::DBI,
so there is no need to use it directly.

=head1 DESCRIPTION

Uses SQL calls to query database directly for schema rather than parsing
a create file.  Should be much faster for larger schemas.

=cut

use strict;
use DBI;
use Data::Dumper;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Parser::MySQL;

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

# -------------------------------------------------------------------
sub parse {
    my ( $tr, $dbh ) = @_;
    my $schema       = $tr->schema;
    my @table_names  = @{ $dbh->selectcol_arrayref('show tables') };

    $dbh->{'FetchHashKeyName'} = 'NAME_lc';

    my $create;
    for my $table_name ( @table_names ) {
        my $sth = $dbh->prepare("show create table $table_name");
        $sth->execute;
        my $table = $sth->fetchrow_hashref;
        $create .= $table->{'create table'} . ";\n\n";
    }

    SQL::Translator::Parser::MySQL::parse( $tr, $create );

    return 1;
}

1;

# -------------------------------------------------------------------
# Where man is not nature is barren.
# William Blake
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

SQL::Translator.

=cut
