package SQL::Translator::Parser::DBI;

=head1 NAME

SQL::Translator::Parser::DBI - "parser" for DBI handles

=head1 SYNOPSIS

  use DBI;
  use SQL::Translator;

  my $dbh = DBI->connect('dsn', 'user', 'pass',
      {
          RaiseError       => 1,
          FetchHashKeyName => 'NAME_lc',
      }
  );

  my $translator  =  SQL::Translator->new(
      parser      => 'DBI',
      parser_args => {
          dbh => $dbh,
      },
  );

Or:

  use SQL::Translator;

  my $translator      =  SQL::Translator->new(
      parser          => 'DBI',
      parser_args     => {
          dsn         => 'dbi:mysql:FOO',
          db_user     => 'guest',
          db_password => 'password',
    }
  );

=head1 DESCRIPTION

This parser accepts an open database handle (or the arguments to create
one) and queries the database directly for the information.

The following are acceptable arguments:

=over 4

=item * dbh

An open DBI database handle.  NB:  Be sure to create the database with the
"FetchHashKeyName => 'NAME_lc'" option as all the DBI parsers expect
lowercased column names.

=item * dsn

The DSN to use for connecting to a database.

=item * db_user

The user name to use for connecting to a database.

=item * db_password

The password to use for connecting to a database.

=back

There is no need to specify which type of database you are querying as
this is determined automatically by inspecting $dbh->{'Driver'}{'Name'}.
If a parser exists for your database, it will be used automatically;
if not, the code will fail automatically (and you can write the parser
and contribute it to the project!).

Currently parsers exist for the following databases:

=over 4

=item * MySQL

=item * SQLite

=item * Sybase

=item * PostgreSQL (still experimental)

=back

Most of these parsers are able to query the database directly for the
structure rather than parsing a text file.  For large schemas, this is
probably orders of magnitude faster than traditional parsing (which
uses Parse::RecDescent, an amazing module but really quite slow).

Though no Oracle parser currently exists, it would be fairly easy to
query an Oracle database directly by using DDL::Oracle to generate a
DDL for the schema and then using the normal Oracle parser on this.
Perhaps future versions of SQL::Translator will include the ability to
query Oracle directly and skip the parsing of a text file, too.

=cut

use strict;
use warnings;
use DBI;
our @EXPORT;
our $VERSION = '1.66';

use constant DRIVERS => {
  mysql  => 'MySQL',
  odbc   => 'SQLServer',
  oracle => 'Oracle',
  pg     => 'PostgreSQL',
  sqlite => 'SQLite',
  sybase => 'Sybase',
  db2    => 'DB2',
};

use Exporter;

use SQL::Translator::Utils qw(debug);

use base qw(Exporter);
@EXPORT = qw(parse);

#
# Passed a SQL::Translator instance and a string containing the data
#
sub parse {
  my ($tr, $data) = @_;

  my $args        = $tr->parser_args;
  my $dbh         = $args->{'dbh'};
  my $dsn         = $args->{'dsn'};
  my $db_user     = $args->{'db_user'};
  my $db_password = $args->{'db_password'};

  my $dbh_is_local;
  unless ($dbh) {
    die 'No DSN' unless $dsn;
    $dbh = DBI->connect(
      $dsn, $db_user,
      $db_password,
      {
        FetchHashKeyName => 'NAME_lc',
        LongReadLen      => 3000,
        LongTruncOk      => 1,
        RaiseError       => 1,
      }
    );
    $dbh_is_local = 1;
  }

  die 'No database handle' unless defined $dbh;

  my $db_type = $dbh->{'Driver'}{'Name'} or die 'Cannot determine DBI type';
  my $driver  = DRIVERS->{ lc $db_type } or die "$db_type not supported";
  my $pkg     = "SQL::Translator::Parser::DBI::$driver";
  my $sub     = $pkg . '::parse';

  SQL::Translator::load($pkg);

  my $s = eval {
    no strict 'refs';
    &{$sub}($tr, $dbh) or die "No result from $pkg";
  };
  my $err = $@;

  eval { $dbh->disconnect } if (defined $dbh and $dbh_is_local);

  die $err if $err;

  return $s;
}

1;

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

DBI, SQL::Translator.

=cut
