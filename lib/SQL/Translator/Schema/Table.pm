package SQL::Translator::Schema::Table;

# ----------------------------------------------------------------------
# $Id: Table.pm,v 1.2 2003-05-03 04:07:09 kycl4rk Exp $
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
  my $table = SQL::Translator::Schema::Table->new( name => 'foo' );

=head1 DESCSIPTION

C<SQL::Translator::Schema::Table> is the table object.

=head1 METHODS

=cut

use strict;
use Class::Base;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Schema::Constraint;
use SQL::Translator::Schema::Field;
use SQL::Translator::Schema::Index;

use base 'Class::Base';
use vars qw( $VERSION $FIELD_ORDER );

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

Add a constraint to the table.  Returns the newly created 
C<SQL::Translator::Schema::Constraint> object.

  my $constraint = $table->add_constraint(
      name   => 'pk',
      type      => PRIMARY_KEY,
      fields => [ 'foo_id' ],
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

Add an index to the table.  Returns the newly created
C<SQL::Translator::Schema::Index> object.

  my $index  = $table->add_index(
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

Add an field to the table.  Returns the newly created 
C<SQL::Translator::Schema::Field> object.

  my $field     =  $table->add_field(
      name      => 'foo_id',
      data_type => 'integer',
      size      => 11,
  );

=cut

    my $self  = shift;
    my %args  = @_;
    return $self->error('No name') unless $args{'name'};
    my $field = SQL::Translator::Schema::Field->new( \%args ) or return;
                SQL::Translator::Schema::Field->error;
    $self->{'fields'}{ $field->name } = $field;
    $self->{'fields'}{ $field->name }{'order'} = ++$FIELD_ORDER;
    return $field;
}

# ----------------------------------------------------------------------
sub get_constraints {

=pod

=head2 get_constraints

Returns all the constraint objects as an array or array reference.

  my @constraints = $table->get_constraints;

=cut

    my $self = shift;

    if ( ref $self->{'constraints'} ) {
        return wantarray 
            ? @{ $self->{'constraints'} } : $self->{'constraints'};
    }
    else {
        $self->error('No constraints');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub get_indices {

=pod

=head2 get_indices

Returns all the index objects as an array or array reference.

  my @indices = $table->get_indices;

=cut

    my $self = shift;

    if ( ref $self->{'indices'} ) {
        return wantarray 
            ? @{ $self->{'indices'} } 
            : $self->{'indices'};
    }
    else {
        $self->error('No indices');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub get_fields {

=pod

=head2 get_fields

Returns all the field objects as an array or array reference.

  my @fields = $table->get_fields;

=cut

    my $self = shift;
    my @fields = 
        sort { $a->{'order'} <=> $b->{'order'} }
        values %{ $self->{'fields'} || {} };

    if ( @fields ) {
        return wantarray ? @fields : \@fields;
    }
    else {
        $self->error('No fields');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub is_valid {

=pod

=head2 is_valid

Determine whether the view is valid or not.

  my $ok = $view->is_valid;

=cut

    my $self = shift;
    return $self->error('No name') unless $self->name;
    return $self->error('No fields') unless $self->get_fields;

    for my $object ( 
        $self->get_fields, $self->get_indices, $self->get_constraints 
    ) {
        return $object->error unless $object->is_valid;
    }

    return 1;
}

1;

# ----------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
