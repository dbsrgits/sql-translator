use warnings;
use strict;

use Test::More;

eval "use Test::NoTabs 1.1";
plan skip_all => 'Test::NoTabs 1.1 required' if $@;

Test::NoTabs::all_perl_files_ok(
  qw|lib t xt script share/DiaUml|,
);

# FIXME - Test::NoTabs declares 'no_plan' which conflicts with done_testing
# https://github.com/schwern/test-more/issues/14
#done_testing;
