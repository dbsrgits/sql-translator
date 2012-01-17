#!/usr/bin/perl
# vim: set ft=perl:

use strict;
use warnings;
use SQL::Translator;

use File::Spec::Functions qw(catfile updir tmpdir);
use FindBin qw($Bin);
use Test::More;
use Test::Differences;

plan tests => 10;

use_ok('SQL::Translator::Diff') or die "Cannot continue\n";

my $tr            = SQL::Translator->new;

my ( $source_schema, $target_schema ) = map {
    my $t = SQL::Translator->new;
    $t->parser( 'YAML' )
      or die $tr->error;
    my $out = $t->translate( catfile($Bin, qw/data diff /, $_ ) )
      or die $tr->error;

    my $schema = $t->schema;
    unless ( $schema->name ) {
        $schema->name( $_ );
    }
    ($schema);
} (qw/create1.yml create2.yml/);

# Test for differences
my $diff = SQL::Translator::Diff->new({
  source_schema => $source_schema,
  source_db     => 'MySQL',
  target_schema => $target_schema,
  target_db     => 'MySQL',
})->compute_differences;

my $diff_hash = make_diff_hash();

eq_or_diff($diff_hash->{employee},
  {
    constraints_to_create => [ 'FK5302D47D93FE702E_diff' ],
    constraints_to_drop => [ 'FK5302D47D93FE702E' ],
    fields_to_drop => [ 'job_title' ]
  },
  "Correct differences correct on employee table");

eq_or_diff($diff_hash->{person},
  {
    constraints_to_create => [ 'UC_person_id', 'UC_age_name' ],
    constraints_to_drop => [ 'UC_age_name' ],
    fields_to_alter => [
      'person_id person_id',
      'name name',
      'age age',
      'iq iq',
    ],
    fields_to_create => [ 'is_rock_star' ],
    fields_to_rename => [ 'description physical_description' ],
    indexes_to_create => [ 'unique_name' ],
    indexes_to_drop => [ 'u_name' ],
    table_options => [ 'person' ],
  },
  "Correct differences correct on person table");

eq_or_diff(
  [ map { $_->name } @{$diff->tables_to_drop} ],
  [ "deleted" ],
  "tables_to_drop right"
);

eq_or_diff(
  [ map { $_->name } @{$diff->tables_to_create} ],
  [ "added" ],
  "tables_to_create right"
);


$diff = SQL::Translator::Diff->new({
  source_schema => $source_schema,
  source_db     => 'MySQL',
  target_schema => $target_schema,
  target_db     => 'MySQL',
  ignore_index_names      => 1,
  ignore_constraint_names => 1,
})->compute_differences;

$diff_hash = make_diff_hash();

eq_or_diff($diff_hash->{employee},
  {
    fields_to_drop => [ 'job_title' ]
  },
  "Correct differences correct on employee table");

eq_or_diff($diff_hash->{person},
  {
    constraints_to_create => [ 'UC_person_id', 'UC_age_name' ],
    constraints_to_drop => [ 'UC_age_name' ],
    fields_to_alter => [
      'person_id person_id',
      'name name',
      'age age',
      'iq iq',
    ],
    fields_to_create => [ 'is_rock_star' ],
    fields_to_rename => [ 'description physical_description' ],
    table_options => [ 'person' ],
  },
  "Correct differences correct on person table");


# Test for sameness
$diff = SQL::Translator::Diff->new({
  source_schema => $source_schema,
  source_db     => 'MySQL',
  target_schema => $source_schema,
  target_db     => 'MySQL',
})->compute_differences;

$diff_hash = make_diff_hash();

eq_or_diff($diff_hash, {}, "No differences");

is( @{$diff->tables_to_drop}, 0, "tables_to_drop right");
is( @{$diff->tables_to_create}, 0, "tables_to_create right");


# Turn table_diff_hash into something we can eq_or_diff better
sub make_diff_hash {

  return {
    map {
      my $table = $_;
      my $table_diff = $diff->table_diff_hash->{$table};

      my %table_diffs = (
        map {

          my $opt = $table_diff->{$_};
          @$opt ? ( $_ => [ map {
                        (ref $_||'') eq 'ARRAY' ? "@$_" :
                        (ref $_)                ? $_->name
                                                : "$_";
                      } @$opt
                    ] )
                : ()
        } keys %$table_diff
      );

      %table_diffs ? ( $table => \%table_diffs ) : ();
    } keys %{ $diff->table_diff_hash }
  };

}
