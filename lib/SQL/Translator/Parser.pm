package SQL::Translator::Parser;

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
# ----------------------------------------------------------------------

use strict;
use vars qw( $VERSION );
$VERSION = '1.60';

sub parse { "" }

1;

# ----------------------------------------------------------------------
# Enough! or Too much.
# William Blake
# ----------------------------------------------------------------------

=pod

=head1 NAME

SQL::Translator::Parser - describes how to write a parser

=head1 DESCRIPTION

Parser modules that get invoked by SQL::Translator need to implement a
single function: B<parse>.  This function will be called by the
SQL::Translator instance as $class::parse($tr, $data_as_string), where
$tr is a SQL::Translator instance.  Other than that, the classes are
free to define any helper functions, or use any design pattern
internally that make the most sense.

When the parser has determined what exists, it will communicate the
structure to the producer through the SQL::Translator::Schema object.
This object can be retrieved from the translator (the first argument
pass to B<parse>) by calling the B<schema> method:

  my $schema = $tr->schema;

The Schema object has methods for adding tables, fields, indices, etc.
For more information, consult the docs for SQL::Translator::Schema and
its related modules.  For examples of how this works, examine the
source code for existing SQL::Translator::Parser::* modules.

=head1 AUTHORS

Ken Youens-Clark, E<lt>kclark@cpan.org<gt>, 
darren chamberlain E<lt>darren@cpan.orgE<gt>.

=head1 SEE ALSO

perl(1), SQL::Translator, SQL::Translator::Schema.

=cut
