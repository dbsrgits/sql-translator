package SQL::Translator::Filter::DefaultExtra;

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

=head1 NAME

SQL::Translator::Filter::DefaultExtra - Set default extra data values for schema
objects.

=head1 SYNOPSIS

  use SQL::Translator;

  my $sqlt = SQL::Translator->new(
      from => 'MySQL',
      to   => 'MySQL',
      filters => [
        DefaultExtra => {
            # XXX - These should really be ordered
            
            # Default widget for fields to basic text edit.
            'field.widget' => 'text',
            # idea:
            'field(data_type=BIT).widget' => 'yesno',

            # Default label (human formated name) for fields and tables
            'field.label'  => '=ucfirst($name)',
            'table.label'  => '=ucfirst($name)',
        }, 
      ],
  ) || die "SQLFairy error : ".SQL::Translator->error;
  my $sql = $sqlt->translate || die "SQLFairy error : ".$sqlt->error;

=cut

use strict;
use vars qw/$VERSION/;
$VERSION = '1.59';

sub filter {
    my $schema = shift;
    my %args = { +shift };

    # Tables
    foreach ( $schema->get_tables ) {
        my %extra = $_->extra;

        $extra{label} ||= ucfirst($_->name);
        $_->extra( %extra );
    }

    # Fields
    foreach ( map { $_->get_fields } $schema->get_tables ) {
        my %extra = $_->extra;

        $extra{label} ||= ucfirst($_->name);
        $_->extra( %extra );
    }
}

1;

__END__

=head1 DESCRIPTION

Maybe I'm trying to do too much in one go. Args set a match and then an update,
if you want to set lots of things, use lots of filters!

=head1 SEE ALSO

L<perl(1)>, L<SQL::Translator>

=head1 BUGS

=head1 TODO

=head1 AUTHOR

=cut
