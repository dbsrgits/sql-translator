package SQL::Translator::Parser::DBI::PostgreSQL;

# -------------------------------------------------------------------
# $Id: PostgreSQL.pm,v 1.2 2003-10-13 19:51:31 phrrngtn Exp $
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

SQL::Translator::Parser::DBI::PostgreSQL - parser for DBD::Pg

=head1 SYNOPSIS

See SQL::Translator::Parser::DBI.

=head1 DESCRIPTION

Uses DBIx::DBSchema.

=cut

use strict;
use DBI;
use DBD::Pg 1.31;
use Data::Dumper;
use SQL::Translator::Schema::Constants;

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

# -------------------------------------------------------------------
sub parse {
    my ( $tr, $dbh ) = @_;

    my $schema = $tr->schema;

    my ($sth, @tables, $columns);
    my $stuff;


    if ($dbh->{FetchHashKeyName} ne 'NAME_uc') {
#        warn "setting dbh attribute {FetchHashKeyName} to NAME_uc";
        $dbh->{FetchHashKeyName} = 'NAME_uc';
    }

    if ($dbh->{ChopBlanks} != 1) {
#        warn "setting dbh attribute {ChopBlanks} to 1";
        $dbh->{ChopBlanks} = 1;
    }

    $sth = $dbh->column_info();
    foreach my $c (@{$sth->fetchall_arrayref({})}) {
        $columns
            ->{$c->{TABLE_SCHEM}}
                ->{$c->{TABLE_NAME}}
                    ->{columns}
                        ->{$c->{COLUMN_NAME}}= $c;
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


            my $cols =
                $columns->{$table_info->{TABLE_SCHEM}}
                        ->{$table_info->{TABLE_NAME}}
                            ->{columns};

            foreach my $c (values %{$cols}) {
                my $f = $table->add_field(
                                          name        => $c->{COLUMN_NAME},
                                          data_type   => $c->{TYPE_NAME},
                                          order       => $c->{ORDINAL_POSITION},
                                          size        => $c->{COLUMN_SIZE},
                                         ) || die $table->error;

                $f->is_nullable(1)
                    if ($c->{NULLABLE} == 1);
            }
        }
    }

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

perl(1), Parse::RecDescent, SQL::Translator::Schema.

=cut
