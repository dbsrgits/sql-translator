package Producer::BaseTest;

use base qw/SQL::Translator::Producer::TT::Base/;

# Make sure we use our new class as the producer
sub produce { return __PACKAGE__->new( translator => shift )->run; };

sub tt_schema { local $/ = undef; return \<DATA>; }

sub tt_vars { ( foo => "bar" ); }

1;

__DATA__
Hello World
[% schema.get_tables %]
foo:bar
