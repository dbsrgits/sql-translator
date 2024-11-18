package SQL::Translator::Parser::DBI::SQLServer;

=head1 NAME

SQL::Translator::Parser::DBI::SQLServer - parser for SQL Server through DBD::ODBC

=head1 SYNOPSIS

See SQL::Translator::Parser::DBI.

=head1 DESCRIPTION

Uses DBI Catalog Methods.

=cut

use strict;
use warnings;
use DBI;
use SQL::Translator::Schema;
use Data::Dumper;

our ($DEBUG, @EXPORT_OK);
our $VERSION = '1.66';
$DEBUG = 0 unless defined $DEBUG;

no strict 'refs';

sub parse {
  my ($tr, $dbh) = @_;

  if ($dbh->{FetchHashKeyName} ne 'NAME_uc') {
    warn "setting dbh attribute {FetchHashKeyName} to NAME_uc";
    $dbh->{FetchHashKeyName} = 'NAME_uc';
  }

  if ($dbh->{ChopBlanks} != 1) {
    warn "setting dbh attribute {ChopBlanks} to 1";
    $dbh->{ChopBlanks} = 1;
  }

  my $schema = $tr->schema;

  my ($sth, @tables, $columns);
  my $stuff;

  ### Columns

  # it is much quicker to slurp back everything all at once rather
  # than make repeated calls

  $sth = $dbh->column_info(undef, undef, undef, undef);

  foreach my $c (@{ $sth->fetchall_arrayref({}) }) {
    $columns->{ $c->{TABLE_CAT} }->{ $c->{TABLE_SCHEM} }
        ->{ $c->{TABLE_NAME} }->{columns}->{ $c->{COLUMN_NAME} } = $c;
  }

  ### Tables and views

  # Get a list of the tables and views.
  $sth    = $dbh->table_info();
  @tables = @{ $sth->fetchall_arrayref({}) };

  my $h = $dbh->selectall_arrayref(
    q{
SELECT o.name, colid,c.text
  FROM syscomments c
  JOIN sysobjects o
    ON c.id = o.id
 WHERE o.type ='V'
ORDER BY o.name,
         c.colid
}
  );

  # View text
  # I had always thought there was something 'hard' about
  # reconstructing text from syscomments ..
  # this seems to work fine and is certainly not complicated!

  foreach (@{$h}) {
    $stuff->{view}->{ $_->[0] }->{text} .= $_->[2];
  }

  #### objects with indexes.
  map { $stuff->{indexes}->{ $_->[0] }++ if defined; } @{
    $dbh->selectall_arrayref(
      "SELECT DISTINCT object_name(id)
                                    FROM sysindexes
                                   WHERE indid > 0 and indid < 255 and
                                         name not like '_WA_Sys%'"
    )
  };

  ## slurp objects
  map { $stuff->{ $_->[1] }->{ $_->[0] } = $_; } @{ $dbh->selectall_arrayref("SELECT name,type, id FROM sysobjects") };

  ### Procedures

# This gets legitimate procedures by used the 'supported' API: sp_stored_procedures
  map {
    my $n = $_->{PROCEDURE_NAME};
    $n =~ s/;\d+$//;    # Ignore versions for now
    $_->{name} = $n;
    $stuff->{procedures}->{$n} = $_;
  } values %{ $dbh->selectall_hashref("sp_stored_procedures", 'PROCEDURE_NAME') };

  # And this blasts in the text of 'legit' stored procedures.  Do
  # this rather than calling sp_helptext in a loop.

  $h = $dbh->selectall_arrayref(
    q{
SELECT o.name, colid,c.text
  FROM syscomments c
  JOIN sysobjects o
    ON c.id = o.id
 WHERE o.type in ('P', 'FN', 'TF', 'IF')
}
  );

  foreach (@{$h}) {
    $stuff->{procedures}->{ $_->[0] }->{text} .= $_->[2]
        if (defined($stuff->{procedures}->{ $_->[0] }));
  }

  ### Defaults
  ### Rules
  ### Bind Defaults
  ### Bind Rules

  ### Triggers
  # Since the 'target' of the trigger is defined in the text, we will
  # just create them independently for now rather than associating them
  # with a table.

  $h = $dbh->selectall_arrayref(
    q{
SELECT o.name, colid,c.text
  FROM syscomments c
  JOIN sysobjects o
    ON c.id = o.id
  JOIN sysobjects o1
    ON (o.id = o1.instrig OR o.id = o1.deltrig or o.id = o1.updtrig)
 WHERE o.type ='TR'
ORDER BY o.name,
         c.colid
}
  );
  foreach (@{$h}) {
    $stuff->{triggers}->{ $_->[0] }->{text} .= $_->[2];
  }

  ### References
  ### Keys

  ### Types
  # Not sure what to do with these?
  $stuff->{type_info_all} = $dbh->type_info_all;

  ### Tables
  # According to the DBI docs, these can be

  # "TABLE"
  # "VIEW"
  # "SYSTEM TABLE"
  # "GLOBAL TEMPORARY",
  # "LOCAL TEMPORARY"
  # "ALIAS"
  # "SYNONYM"

  foreach my $table_info (@tables) {
    next
        unless (defined($table_info->{TABLE_TYPE}));

    if ($table_info->{TABLE_TYPE} eq "TABLE") {
      my $table = $schema->add_table(
        name => $table_info->{TABLE_NAME},
        type => $table_info->{TABLE_TYPE},
      ) || die $schema->error;

      # find the associated columns

      my $cols = $columns->{ $table_info->{TABLE_CAT} }
          ->{ $table_info->{TABLE_SCHEM} }->{ $table_info->{TABLE_NAME} }
          ->{columns};

      foreach my $c (values %{$cols}) {
        my $is_auto_increment = $c->{TYPE_NAME} =~ s#(\(\))? identity##i;
        my $f                 = $table->add_field(
          name      => $c->{COLUMN_NAME},
          data_type => $c->{TYPE_NAME},
          order     => $c->{ORDINAL_POSITION},
          size      => [ $c->{COLUMN_SIZE}, $c->{DECIMAL_DIGITS} ],
        ) || die $table->error;
        $f->is_nullable($c->{NULLABLE} == 1);
        $f->is_auto_increment($is_auto_increment);
        if (defined $c->{COLUMN_DEF}) {
          $c->{COLUMN_DEF} =~ s#\('?(.*?)'?\)#$1#;
          $f->default_value($c->{COLUMN_DEF});
        }
      }

      # add in primary key
      my $h = $dbh->selectall_hashref(
        "sp_pkeys
[$table_info->{TABLE_NAME}]", 'COLUMN_NAME'
      );
      if (scalar keys %{$h} >= 1) {
        my @c = map { $_->{COLUMN_NAME} }
            sort { $a->{KEY_SEQ} <=> $b->{KEY_SEQ} } values %{$h};

        $table->primary_key(@c)
            if (scalar @c);
      }

      # add in foreign keys
      $h = $dbh->selectall_hashref(
        "sp_fkeys NULL,
\@fktable_name = '[$table_info->{TABLE_NAME}]'", 'FK_NAME'
      );
      foreach my $fk (values %{$h}) {
        my $constraint = $table->add_constraint(
          name   => $fk->{FK_NAME},
          fields => [ $fk->{FKCOLUMN_NAME} ],
        );
        $constraint->type("FOREIGN_KEY");
        $constraint->on_delete(
            $fk->{DELETE_RULE} == 0 ? "CASCADE"
          : $fk->{DELETE_RULE} == 1 ? "NO ACTION"
          :                           "SET_NULL"
        );
        $constraint->on_update(
            $fk->{UPDATE_RULE} == 0 ? "CASCADE"
          : $fk->{UPDATE_RULE} == 1 ? "NO ACTION"
          :                           "SET_NULL"
        );
        $constraint->reference_table($fk->{PKTABLE_NAME});
      }

      # add in any indexes ... how do we tell if the index has
      # already been created as part of a primary key or other
      # constraint?

      if (defined($stuff->{indexes}->{ $table_info->{TABLE_NAME} })) {
        my $h = $dbh->selectall_hashref(
          "sp_helpindex
[$table_info->{TABLE_NAME}]", 'INDEX_NAME'
        );
        foreach (values %{$h}) {
          my $fields = $_->{'INDEX_KEYS'};
          $fields =~ s/\s*//g;
          my $i = $table->add_index(
            name   => $_->{INDEX_NAME},
            fields => $fields,
          );
          if ($_->{'INDEX_DESCRIPTION'} =~ /unique/i) {
            $i->type('unique');

            # we could make this a primary key if there
            # isn't already one defined and if there
            # aren't any nullable columns in thisindex.

            if (!defined($table->primary_key())) {
              $table->primary_key($fields)
                  unless grep { $table->get_field($_)->is_nullable() }
                  split(/,\s*/, $fields);
            }
          }
        }
      }
    } elsif ($table_info->{TABLE_TYPE} eq 'VIEW') {
      next
          if $table_info->{TABLE_NAME} eq 'sysconstraints'
          || $table_info->{TABLE_NAME} eq 'syssegments';
      next if !$stuff->{view}->{ $table_info->{TABLE_NAME} }->{text};
      my $view = $schema->add_view(name => $table_info->{TABLE_NAME},);

      my $cols = $columns->{ $table_info->{TABLE_CAT} }
          ->{ $table_info->{TABLE_SCHEM} }->{ $table_info->{TABLE_NAME} }
          ->{columns};

      $view->fields(
        map  { $_->{COLUMN_NAME} }
        sort { $a->{ORDINAL_POSITION} <=> $b->{ORDINAL_POSITION} } values %{$cols}
      );

      $view->sql($stuff->{view}->{ $table_info->{TABLE_NAME} }->{text})
          if (defined($stuff->{view}->{ $table_info->{TABLE_NAME} }->{text}));
    }
  }

  foreach my $p (values %{ $stuff->{procedures} }) {
    next if !$p->{text};
    my $proc = $schema->add_procedure(
      name     => $p->{name},
      owner    => $p->{PROCEDURE_OWNER},
      comments => $p->{REMARKS},
      sql      => $p->{text},
    );

  }

  ### Permissions
  ### Groups
  ### Users
  ### Aliases
  ### Logins
  return 1;
}

1;

=pod

=head1 AUTHOR

Chris Hilton E<lt>chris@dctank.comE<gt> - Bulk of code from
DBI-Sybase parser, I just tweaked it for SQLServer. Thanks.

=head1 SEE ALSO

DBI, DBD::ODBC, SQL::Translator::Schema.

=cut
