#!/usr/bin/perl

use warnings;
use strict;
use Test::More qw/no_plan/;
use Test::Exception;
use FindBin qw/$Bin/;

use SQL::Translator;

### Set $ENV{SQLTTEST_RT_DEBUG} = 1 for more output

# What tests to run - parser/producer name, and optional args
my $plan = [
  {
    engine => 'SQLite',
    producer_args => {},
    parser_args => {},
  },
  {
    engine => 'MySQL',
    producer_args => {},
    parser_args => {},
  },
  {
    engine => 'MySQL',
    name => 'MySQL 5.0',
    producer_args => { mysql_version => 5 },
    parser_args => { mysql_parser_version => 5 },
  },
  {
    engine => 'MySQL',
    name => 'MySQL 5.1',
    producer_args => { mysql_version => '5.1' },
    parser_args => { mysql_parser_version => '5.1' },
  },
  {
    engine => 'PostgreSQL',
    producer_args => {},
    parser_args => {},
  },
  {
    engine => 'Oracle',
    producer_args => {},
    parser_args => {},
  },
  {
    engine => 'SQLServer',
    producer_args => {},
    parser_args => {},
  },
  {
    engine => 'Sybase',
    producer_args => {},
    parser_args => {},
  },
  {
    engine => 'DB2',
    producer_args => {},
    parser_args => {},
  },

# There is no Access producer
#  {
#    engine => 'Access',
#    producer_args => {},
#    parser_args => {},
#  },
];


# This data file has the right mix of table/view/procedure/trigger
# definitions, and lists enough quirks to trip up most combos
# I am not sure if augmenting it will break other tests - experiment
my $base_file = "$Bin/data/xml/schema.xml";

my $base_t = SQL::Translator->new;
$base_t->$_ (1) for qw/add_drop_table no_comments/;

my $base_schema = $base_t->translate (
  parser => 'XML',
  file => $base_file,
) or die $base_t->error;


for my $args (@$plan) {

  $args->{name} ||= $args->{engine};

  lives_ok (
    sub { check_roundtrip ($args, $base_schema) },
    "Round trip for $args->{name} did not throw an exception",
  );
}


sub check_roundtrip {
  my ($args, $base_schema) = @_;
  my $base_t = $base_schema->translator;

# create some sql from the submitted schema
  my $base_sql = $base_t->translate (
    data => $base_schema,
    producer => $args->{engine},
    producer_args => $args->{producer_args},
  );

  like (
    $base_sql,
    qr/^\s*CREATE TABLE/m,  #assume there is at least one create table statement
    "Received some meaningful output from the first $args->{name} production",
  ) or do {
    diag ( _gen_diag ($base_t->error) );
    return;
  };

# parse the sql back
  my $parser_t = SQL::Translator->new;
  $parser_t->$_ (1) for qw/add_drop_table no_comments/;
  my $mid_schema = $parser_t->translate (
    data => $base_sql,
    parser => $args->{engine},
    parser_args => $args->{parser_args},
  );

  isa_ok ($mid_schema, 'SQL::Translator::Schema', "First $args->{name} parser pass produced a schema:")
    or do {
      diag (_gen_diag ( $parser_t->error, $base_sql ) );
      return;
    };

# schemas should be comparable at least as far as table/field numbers go
  is_deeply (
    _get_table_info ($mid_schema->get_tables),
    _get_table_info ($base_schema->get_tables),
    "Schema tables generally match afer $args->{name} parser trip",
  ) or return;

# and produce sql once again

# Producing a schema with a Translator different from the one the schema was generated
# from does not work. This is arguably a bug, 61translator_agnostic.t works with that
#  my $producer_t = SQL::Translator->new;
#  $producer_t->$_ (1) for qw/add_drop_table no_comments/;

#  my $rt_sql = $producer_t->translate (
#    data => $mid_schema,
#    producer => $args->{engine},
#    producer_args => $args->{producer_args},
#  );

  my $rt_sql = $parser_t->translate (
    data => $mid_schema,
    producer => $args->{engine},
    producer_args => $args->{producer_args},
  );

  like (
    $rt_sql,
    qr/^\s*CREATE TABLE/m,  #assume there is at least one create table statement
    "Received some meaningful output from the second $args->{name} production",
  ) or do {
    diag ( _gen_diag ( $parser_t->error ) );
    return;
  };

# the two sql strings should be identical
  my $msg = "$args->{name} SQL roundtrip successful - SQL statements match";
  $ENV{SQLTTEST_RT_DEBUG}
    ? is_deeply (
      [ split /\n/, $rt_sql ],
      [ split /\n/, $base_sql ],
      $msg,
    )
    : ok ($rt_sql eq $base_sql, $msg)
  ;
}

sub _get_table_info {
  my @tables = @_;

  my @info;

  for my $t (@tables) {
    push @info, {
      name => $t->name,
      fields => [
        map { $_->name } ($t->get_fields),
      ],
    };
  }

  return \@info;
}

# takes an error string and an optional SQL block
# returns the string conctenated with a line-numbered block for
# easier reading
sub _gen_diag {
  my ($err, $sql) = @_;

  return 'Unknown error' unless $err;


  if ($sql and $ENV{SQLTTEST_RT_DEBUG}) {
    my @sql_lines;
    for (split /\n/, $sql) {
      push @sql_lines, sprintf ('%03d: %s',
        scalar @sql_lines + 1,
        $_,
      );
    }

    return "$err\n\n" . join ("\n", @sql_lines);
  }

  return $err;
}
