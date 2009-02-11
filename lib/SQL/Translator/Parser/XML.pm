package SQL::Translator::Parser::XML;

# -------------------------------------------------------------------
# $Id: XML.pm 1440 2009-01-17 16:31:57Z jawnsy $
# -------------------------------------------------------------------
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
use vars qw[ $DEBUG ];
$DEBUG = 1 unless defined $DEBUG;

use SQL::Translator::Parser::XML::SQLFairy;

*parse = \&SQL::Translator::Parser::XML::SQLFairy::parse;

1;
