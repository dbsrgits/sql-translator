#!/usr/bin/perl

use FindBin qw/$Bin/;
use Test::More;
use Test::SQL::Translator;
use Test::Exception;
use Data::Dumper;
use SQL::Translator;
use SQL::Translator::Diff;

BEGIN {
    maybe_plan(11, 'SQL::Translator::Producer::Oracle');
}

my $schema1 = $Bin.'/data/oracle/schema-1.5.sql';
my $schema2 = $Bin.'/data/oracle/schema-1.6.sql';

open my $io1, '<', $schema1 or die $!;
open my $io2, '<', $schema2 or die $!;

my ($yaml1, $yaml2);
{
    local $/ = undef;
    $sql1 = <$io1>;
    $sql2 = <$io2>;
};

close $io1;
close $io2;

my $s = SQL::Translator->new(from => 'Oracle');
$s->parser->($s,$sql1);

my $t = SQL::Translator->new(from => 'Oracle', debug => 1);
$t->parser->($t,$sql2);

my $d = SQL::Translator::Diff->new
  ({
    output_db => 'Oracle',
    source_schema => $s->schema,
    target_schema => $t->schema,
    sqlt_args => {quote_identifiers => 0}
   });

my $diff = $d->compute_differences->produce_diff_sql || die $d->error;

ok($diff, 'Diff generated.');

like($diff, '/CREATE TABLE t_group/', 'CREATE TABLE t_group generated');

like($diff, '/ALTER TABLE t_category DROP PRIMARY KEY/', 'Drop PRIMARY KEY generated');

like($diff, '/ALTER TABLE t_category DROP CONSTRAINT t_category_display_name/', 'DROP constraint t_category_display_name generated');

like($diff, '/ALTER TABLE t_user_groups DROP CONSTRAINT t_user_groups_group_id_fk/', 'DROP FOREIGN KEY constraint generated');

like($diff, '/DROP INDEX t_alert_roles_idx_alert_id/', 'DROP INDEX generated');

like($diff, '/ALTER TABLE t_message MODIFY \( alert_id number\(11\) \)/', 'MODIFY alert_id generated');

like($diff, '/CREATE INDEX t_user_groups_idx_user_id ON t_user_groups \(user_id\)/', 'CREATE INDEX generated');

like($diff, '/ALTER TABLE t_user_groups ADD CONSTRAINT t_user_groups_group_id_fk FOREIGN KEY \(group_id\) REFERENCES t_group \(group_id\) ON DELETE CASCADE/', 'ADD FOREIGN KEY constraint generated');

like($diff, '/ALTER TABLE t_population_group DROP CONSTRAINT t_population_group_group_role_fk/', 'DROP FOREIGN KEY before drop table generated');

like($diff, '/DROP TABLE t_population_group/', 'DROP TABLE generated');