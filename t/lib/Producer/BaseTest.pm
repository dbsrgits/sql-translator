package Producer::BaseTest;

#
# A trivial little sub-class to test sub-classing the TT::Base producer.
#

use base qw/SQL::Translator::Producer::TT::Base/;

# Make sure we use our new class as the producer
sub produce { return __PACKAGE__->new( translator => shift )->run; };

# Note: we don't need to impliment tt_schema as the default will use the DATA
# section by default.

sub tt_vars { ( foo => "bar" ); }

sub tt_config { ( INTERPOLATE => 1 ); }

1;

__DATA__
Hello World
Tables: [% schema.get_tables.join(', ') %]
[% FOREACH table IN schema.get_tables -%]

$table
------
Fields: $table.field_names.join
[% END %]
