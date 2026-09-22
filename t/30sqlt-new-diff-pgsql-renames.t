#!/usr/bin/perl
# vim: set ft=perl:

use strict;
use warnings;
use SQL::Translator;

use File::Spec::Functions qw(catfile updir tmpdir);
use FindBin               qw($Bin);
use Test::More;
use Test::Differences;
use Test::SQL::Translator qw(maybe_plan);
use SQL::Translator::Schema::Constants;
use Storable 'dclone';

plan tests => 5;

use_ok('SQL::Translator::Diff') or die "Cannot continue\n";

my @warns;
local $SIG{__WARN__} = sub {
  push @warns, $_[0] =~ s/\s+$//r;
};


sub load {
  return map {
    my $t = SQL::Translator->new;
    $t->parser('YAML')
        or die $t->error;
    my $out = $t->translate(catfile($Bin, qw/data diff pgsql/, $_))
        or die $t->error;

    my $schema = $t->schema;
    unless ($schema->name) {
      $schema->name($_);
    }
    ($schema);
  } @_;
}


sub diff_it {
  my( $src, $dst ) =  @_;

  my $out =  SQL::Translator::Diff::schema_diff(
    $src,
    'PostgreSQL',
    $dst,
    'PostgreSQL', {
      ignore_index_names      => 1,
      ignore_constraint_names => 1,
      sqlt_args               => {
        quote_identifiers => 0,
      }
    }
  );

  return $out =~ s/^.*?BEGIN;\n+(.*)COMMIT.*?$/$1/sr  =~ s/\n+$//gmr ."\n";
}

<<INFO;
v1 | v2   | v3   | v4      | v5   |
x  | y:rx | x:ry | x, y:rx | y:rx |
INFO

my $out;

# v1 -> v2
$out =  diff_it load qw/ rename1.yml rename2.yml /;

eq_or_diff $out, <<DDL, "Column x renamed to y";
ALTER TABLE testr RENAME COLUMN x TO y;
DDL


# v2 -> v3
$out =  diff_it load qw/ rename2.yml rename3.yml /;

eq_or_diff $out, <<DDL, "Column y renamed back to x";
ALTER TABLE testr RENAME COLUMN y TO x;
DDL


# v3 -> v4
$out =  diff_it load qw/ rename3.yml rename4.yml /;

eq_or_diff $out, <<DDL, "Column x renamed to y and new column x created";
ALTER TABLE testr RENAME COLUMN x TO y;
ALTER TABLE testr ADD COLUMN x integer;
DDL


# v4 -> v5
$out =  diff_it load qw/ rename4.yml rename5.yml /;

eq_or_diff $out, <<DDL, "Column y dropped and column x renamed to y";
ALTER TABLE testr DROP COLUMN y;
ALTER TABLE testr RENAME COLUMN x TO y;
DDL
