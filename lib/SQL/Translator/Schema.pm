package SQL::Translator::Schema;

# ----------------------------------------------------------------------
# $Id: Schema.pm,v 1.2 2003-05-03 04:07:38 kycl4rk Exp $
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
  my $schema = SQL::Translator::Schema->new;
  my $table  = $schema->add_table( name => 'foo' );
  my $view   = $schema->add_view( name => 'bar', sql => '...' );

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
use vars qw[ $VERSION $TABLE_ORDER $VIEW_ORDER ];

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
sub add_table {

=pod

=head2 add_table

Add a table object.  Returns the new SQL::Translator::Schema::Table object.

  my $table = $schema->add_table( name => 'foo' );

=cut

    my $self  = shift;
    my %args  = @_;
    return $self->error('No table name') unless $args{'name'};
    my $table = SQL::Translator::Schema::Table->new( \%args ) or return
                SQL::Translator::Schema::Table->error;

    $self->{'tables'}{ $table->name } = $table;
    $self->{'tables'}{ $table->name }{'order'} = ++$TABLE_ORDER;

    return $table;
}

# ----------------------------------------------------------------------
sub add_view {

=pod

=head2 add_view

Add a view object.  Returns the new SQL::Translator::Schema::View object.

  my $view = $schema->add_view( name => 'foo' );

=cut

    my $self = shift;
    my %args = @_;
    return $self->error('No view name') unless $args{'name'};
    my $view = SQL::Translator::Schema::View->new( @_ ) or return
               SQL::Translator::Schema::View->error;

    $self->{'views'}{ $view->name } = $view;
    $self->{'views'}{ $view->name }{'order'} = ++$VIEW_ORDER;

    return $view;
}

# ----------------------------------------------------------------------
sub is_valid {

=pod

=head2 is_valid

Returns true if all the tables and views are valid.

  my $ok = $schema->is_valid or die $schema->error;

=cut

    my $self = shift;

    return $self->error('No tables') unless $self->get_tables;

    for my $object ( $self->get_tables, $self->get_views ) {
        return $object->error unless $object->is_valid;
    }

    return 1;
}

# ----------------------------------------------------------------------
sub get_table {

=pod

=head2 get_table

Returns a table by the name provided.

  my $table = $schema->get_table('foo');

=cut

    my $self       = shift;
    my $table_name = shift or return $self->error('No table name');
    return $self->error('Table "$table_name" does not exist') unless
        exists $self->{'tables'}{ $table_name };
    return $self->{'tables'}{ $table_name };
}

# ----------------------------------------------------------------------
sub get_tables {

=pod

=head2 get_tables

Returns all the tables as an array or array reference.

  my @tables = $schema->get_tables;

=cut

    my $self   = shift;
    my @tables = 
        sort { $a->{'order'} <=> $b->{'order'} } 
        values %{ $self->{'tables'} };

    if ( @tables ) {
        return wantarray ? @tables : \@tables;
    }
    else {
        $self->error('No tables');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub get_view {

=pod

=head2 get_view

Returns a view by the name provided.

  my $view = $schema->get_view('foo');

=cut

    my $self      = shift;
    my $view_name = shift or return $self->error('No view name');
    return $self->error('View "$view_name" does not exist') unless
        exists $self->{'views'}{ $view_name };
    return $self->{'views'}{ $view_name };
}

# ----------------------------------------------------------------------
sub get_views {

=pod

=head2 get_views

Returns all the views as an array or array reference.

  my @views = $schema->get_views;

=cut

    my $self  = shift;
    my @views = 
        sort { $a->{'order'} <=> $b->{'order'} } values %{ $self->{'views'} };

    if ( @views ) {
        return wantarray ? @views : \@views;
    }
    else {
        $self->error('No views');
        return wantarray ? () : undef;
    }
}

1;

# ----------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
