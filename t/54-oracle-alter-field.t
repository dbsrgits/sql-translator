#!/usr/bin/perl

use FindBin qw/$Bin/;
use Test::More;
use Test::SQL::Translator;
use Test::Exception;
use Data::Dumper;
use SQL::Translator;
use SQL::Translator::Diff;

BEGIN {
    maybe_plan(3, 'SQL::Translator::Parser::YAML',
                  'SQL::Translator::Producer::Oracle');
}

my $schema1 = $Bin.'/data/oracle/schema_diff_a.yaml';
my $schema2 = $Bin.'/data/oracle/schema_diff_b.yaml';

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
like($diff, '/ALTER TABLE d_operator MODIFY \( name nvarchar2\(10\) \)/',
     'Alter table generated.');
like($diff, '/ALTER TABLE d_operator MODIFY \( other nvarchar2\(10\) NOT NULL \)/',
     'Alter table generated.');
