package SQL::Translator::Parser;

# ----------------------------------------------------------------------
# $Id: Parser.pm,v 1.1.1.1.2.1 2002-03-15 20:13:46 dlc Exp $
# ----------------------------------------------------------------------
# Copyright (C) 2002 Ken Y. Clark <kycl4rk@users.sourceforge.net>,
#                    darren chamberlain <darren@cpan.org>
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
# ----------------------------------------------------------------------

use strict;
use vars qw( $VERSION );
$VERSION = sprintf "%d.%02d", q$Revision: 1.1.1.1.2.1 $ =~ /(\d+)\.(\d+)/;

sub parse { "" }

1;

#-----------------------------------------------------
# Enough! or Too much.
# William Blake
#-----------------------------------------------------

=head1 NAME

SQL::Translator::Parser - base object for parsers

=head1 DESCRIPTION

Parser modules that get invoked by SQL::Translator need to implement
a single function: B<parse>.  This function will be called by the
SQL::Translator instance as $class::parse($data_as_string).  Other
than that, the classes are free to define any helper functions, or
use any design pattern internally that make the most sense.

=head1 AUTHOR

Ken Y. Clark, kclark@logsoft.com

=head1 SEE ALSO

perl(1).

=cut
