package SQL::Translator::Schema::View;

# ----------------------------------------------------------------------
# $Id: View.pm,v 1.1 2003-05-01 04:25:00 kycl4rk Exp $
# ----------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>
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

SQL::Translator::Schema::View - SQL::Translator view object

=head1 SYNOPSIS

  use SQL::Translator::Schema::View;
  my $view = SQL::Translator::Schema::View->new(
      name => 'foo',
      sql  => 'select * from foo',
  );

=head1 DESCRIPTION

C<SQL::Translator::Schema::View> is the view object.

=head1 METHODS

=cut

use strict;
use Class::Base;

use base 'Class::Base';
use vars qw($VERSION $TABLE_COUNT $VIEW_COUNT);

$VERSION = 1.00;

# ----------------------------------------------------------------------
sub init {

=pod

=head2 new

Object constructor.

  my $schema = SQL::Translator::Schema::View->new;

=cut

    my ( $self, $config ) = @_;
    $self->params( $config, qw[ name sql ] );
    return $self;
}

# ----------------------------------------------------------------------
sub name {

=pod

=head2 name

Get or set the view's name.

  my $name = $view->name('foo');

=cut

    my $self        = shift;
    $self->{'name'} = shift if @_;
    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub sql {

=pod

=head2 sql

Get or set the view's SQL.

  my $sql = $view->sql('select * from foo');

=cut

    my $self       = shift;
    $self->{'sql'} = shift if @_;
    return $self->{'sql'} || '';
}

# ----------------------------------------------------------------------
sub is_valid {

=pod

=head2 is_valid

Determine whether the view is valid or not.

  my $ok = $view->is_valid;

=cut

    my $self = shift;
    return 1 if $self->name && $self->sql;
}

1;

# ----------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
