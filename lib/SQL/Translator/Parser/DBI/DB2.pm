package SQL::Translator::Parser::DBI::DB2;

=head1 NAME

SQL::Translator::Parser::DBI::DB2 - parser for DBD::DB2

=head1 SYNOPSIS

See SQL::Translator::Parser::DBI.

=head1 DESCRIPTION

Uses DBI methods to determine schema structure.  DBI, of course,
delegates to DBD::DB2.

=cut

use strict;
use warnings;
use DBI;
use Data::Dumper;
use SQL::Translator::Parser::DB2;
use SQL::Translator::Schema::Constants;

our ($DEBUG, $VERSION, @EXPORT_OK );
# $VERSION = '1.59';
$DEBUG   = 0 unless defined $DEBUG;

sub parse {
    my ( $tr, $dbh ) = @_;

    my $schema = $tr->schema;

    my ($sth, @tables, $columns);
    my $stuff;

    if ($dbh->{FetchHashKeyName} ne 'NAME_uc') {
        $dbh->{FetchHashKeyName} = 'NAME_uc';
    }

    if ($dbh->{ChopBlanks} != 1) {
        $dbh->{ChopBlanks} = 1;
    }

    my $tabsth = $dbh->prepare(<<SQL);
SELECT t.TABSCHEMA,
       t.TABNAME,
       t.TYPE,
      ts.TBSPACE
FROM SYSCAT.TABLES t
JOIN SYSCAT.TABLESPACES ts ON t.TBSPACEID = ts.TBSPACEID
WHERE t.TABSCHEMA NOT LIKE 'SYS%'
ORDER BY t.TABNAME ASC
SQL
#    $sth = $dbh->table_info();
#    @tables   = @{$sth->fetchall_arrayref({})};

    my $colsth = $dbh->prepare(<<SQL);
SELECT c.TABSCHEMA,
       c.TABNAME,
       c.COLNAME,
       c.TYPENAME,
       c.LENGTH,
       c.DEFAULT,
       c.NULLS,
       c.COLNO
FROM SYSCAT.COLUMNS c
WHERE c.TABSCHEMA NOT LIKE 'SYS%' AND
     c.TABNAME = ?
ORDER BY COLNO
SQL

    my $consth = $dbh->prepare(<<SQL);
SELECT tc.TABSCHEMA,
       tc.TABNAME,
       kc.CONSTNAME,
       kc.COLNAME,
       tc.TYPE,
       tc.CHECKEXISTINGDATA
FROM SYSCAT.TABCONST tc
JOIN SYSCAT.KEYCOLUSE kc ON tc.CONSTNAME = kc.CONSTNAME AND
                            tc.TABSCHEMA = kc.TABSCHEMA AND
                            tc.TABNAME   = kc.TABNAME
WHERE tc.TABSCHEMA NOT LIKE 'SYS%' AND
      tc.TABNAME = ?
SQL

    my $indsth = $dbh->prepare(<<SQL);
SELECT i.INDSCHEMA,
       i.INDNAME,
       i.TABSCHEMA,
       i.TABNAME,
       i.UNIQUERULE,
       i.INDEXTYPE,
       ic.COLNAME
FROM SYSCAT.INDEXES i
JOIN SYSCAT.INDEXCOLUSE ic ON i.INDSCHEMA = ic.INDSCHEMA AND
                              i.INDNAME = ic.INDNAME
WHERE i.TABSCHEMA NOT LIKE 'SYS%' AND
      i.INDEXTYPE <> 'P' AND
      i.TABNAME = ?
SQL

    my $trigsth = $dbh->prepare(<<SQL);
SELECT t.TRIGSCHEMA,
       t.TRIGNAME,
       t.TABSCHEMA,
       t.TRIGTIME,
       t.TRIGEVENT,
       t.GRANULARITY,
       t.TEXT
FROM SYSCAT.TRIGGERS t
WHERE t.TABSCHEMA NOT LIKE 'SYS%' AND
      t.TABNAME = ?
SQL

    $tabsth->execute();
    @tables = @{$tabsth->fetchall_arrayref({})};

    foreach my $table_info (@tables) {
        next
            unless (defined($table_info->{TYPE}));

# Why are we not getting system tables, maybe a parameter should decide?

        if ($table_info->{TYPE} eq 'T'&&
            $table_info->{TABSCHEMA} !~ /^SYS/) {
            print Dumper($table_info) if($DEBUG);
            print  $table_info->{TABNAME} if($DEBUG);
            my $table = $schema->add_table(
                                           name => $table_info->{TABNAME},
                                           type => 'TABLE',
                                          ) || die $schema->error;
            $table->options("TABLESPACE", $table_info->{TBSPACE});

            $colsth->execute($table_info->{TABNAME});
            my $cols = $colsth->fetchall_hashref("COLNAME");

            foreach my $c (values %{$cols}) {
                print Dumper($c) if $DEBUG;
                print $c->{COLNAME} if($DEBUG);
                my $f = $table->add_field(
                                        name        => $c->{COLNAME},
                                        default_value => $c->{DEFAULT},
                                        data_type   => $c->{TYPENAME},
                                        order       => $c->{COLNO},
                                        size        => $c->{LENGTH},
                                         ) || die $table->error;


                $f->is_nullable($c->{NULLS} eq 'Y');
            }

            $consth->execute($table_info->{TABNAME});
            my $cons = $consth->fetchall_hashref("COLNAME");
            next if(!%$cons);

            my @fields = map { $_->{COLNAME} } (values %{$cons});
            my $c = $cons->{$fields[0]};

            print  $c->{CONSTNAME} if($DEBUG);
            my $con = $table->add_constraint(
                                           name   => $c->{CONSTNAME},
                                           fields => \@fields,
                                           type   => $c->{TYPE} eq 'P' ?
                                           PRIMARY_KEY : $c->{TYPE} eq 'F' ?
                                           FOREIGN_KEY : UNIQUE
                                         ) || die $table->error;


            $con->deferrable($c->{CHECKEXISTINGDATA} eq 'D');

            $indsth->execute($table_info->{TABNAME});
            my $inds = $indsth->fetchall_hashref("INDNAME");
            print Dumper($inds) if($DEBUG);
            next if(!%$inds);

            foreach my $ind (keys %$inds)
            {
                print $ind if($DEBUG);
                $indsth->execute($table_info->{TABNAME});
                my $indcols = $indsth->fetchall_hashref("COLNAME");
                next if($inds->{$ind}{UNIQUERULE} eq 'P');

                print Dumper($indcols) if($DEBUG);

                my @fields = map { $_->{INDNAME} eq $ind ? $_->{COLNAME} : () }
                   (values %{$indcols});

                my $index = $indcols->{$fields[0]};

                my $inew = $table->add_index(
                                             name   => $index->{INDNAME},
                                             fields => \@fields,
                                             type   => $index->{UNIQUERULE} eq 'U' ?
                                             UNIQUE : NORMAL
                                             ) || die $table->error;


            }

            $trigsth->execute($table_info->{TABNAME});
            my $trigs = $trigsth->fetchall_hashref("TRIGNAME");
            print Dumper($trigs);
            next if(!%$trigs);

            foreach my $t (values %$trigs)
            {
                print  $t->{TRIGNAME} if($DEBUG);
                my $trig = $schema->add_trigger(
                     name                  => $t->{TRIGNAME},
 #                      fields => \@fields,
                     perform_action_when   => $t->{TRIGTIME} eq 'A' ? 'after' :
                                              $t->{TRIGTIME} eq 'B' ? 'before':
                                              'instead',
                     database_event        => $t->{TRIGEVENT} eq 'I' ? 'insert'
                                            : $t->{TRIGEVENT} eq 'D' ? 'delete'
                                            : 'update',
                     action                => $t->{TEXT},
                     on_table              => $t->{TABNAME}
                                              ) || die $schema->error;

#             $trig->extra( reference => $def->{'reference'},
#                           condition => $def->{'condition'},
#                           granularity => $def->{'granularity'} );
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

Jess Robinson <lt>castaway@desert-island.m.isar.de<gt>.

=head1 SEE ALSO

SQL::Translator, DBD::DB2.

=cut
