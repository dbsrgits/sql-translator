package SQL::Translator::Parser::DBI::PostgreSQL;

# -------------------------------------------------------------------
# $Id: PostgreSQL.pm,v 1.7 2004-09-15 21:13:43 schiffbruechige Exp $
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

SQL::Translator::Parser::DBI::PostgreSQL - parser for DBD::Pg

=head1 SYNOPSIS

See SQL::Translator::Parser::DBI.

=head1 DESCRIPTION

Uses DBI methods to determine schema structure.  DBI, of course, 
delegates to DBD::Pg, and versions < 1.31 of DBD::Pg don't return very 
useful information.  It is recommended that you upgrade this module.

=cut

use strict;
use DBI;
use Data::Dumper;
use SQL::Translator::Schema::Constants;

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

# -------------------------------------------------------------------
sub parse {
    my ( $tr, $dbh ) = @_;

    my $schema = $tr->schema;

    my ($sth, @tables, $columns);
    my $stuff;

    warn "DBD:Pg $DBD::Pg::VERSION is not likely to produce anything ".
        "useful. Upgrade to 1.31 or better if available.\n"
        unless ($DBD::Pg::VERSION ge '1.31');

    if ($dbh->{FetchHashKeyName} ne 'NAME_uc') {
        $dbh->{FetchHashKeyName} = 'NAME_uc';
    }

    if ($dbh->{ChopBlanks} != 1) {
        $dbh->{ChopBlanks} = 1;
    }

    $sth = $dbh->table_info();

    @tables   = @{$sth->fetchall_arrayref({})};

    foreach my $table_info (@tables) {
        next
            unless (defined($table_info->{TABLE_TYPE}));

        if ($table_info->{TABLE_TYPE} eq 'TABLE'&&
            $table_info->{TABLE_SCHEM} eq 'public') {
            my $table = $schema->add_table(
                                           name => $table_info->{TABLE_NAME},
                                           type => $table_info->{TABLE_TYPE},
                                          ) || die $schema->error;


            my $cols = $dbh->column_info(undef,
                                         $table_info->{TABLE_SCHEM},
                                         $table_info->{TABLE_NAME},
                                         "%" )->fetchall_arrayref({});

            foreach my $c (@{$cols}) {
                print Dumper($c) if $DEBUG;
                my $f = $table->add_field(
                                        name        => $c->{COLUMN_NAME},
                                        default_value => $c->{COLUMN_DEF},
                                        data_type   => $c->{TYPE_NAME},
                                        order       => $c->{ORDINAL_POSITION},
                                        size        => $c->{COLUMN_SIZE},
                                         ) || die $table->error;

                
                $f->is_nullable($c->{NULLABLE} == 1);
            }
        }
    }

    return 1;
}

1;

# -------------------------------------------------------------------
# Time is a waste of money.
# Oscar Wilde
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Paul Harrington E<lt>harringp@deshaw.comE<gt>.

=head1 SEE ALSO

SQL::Translator, DBD::Pg.

=cut
