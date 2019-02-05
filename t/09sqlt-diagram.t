use strict;
use warnings;

use File::Spec::Functions qw(catfile updir tmpdir);
use File::Temp qw(mktemp);
use FindBin qw($Bin);
use Test::More;
use Test::SQL::Translator qw(maybe_plan);
use Text::ParseWords qw(shellwords);

BEGIN {
    maybe_plan(
        3,
        'GD',
        'Graph::Directed',
        'SQL::Translator::Producer::Diagram',
        'SQL::Translator::Parser::MySQL',
    );
}

my @script = qw(script sqlt-diagram);
my @data = qw(data mysql create2.sql);

my $sqlt_diagram = catfile($Bin, updir, @script);
my $test_data = catfile($Bin, @data);

my $tmp = mktemp('sqlXXXXX');

ok(-e $sqlt_diagram);
my @cmd = ($^X, shellwords($ENV{HARNESS_PERL_SWITCHES}||''), $sqlt_diagram, "-d", "MySQL", "-o", $tmp, $test_data);
eval { system(@cmd); };
ok(!$@ && ($? == 0));
ok(-e $tmp);
eval { unlink $tmp; };
