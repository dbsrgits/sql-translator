package SQL::Translator::Producer;

# -------------------------------------------------------------------
# $Id: Producer.pm,v 1.5 2003-01-27 17:04:45 dlc Exp $
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

use strict;
use vars qw($VERSION);
$VERSION = sprintf "%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/;

sub produce { "" }

1;

# -------------------------------------------------------------------
# A burnt child loves the fire.
# Oscar Wilde
# -------------------------------------------------------------------

=pod

=head1 NAME

SQL::Translator::Producer - base object for Producers

=head1 SYNOPSIS

=head1 DESCRIPTION

Producer modules designed to be used with SQL::Translator need to
implement a single function, called B<produce>.  B<produce> will be
called with a data structure created by a SQL::Translator::Parser
subclass.  It is expected to return a string containing a valid SQL
create statement.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=head1 SEE ALSO

perl(1).

=cut
