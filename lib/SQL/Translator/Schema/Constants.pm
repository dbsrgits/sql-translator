package SQL::Translator::Schema::Constants;

# ----------------------------------------------------------------------
# Copyright (C) 2002-2009 SQLFairy Authors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
# 02111-1307  USA
# -------------------------------------------------------------------

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
use base qw( Exporter );
use vars qw( @EXPORT $VERSION );
require Exporter;
$VERSION = '1.59';

@EXPORT = qw[ 
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

# ----------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut
