use warnings;
use strict;

use Test::More;
eval "use Test::EOL 1.1";
plan skip_all => 'Test::EOL 1.1 required' if $@;

Test::EOL::all_perl_files_ok({ trailing_whitespace => 1},
  qw|lib t xt script share/DiaUml|,
);

# FIXME - Test::EOL declares 'no_plan' which conflicts with done_testing
# https://github.com/schwern/test-more/issues/14
#done_testing;
