package SQL::Translator::Parser::DBI::PostgreSQL;

=head1 NAME

SQL::Translator::Parser::DBI::PostgreSQL - parser for DBD::Pg

=head1 SYNOPSIS

See SQL::Translator::Parser::DBI.

=head1 DESCRIPTION

Uses DBI to query PostgreSQL system tables to determine schema structure.

=cut

use strict;
use warnings;
use DBI;
use Data::Dumper;
use SQL::Translator::Schema::Constants;

our ( $DEBUG, @EXPORT_OK );
our $VERSION = '1.59';
$DEBUG   = 0 unless defined $DEBUG;

my $actions = {c => 'cascade',
               r => 'restrict',
               a => 'no action',
               n => 'set null',
               d => 'set default',
           };

sub parse {
    my ( $tr, $dbh ) = @_;

    my $schema = $tr->schema;

    my $column_select = $dbh->prepare(
      "SELECT a.attname, format_type(t.oid, a.atttypmod) as typname, a.attnum,
              a.atttypmod as length, a.attnotnull, a.atthasdef, ad.adsrc,
              d.description
       FROM pg_type t, pg_attribute a
       LEFT JOIN pg_attrdef ad ON (ad.adrelid = a.attrelid AND a.attnum = ad.adnum)
       LEFT JOIN pg_description d ON (a.attrelid=d.objoid AND a.attnum=d.objsubid)
       WHERE a.attrelid=? AND attnum>0
         AND a.atttypid=t.oid
       ORDER BY a.attnum"
    );

    my $index_select  = $dbh->prepare(
      "SELECT oid, c.relname, i.indkey, i.indnatts, i.indisunique,
              ARRAY(SELECT a.attname
                  FROM pg_attribute a
                  WHERE a.attrelid=i.indrelid AND a.attnum = ANY(i.indkey)
              ) AS attname,
              i.indisprimary, pg_get_indexdef(oid) AS create_string
       FROM pg_class c,pg_index i
       WHERE c.relnamespace IN (SELECT oid FROM pg_namespace WHERE nspname='public') AND c.relkind='i'
         AND c.oid=i.indexrelid AND i.indrelid=?"
    );

    my $table_select  = $dbh->prepare(
      "SELECT c.oid, c.relname, d.description
       FROM pg_class c
       LEFT JOIN pg_description d ON c.oid=d.objoid AND d.objsubid=0
       WHERE relnamespace IN
          (SELECT oid FROM pg_namespace WHERE nspname='public')
          AND relkind='r';"
    );

    my $fk_select = $dbh->prepare(
        q/
SELECT r.conname,
       c.relname,
       d.relname AS frelname,
       r.conkey,
       ARRAY(SELECT column_name::varchar
               FROM information_schema.columns
              WHERE ordinal_position = ANY  (r.conkey)
                AND table_schema = n.nspname
                AND table_name   =   c.relname ) AS fields,
       r.confkey,
       ARRAY(SELECT column_name::varchar
               FROM information_schema.columns
              WHERE ordinal_position = ANY  (r.confkey)
                AND table_schema =   n.nspname
                AND table_name   =   d.relname ) AS reference_fields,
       r.confupdtype,
       r.confdeltype,
       r.confmatchtype

FROM pg_catalog.pg_constraint r

JOIN pg_catalog.pg_class c
  ON c.oid = r.conrelid
 AND r.contype = 'f'

JOIN pg_catalog.pg_class d
  ON d.oid = r.confrelid

JOIN pg_catalog.pg_namespace n
  ON n.oid = c.relnamespace

WHERE pg_catalog.pg_table_is_visible(c.oid)
  AND n.nspname = ?
  AND c.relname = ?
ORDER BY 1;
        /) or die "Can't prepare: $@";

    $table_select->execute();

    while ( my $tablehash = $table_select->fetchrow_hashref ) {

        my $table_name = $$tablehash{'relname'};
        my $table_oid  = $$tablehash{'oid'};
        my $table = $schema->add_table(
                                       name => $table_name,
              #what is type?               type => $table_info->{TABLE_TYPE},
                                          ) || die $schema->error;

        $table->comments($$tablehash{'description'}) if $$tablehash{'description'};

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

            $col->{size} = [$$columnhash{'length'}]
                if $$columnhash{'length'}>0 && $$columnhash{'length'}<=0xFFFF;
            $col->{is_nullable} = $$columnhash{'attnotnull'} ? 0 : 1;
            $col->comments($$columnhash{'description'}) if $$columnhash{'description'};
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
            my @columns = split /\s+/, $$indexhash{'attname'};

            $table->add_index(
                              name         => $$indexhash{'relname'},
                              type         => $type,
                              fields       => \@columns,
                             ) || die $table->error;
        }

        $fk_select->execute('public',$table_name) or die "Can't execute: $@";
        my $fkeys = $fk_select->fetchall_arrayref({});
        $DEBUG and print Dumper $fkeys;
        for my $con (@$fkeys){
            my $con_name         = $con->{conname};
            my $fields           = $con->{fields};
            my $reference_fields = $con->{reference_fields};
            my $reference_table  = $con->{frelname};
            my $on_upd           = $con->{confupdtype};
            my $on_del           = $con->{confdeltype};
            $table->add_constraint(
                                   name   => $con_name,
                                   type   => 'foreign_key',
                                   fields =>  $fields,
                                   reference_fields => $reference_fields,
                                   reference_table => $reference_table,
                                   on_delete  => $actions->{$on_upd},
                                   on_update  => $actions->{$on_del},
                               );
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
