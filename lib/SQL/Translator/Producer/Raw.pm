package SQL::Translator::Producer::Raw;

# -------------------------------------------------------------------
# $Id: Raw.pm,v 1.2 2003-01-29 13:32:44 dlc Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>,
#                    darren chamberlain <darren@cpan.org>,
#                    Chris Mungall <cjm@fruitfly.org>
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

SQL::Translator::Producer::Raw - Raw output (data structure)

=head1 SYNOPSIS

  use SQL::Translator::Producer::Raw;

=head1 DESCRIPTION

Returns a raw data structure from whatever parser was used.

=cut

use strict;
use vars qw[ $VERSION ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;

# -------------------------------------------------------------------
sub produce {
    my ( $translator, $data ) = @_;
    return $data;
}

1;

# -------------------------------------------------------------------
# Something there is that doesn't love a wall.
# Robert Frost
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
