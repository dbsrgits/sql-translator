package SQL::Translator::Schema::Constants;

# ----------------------------------------------------------------------
# $Id: Constants.pm,v 1.2 2003-05-05 04:32:39 kycl4rk Exp $
# ----------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>
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

SQL::Translator::CMap::Constants - constants module

=head1 SYNOPSIS

  use SQL::Translator::CMap::Constants;

  $table->add_constraint(
      name => 'foo',
      type => PRIMARY_KEY,
  );

=head1 DESCRIPTION

This module exports a several constants to like "primary key," etc. 

=cut

use strict;
use base qw( Exporter );
use vars qw( @EXPORT $VERSION );
require Exporter;
$VERSION = (qw$Revision: 1.2 $)[-1];

@EXPORT = qw[ 
    CHECK_C
    FOREIGN_KEY
    NOT_NULL
    NULL
    PRIMARY_KEY
    UNIQUE
];

#
# Because "CHECK" is a Perl keyword
#
use constant CHECK_C => 'CHECK';

use constant FOREIGN_KEY => 'FOREIGN_KEY';

use constant NOT_NULL => 'NOT_NULL';

use constant NULL => 'NULL';

use constant PRIMARY_KEY => 'PRIMARY_KEY';

use constant UNIQUE => 'UNIQUE';

1;

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2003

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
