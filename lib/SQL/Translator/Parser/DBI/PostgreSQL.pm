package SQL::Translator::Parser::DBI::PostgreSQL;

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

SQL::Translator::Parser::DBI::PostgreSQL - parser for DBD::Pg

=head1 SYNOPSIS

See SQL::Translator::Parser::DBI.

=head1 DESCRIPTION

Uses DBI to query PostgreSQL system tables to determine schema structure.   

=cut

use strict;
use DBI;
use Data::Dumper;
use SQL::Translator::Schema::Constants;

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = '1.59';
$DEBUG   = 0 unless defined $DEBUG;

# -------------------------------------------------------------------
sub parse {
    my ( $tr, $dbh ) = @_;

    my $schema = $tr->schema;

    my $column_select = $dbh->prepare(
      "SELECT a.attname, t.typname, a.attnum,a.atttypmod as length,
              a.attnotnull, a.atthasdef, d.adsrc
       FROM pg_type t,pg_attribute a
       LEFT JOIN pg_attrdef d ON (d.adrelid = a.attrelid AND a.attnum = d.adnum)
       WHERE a.attrelid=? AND attnum>0
         AND a.atttypid=t.oid
       ORDER BY a.attnum"
    ); 

    my $index_select  = $dbh->prepare(
      "SELECT oid, c.relname, i.indkey, i.indnatts, i.indisunique,
              i.indisprimary, pg_get_indexdef(oid) AS create_string
       FROM pg_class c,pg_index i
       WHERE c.relnamespace=2200 AND c.relkind='i'
         AND c.oid=i.indexrelid AND i.indrelid=?"
    );

    my $table_select  = $dbh->prepare(
      "SELECT oid,relname FROM pg_class WHERE relnamespace IN
          (SELECT oid FROM pg_namespace WHERE nspname='public')
          AND relkind='r';"
    );
    $table_select->execute();

    while ( my $tablehash = $table_select->fetchrow_hashref ) {

        my $table_name = $$tablehash{'relname'};
        my $table_oid  = $$tablehash{'oid'}; 

        my $table = $schema->add_table(
                                       name => $table_name,
              #what is type?               type => $table_info->{TABLE_TYPE},
                                          ) || die $schema->error;

        $column_select->execute($table_oid);

        while (my $columnhash = $column_select->fetchrow_hashref ) {

            #data_type seems to not be populated; perhaps there needs to 
            #be a mapping of query output to reserved constants in sqlt?

            my $col = $table->add_field(
                              name        => $$columnhash{'attname'},
                              default_value => $$columnhash{'adsrc'},
                              data_type   => $$columnhash{'typname'},
                              order       => $$columnhash{'attnum'},
                             ) || die $table->error;

            $col->{size} = [$$columnhash{'length'}] if $$columnhash{'length'}>0;
            $col->{is_nullable} = $$columnhash{'attnotnull'} ? 0 : 1;
        }

        $index_select->execute($table_oid);

        my @column_names = $table->field_names();
        while (my $indexhash = $index_select->fetchrow_hashref ) {
              #don't deal with function indexes at the moment
            next if ($$indexhash{'indkey'} eq '' 
                     or !defined($$indexhash{'indkey'}) );

            my $type;
            if      ($$indexhash{'indisprimary'}) {
                $type = UNIQUE; #PRIMARY_KEY;

                #tell sqlt that this is the primary key:
                my $col_name=$column_names[($$indexhash{'indkey'} - 1)];
                $table->get_field($col_name)->{is_primary_key}=1;

            } elsif ($$indexhash{'indisunique'}) {
                $type = UNIQUE;    
            } else {
                $type = NORMAL;
            }

            my @column_ids = split /\s+/, $$indexhash{'indkey'};
            my @columns;
            foreach my $col (@column_ids) {
                push @columns, $column_names[($col - 1)];
            }

            $table->add_index(
                              name         => $$indexhash{'relname'},
                              type         => $type,
                              fields       => \@columns,
                             ) || die $table->error;
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

Scott Cain E<lt>cain@cshl.eduE<gt>, previous author: 
Paul Harrington E<lt>harringp@deshaw.comE<gt>.

=head1 SEE ALSO

SQL::Translator, DBD::Pg.

=cut
