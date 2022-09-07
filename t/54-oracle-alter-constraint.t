#!/usr/bin/perl

use FindBin qw/$Bin/;
use Test::More;
use Test::SQL::Translator;
use Test::Exception;
use Data::Dumper;
use SQL::Translator;
use SQL::Translator::Diff;

BEGIN {
    maybe_plan(6, 'SQL::Translator::Parser::YAML',
                  'SQL::Translator::Producer::Oracle');
}

my $schema1 = $Bin.'/data/oracle/schema_diff_d.yaml';
my $schema2 = $Bin.'/data/oracle/schema_diff_e.yaml';

open my $io1, '<', $schema1 or die $!;
open my $io2, '<', $schema2 or die $!;

my ($yaml1, $yaml2);
{
    local $/ = undef;
    $yaml1 = <$io1>;
    $yaml2 = <$io2>;
};

close $io1;
close $io2;

my $s = SQL::Translator->new(from => 'YAML');
$s->parser->($s,$yaml1);

my $t = SQL::Translator->new(from => 'YAML');
$t->parser->($t,$yaml2);

my $d = SQL::Translator::Diff->new
  ({
    output_db => 'Oracle',
    target_db => 'Oracle',
    source_schema => $s->schema,
    target_schema => $t->schema,
   });


my $diff = $d->compute_differences->produce_diff_sql || die $d->error;

ok($diff, 'Diff generated.');

like($diff, '/ALTER TABLE d_operator DROP CONSTRAINT foo_unique/', 'DROP constraint foo_unique generated');

like($diff, '/DROP CONSTRAINT other_check/', 'DROP constraint other_check generated');

like($diff, '/ADD CONSTRAINT other_check CHECK \(other BETWEEN 100 and 99999\)/', 'ADD check constraint generated');

like($diff, '/ALTER TABLE supplier CONSTRAINT fk_customer/', 'DROP Foreign key constraint generated');

like($diff, '/DROP TABLE customer/', 'DROP TABLE customer generated');
