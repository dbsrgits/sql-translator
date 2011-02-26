package SQL::Translator::Schema::Constants;

=head1 NAME

SQL::Translator::Schema::Constants - constants module

=head1 SYNOPSIS

  use SQL::Translator::Schema::Constants;

  $table->add_constraint(
      name => 'foo',
      type => PRIMARY_KEY,
  );

=head1 DESCRIPTION

This module exports the following constants for Schema features;

=over 4

=item CHECK_C

=item FOREIGN_KEY

=item FULL_TEXT

=item NOT_NULL

=item NORMAL

=item NULL

=item PRIMARY_KEY

=item UNIQUE

=back

=cut

use strict;
use warnings;
use base qw( Exporter );
require Exporter;
our $VERSION = '1.59';

our @EXPORT = qw[
    CHECK_C
    FOREIGN_KEY
    FULL_TEXT
    SPATIAL
    NOT_NULL
    NORMAL
    NULL
    PRIMARY_KEY
    UNIQUE
];

#
# Because "CHECK" is a Perl keyword
#
use constant CHECK_C => 'CHECK';

use constant FOREIGN_KEY => 'FOREIGN KEY';

use constant FULL_TEXT => 'FULLTEXT';

use constant SPATIAL => 'SPATIAL';

use constant NOT_NULL => 'NOT NULL';

use constant NORMAL => 'NORMAL';

use constant NULL => 'NULL';

use constant PRIMARY_KEY => 'PRIMARY KEY';

use constant UNIQUE => 'UNIQUE';

1;

=pod

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut
