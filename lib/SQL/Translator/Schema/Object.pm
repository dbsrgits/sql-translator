package SQL::Translator::Schema::Object;

# ----------------------------------------------------------------------
# $Id: Object.pm,v 1.1 2004-11-04 16:29:56 grommit Exp $
# ----------------------------------------------------------------------
# Copyright (C) 2002-4 SQLFairy Authors
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

=pod

=head1 NAME

SQL::Translator::Schema::Object - Base class SQL::Translator Schema objects.

=head1 SYNOPSIS

=head1 DESCSIPTION

Doesn't currently provide any functionaliy apart from sub classing
L<Class::Base>. Here to provide a single place to impliment global Schema
object functionality.

=cut

use strict;
use Class::Base;
use base 'Class::Base';

use vars qw[ $VERSION ];

$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;


1;

# ----------------------------------------------------------------------

=pod

=head1 SEE ALSO

=head1 TODO

=head1 BUGS

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>, Mark Addison E<lt>mark.addison@itn.co.ukE<gt> 

=cut
