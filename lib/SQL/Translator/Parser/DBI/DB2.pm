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
use DBI;
use Data::Dumper;
use SQL::Translator::Schema::Constants;

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

# -------------------------------------------------------------------
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

    $sth = $dbh->table_info();

    @tables   = @{$sth->fetchall_arrayref({})};

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

    foreach my $table_info (@tables) {
        next
            unless (defined($table_info->{TABLE_TYPE}));

# Why are we not getting system tables, maybe a parameter should decide?

        if ($table_info->{TABLE_TYPE} eq 'TABLE'&&
            $table_info->{TABLE_SCHEM} !~ /^SYS/) {
            print Dumper($table_info) if($DEBUG);
            print  $table_info->{TABLE_NAME} if($DEBUG);
            my $table = $schema->add_table(
                                           name => $table_info->{TABLE_NAME},
                                           type => $table_info->{TABLE_TYPE},
                                          ) || die $schema->error;

            $colsth->execute($table_info->{TABLE_NAME});
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

            $consth->execute($table_info->{TABLE_NAME});
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
            
            $indsth->execute($table_info->{TABLE_NAME});
            my $inds = $indsth->fetchall_hashref("INDNAME");
            print Dumper($inds) if($DEBUG);
            next if(!%$inds);

            foreach my $ind (keys %$inds)
            {
                print $ind if($DEBUG);
                $indsth->execute($table_info->{TABLE_NAME});
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
