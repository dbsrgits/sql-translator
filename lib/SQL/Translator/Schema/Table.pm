package SQL::Translator::Schema::Table;

# ----------------------------------------------------------------------
# $Id: Table.pm,v 1.1 2003-05-01 04:25:00 kycl4rk Exp $
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

SQL::Translator::Schema::Table - SQL::Translator table object

=head1 SYNOPSIS

  use SQL::Translator::Schema::Table;
  my $foo_table    = SQL::Translator::Schema::Table->new('foo');

  $foo_table->add_field( 
      name           => 'foo_id', 
      data_type      => 'integer', 
      size           => 11,
      is_primary_key => 1,
  );

  $foo_table->add_field(
      name           => 'foo_name', 
      data_type      => 'char', 
      size           => 10,
  );

  $foo_table->add_index(
      name           => '',
      fields         => [ 'foo_name' ],
  );

=head1 DESCSIPTION

C<SQL::Translator::Schema::Table> is the table object.

=head1 METHODS

=cut

use strict;
use Class::Base;
use SQL::Translator::Schema::Constraint;
use SQL::Translator::Schema::Field;
use SQL::Translator::Schema::Index;

use base 'Class::Base';
use vars qw($VERSION);

$VERSION = 1.00;

# ----------------------------------------------------------------------
sub init {

=pod

=head2 new

Object constructor.

  my $schema = SQL::Translator::Schema::Table->new( name => 'foo' );

=cut

    my ( $self, $config ) = @_;
    $self->params( $config, qw[ name ] ) || return undef;
    return $self;
}

# ----------------------------------------------------------------------
sub name {

=pod

=head2 name

Get or set the table's name.

  my $table_name = $table->name('foo');

=cut

    my $self = shift;
    $self->{'name'} = shift if @_;
    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub add_constraint {

=pod

=head2 add_constraint

Add a constraint to the table.

  $table->add_constraint(
      name   => 'pk',
      fields => [ 'foo_id' ],
      type   => 'primary_key',
  );

=cut

    my $self       = shift;
    my $constraint = SQL::Translator::Schema::Constraint->new( @_ ) or 
        return SQL::Translator::Schema::Constraint->error;
    push @{ $self->{'constraints'} }, $constraint;
    return $constraint;
}

# ----------------------------------------------------------------------
sub add_index {

=pod

=head2 add_index

Add an index to the table.

  $table->add_index(
      name   => 'name',
      fields => [ 'name' ],
      type   => 'normal',
  );

=cut

    my $self  = shift;
    my $index = SQL::Translator::Schema::Index->new( @_ ) or return
                SQL::Translator::Schema::Index->error;
    push @{ $self->{'indices'} }, $index;
    return $index;
}

# ----------------------------------------------------------------------
sub add_field {

=pod

=head2 add_field

Add an field to the table.  Returns the SQL::Translator::Schema::Field 
object.

  my $field          =  $table->add_field(
      name           => 'foo_id',
      data_type      => 'integer',
      size           => 11,
      is_primary_key => 1,
  );

=cut

    my $self  = shift;
    my $field = SQL::Translator::Schema::Field->new( @_ ) or return;
                SQL::Translator::Schema::Field->error;
    $self->{'fields'}{ $field->name } = $field;
    return $field;
}

# ----------------------------------------------------------------------
sub fields {

=pod

=head2 fields

Returns all the fields.

  my @fields = $table->fields;

=cut

    my $self = shift;
    return wantarray ? %{ $self->{'fields'} || {} } : $self->{'fields'};
}

# ----------------------------------------------------------------------
sub is_valid {

=pod

=head2 is_valid

Determine whether the view is valid or not.

  my $ok = $view->is_valid;

=cut

    my $self = shift;
    return ( $self->name && $self->fields ) ? 1 : 0;
}

1;

# ----------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
