package SQL::Translator::Parser::DBI::Oracle;

# -------------------------------------------------------------------
# Copyright (C) 2006-2009 SQLFairy Authors
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

SQL::Translator::Parser::DBI::Oracle - parser for DBD::Oracle

=head1 SYNOPSIS

See SQL::Translator::Parser::DBI.

=head1 DESCRIPTION

Uses DBI introspection methods to determine schema details.

=cut

use strict;
use warnings;
use DBI;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Schema::Table;
use SQL::Translator::Schema::Field;
use SQL::Translator::Schema::Constraint;

our $VERSION = '1.59';

# -------------------------------------------------------------------
sub parse {
    my ( $tr, $dbh ) = @_;

    my $schema = $tr->schema;

    my $db_user = uc $tr->parser_args()->{db_user};
    my $sth = $dbh->table_info(undef, $db_user, '%', 'TABLE');

    while(my $table_info = $sth->fetchrow_hashref('NAME_uc')) {
        next if ($table_info->{TABLE_NAME} =~ /\$/);

        # create the table

        my $table = $schema->add_table(
            name => $table_info->{TABLE_NAME},
            type => $table_info->{TABLE_TYPE},
        );

        # add the fields (columns) for this table

        my $sth;

        $sth = $dbh->column_info(
            undef,
            $table_info->{TABLE_SCHEM},
            $table_info->{TABLE_NAME},
            '%'
        );

        while(my $column = $sth->fetchrow_hashref('NAME_uc')) {
            my $f = $table->add_field(
                name          => $column->{COLUMN_NAME},
                default_value => $column->{COLUMN_DEF},
                data_type     => $column->{TYPE_NAME},
                order         => $column->{ORDINAL_POSITION},
                size          => $column->{COLUMN_SIZE},
            ) || die $table->error;

            $f->is_nullable( $column->{NULLABLE} == 1 );
        }

        # add the primary key info

        $sth = $dbh->primary_key_info(
            undef,
            $table_info->{TABLE_SCHEM},
            $table_info->{TABLE_NAME},
        );

        while(my $primary_key = $sth->fetchrow_hashref('NAME_uc')) {
            my $f = $table->get_field( $primary_key->{COLUMN_NAME} );
            $f->is_primary_key(1);
        }

        # add the foreign key info (constraints)

        $sth = $dbh->foreign_key_info(
            undef,
            undef,
            undef,
            undef,
            $table_info->{TABLE_SCHEM},
            $table_info->{TABLE_NAME},
        );

        my $cons = {};
        while(my $foreign_key = $sth->fetchrow_hashref('NAME_uc')) {
            my $name = $foreign_key->{FK_NAME};
            $cons->{$name}->{reference_table} = $foreign_key->{UK_TABLE_NAME};
            push @{ $cons->{$name}->{fields} },
                $foreign_key->{FK_COLUMN_NAME};
            push @{ $cons->{$name}->{reference_fields} },
                $foreign_key->{UK_COLUMN_NAME};
        }

        for my $name ( keys %$cons ) {
            my $c = $table->add_constraint(
                type             => FOREIGN_KEY,
                name             => $name,
                fields           => $cons->{$name}->{fields},
                reference_fields => $cons->{$name}->{reference_fields},
                reference_table  => $cons->{$name}->{reference_table},
            ) || die $table->error;
        }
    }

    return 1;
}

1;

=pod

=head1 AUTHOR

Earl Cahill E<lt>cpan@spack.netE<gt>.

=head1 ACKNOWLEDGEMENT

Initial revision of this module came almost entirely from work done by 
Todd Hepler E<lt>thepler@freeshell.orgE<gt>.  My changes were
quite minor (ensuring NAME_uc, changing a couple variable names, 
skipping tables with a $ in them).

Todd claimed his work to be an almost verbatim copy of
SQL::Translator::Parser::DBI::PostgreSQL revision 1.7

For me, the real work happens in DBD::Oracle and DBI, which, also
for me, that is the beauty of having introspection methods in DBI.

=head1 SEE ALSO

SQL::Translator, DBD::Oracle.

=cut
