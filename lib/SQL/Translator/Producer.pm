package SQL::Translator::Producer;

# -------------------------------------------------------------------
# $Id: Producer.pm,v 1.6 2003-08-22 22:51:51 kycl4rk Exp $
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
$VERSION = sprintf "%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/;

sub produce { "" }

1;

# -------------------------------------------------------------------
# A burnt child loves the fire.
# Oscar Wilde
# -------------------------------------------------------------------

=pod

=head1 NAME

SQL::Translator::Producer - describes how to write a producer

=head1 DESCRIPTION

Producer modules designed to be used with SQL::Translator need to
implement a single function, called B<produce>.  B<produce> will be
called with the SQL::Translator object from which it is expected to 
retrieve the SQL::Translator::Schema object which has been populated 
by the parser.  It is expected to return a string.

=head1 AUTHORS

Darren Chamberlain E<lt>darren@cpan.orgE<gt>,
Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

perl(1), SQL::Translator, SQL::Translator::Schema.

=cut
