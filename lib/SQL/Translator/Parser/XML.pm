package SQL::Translator::Parser::XML;

# -------------------------------------------------------------------
# $Id: XML.pm,v 1.2 2004-02-09 22:23:40 kycl4rk Exp $
# -------------------------------------------------------------------
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

SQL::Translator::Parser::XML - Alias to XML::SQLFairy parser

=head1 DESCRIPTION

This module is an alias to the XML::SQLFairy parser.

=head1 SEE ALSO

SQL::Translator::Parser::XML::SQLFairy.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=cut

# -------------------------------------------------------------------

use strict;
use vars qw[ $VERSION $DEBUG ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;
$DEBUG = 1 unless defined $DEBUG;

use SQL::Translator::Parser::XML::SQLFairy;

*parse = \&SQL::Translator::Parser::XML::SQLFairy::parse;

1;
