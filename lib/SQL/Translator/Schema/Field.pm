package SQL::Translator::Schema::Field;

# ----------------------------------------------------------------------
# $Id: Field.pm,v 1.1 2003-05-01 04:25:00 kycl4rk Exp $
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

SQL::Translator::Schema::Field - SQL::Translator field object

=head1 SYNOPSIS

  use SQL::Translator::Schema::Field;
  my $field = SQL::Translator::Schema::Field->new(
      name => 'foo',
      sql  => 'select * from foo',
  );

=head1 DESCRIPTION

C<SQL::Translator::Schema::Field> is the field object.

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

  my $schema = SQL::Translator::Schema::Field->new;

=cut

    my ( $self, $config ) = @_;
    $self->params( $config, qw[ name data_type size is_primary_key ] );
    return $self;
}

# ----------------------------------------------------------------------
sub data_type {

=pod

=head2 data_type

Get or set the field's data_type.

  my $data_type = $field->data_type('integer');

=cut

    my $self = shift;
    $self->{'data_type'} = shift if @_;
    return $self->{'data_type'} || '';
}

# ----------------------------------------------------------------------
sub is_primary_key {

=pod

=head2 is_primary_key

Get or set the field's is_primary_key attribute.

  my $is_pk = $field->is_primary_key(1);

=cut

    my ( $self, $arg ) = @_;

    if ( defined $arg ) {
        $self->{'is_primary_key'} = $arg ? 1 : 0;
    }

    return $self->{'is_primary_key'} || 0;
}

# ----------------------------------------------------------------------
sub name {

=pod

=head2 name

Get or set the field's name.

  my $name = $field->name('foo');

=cut

    my $self = shift;
    $self->{'name'} = shift if @_;
    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub size {

=pod

=head2 size

Get or set the field's size.

  my $size = $field->size('25');

=cut

    my ( $self, $arg ) = @_;

    if ( $arg =~ m/^\d+(?:\.\d+)?$/ ) {
        $self->{'size'} = $arg;
    }

    return $self->{'size'} || 0;
}

# ----------------------------------------------------------------------
sub is_valid {

=pod

=head2 is_valid

Determine whether the field is valid or not.

  my $ok = $field->is_valid;

=cut

    my $self = shift;
    return 1 if $self->name && $self->data_type;
}

1;

# ----------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
