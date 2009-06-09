use strict;
use warnings;

use File::Spec::Functions qw(catfile updir tmpdir);
use File::Temp qw(mktemp);
use FindBin qw($Bin);
use Test::More;
use Test::SQL::Translator qw(maybe_plan);

BEGIN {
    maybe_plan(
        3,
        'SQL::Translator::Parser::MySQL',
        'SQL::Translator::Producer::Diagram',
        'Graph::Directed',
    );
}

my @script = qw(script sqlt-diagram);
my @data = qw(data mysql Apache-Session-MySQL.sql);

my $sqlt_diagram = catfile($Bin, updir, @script);
my $test_data = catfile($Bin, @data);

my $tmp = mktemp('sqlXXXXX');

ok(-e $sqlt_diagram); 
my @cmd = ($^X, $sqlt_diagram, "-d", "MySQL", "-o", $tmp, $test_data);
eval { system(@cmd); };
ok(!$@ && ($? == 0));
ok(-e $tmp); 
eval { unlink $tmp; };
