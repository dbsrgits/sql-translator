package SQL::Translator::Schema;

# ----------------------------------------------------------------------
# $Id: Schema.pm,v 1.1 2003-05-01 04:24:59 kycl4rk Exp $
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

SQL::Translator::Schema - SQL::Translator schema object

=head1 SYNOPSIS

  use SQL::Translator::Schema;
  my $schema    = SQL::Translator::Schema->new;
  my $foo_table = $schema->add_table( name => 'foo' );

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

  my $view = $schema->add_view(...);

=head1 DESCSIPTION

C<SQL::Translator::Schema> is the object that accepts, validates, and
returns the database structure.

=head1 METHODS

=cut

use strict;
use Class::Base;
use SQL::Translator::Schema::Table;
use SQL::Translator::Schema::View;

use base 'Class::Base';
use vars qw($VERSION $TABLE_COUNT $VIEW_COUNT);

$VERSION = 1.00;

# ----------------------------------------------------------------------
sub init {

=pod

=head2 new

Object constructor.

  my $schema = SQL::Translator->new;

=cut

    my ( $self, $config ) = @_;
    # empty for now
    return $self;
}

# ----------------------------------------------------------------------
sub add_constraint {

=pod

=head2 add_constraint

Add a constraint object.  Returns the new 
SQL::Translator::Schema::Constraint object.

  my $constraint = $table->add_constraint( name => 'foo' );

=cut

    my $self  = shift;
    my $table = SQL::Translator::Schema::Constraint->new( @_ ) or return
                SQL::Translator::Schema::Constraint->error;

    $self->{'tables'}{ $table->name } = $table;
    $self->{'tables'}{ $table->name }{'order'} = ++$TABLE_COUNT;

    return $table;
}

# ----------------------------------------------------------------------
sub add_table {

=pod

=head2 add_table

Add a table object.  Returns the new SQL::Translator::Schema::Table object.

  my $table = $schema->add_table( name => 'foo' );

=cut

    my $self  = shift;
    my $table = SQL::Translator::Schema::Table->new( @_ ) or return
                SQL::Translator::Schema::Table->error;

    $self->{'tables'}{ $table->name } = $table;
    $self->{'tables'}{ $table->name }{'order'} = ++$TABLE_COUNT;

    return $table;
}

# ----------------------------------------------------------------------
sub add_view {

=pod

=head2 add_view

Add a view object.  Returns the new SQL::Translator::Schema::View object.

  my $view = $schema->add_view( name => 'foo' );

=cut

    my $self      = shift;
    my $view      = SQL::Translator::Schema::View->new( @_ ) or return
                    SQL::Translator::Schema::View->error;

    $self->{'views'}{ $view->name } = $view;
    $self->{'views'}{ $view->name }{'order'} = ++$VIEW_COUNT;

    return $view;
}

1;

# ----------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
