package SQL::Translator::Parser;

# ----------------------------------------------------------------------
# $Id: Parser.pm,v 1.3 2002-03-25 14:25:58 dlc Exp $
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
$VERSION = sprintf "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/;

sub parse { "" }

1;

#-----------------------------------------------------
# Enough! or Too much.
# William Blake
#-----------------------------------------------------
__END__

=head1 NAME

SQL::Translator::Parser - base object for parsers

=head1 DESCRIPTION

Parser modules that get invoked by SQL::Translator need to implement a
single function: B<parse>.  This function will be called by the
SQL::Translator instance as $class::parse($tr, $data_as_string), where
$tr is a SQL::Translator instance.  Other than that, the classes are
free to define any helper functions, or use any design pattern
internally that make the most sense.

=head1 FORMAT OF THE DATA STRUCTURE

The data structure returned from the B<parse> function has a very
particular format.

=over 4

=item o

The data structure should be a reference to a hash, the keys of which
are table names.

=item o

The values associated with each table should also be a reference to a
hash.  This hash should have several keys, enumerated below.

=back

=over 15

=item B<type>

This is the type of the table, if applicable, as a string, or undef if not (for
example, if the database does not have multiple options).  For MySQL,
this value might include MyISAM, HEAP, or similar.

=item B<indeces>

The indeces keys is a reference to an array of hashrefs.  Each hashref
defines one index, and has the keys 'name' (if defined, it will be a
string), 'type' (a string), and 'fields' (a reference to another
array).  For example, a table in a MySQL database with two indexes,
created as:

  PRIMARY KEY (id),
  KEY foo_idx (foo),
  KEY foo_bar_idx (foo, bar),

would be described in the indeces element as:

  [
    {
      'type' => 'primary_key',
      'fields' => [
                    'id'
                  ],
      'name' => undef,
    },
    {
      'type' => 'normal',
      'fields' => [
                    'foo'
                  ],
      'name' => 'foo_idx',
    },
    {
      'type' => 'normal',
      'fields' => [
                    'foo',
                    'bar',
                  ],
      'name' => 'foo_bar_idx',
    },
  ]

=item B<fields>

The fields element is a refernce to a hash; the keys of this hash are
the row names from the table, and each value fills in this template:

  { 
    type           => 'field',
    order          => 1,      # the order in the original table
    name           => '',     # same as the key
    data_type      => '',     # in the db's jargon,
                              # i.e., MySQL => int, Oracale => INTEGER
    size           => '',     # int
    null           => 1 | 0,  # boolean
    default        => '',
    is_auto_inc    => 1 1 0,  # boolean
    is_primary_key => 1 | 0,  # boolean
  } 

So a row defined as:

  username CHAR(8) NOT NULL DEFAULT 'nobody',
  KEY username_idx (username)

would be represented as:

  'fields => {
    'username' => { 
      type           => 'field',
      order          => 1,
      name           => 'username',
      data_type      => 'char',
      size           => '8',
      null           => undef,
      default        => 'nobody',
      is_auto_inc    => undef,
      is_primary_key => undef,
    },
  },
  'indeces' => [
    {
      'name' => 'username_idx',
      'fields' => [
                    'username'
                  ],
      'type' => 'normal',
    },
  ],

=back


=head1 AUTHORS

Ken Y. Clark, E<lt>kclark@logsoft.comE<gt>, darren chamberlain E<lt>darren@cpan.orgE<gt>

=head1 SEE ALSO

perl(1).

=cut
