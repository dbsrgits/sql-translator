package SQL::Translator::Schema::Index;

# ----------------------------------------------------------------------
# $Id: Index.pm,v 1.3 2003-05-09 17:09:43 kycl4rk Exp $
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

SQL::Translator::Schema::Index - SQL::Translator index object

=head1 SYNOPSIS

  use SQL::Translator::Schema::Index;
  my $index = SQL::Translator::Schema::Index->new(
      name   => 'foo',
      fields => [ id ],
      type   => 'unique',
  );

=head1 DESCRIPTION

C<SQL::Translator::Schema::Index> is the index object.

Primary keys will be considered table constraints, not indices.

=head1 METHODS

=cut

use strict;
use Class::Base;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils 'parse_list_arg';

use base 'Class::Base';
use vars qw($VERSION $TABLE_COUNT $VIEW_COUNT);

$VERSION = 1.00;

use constant VALID_TYPE => {
    UNIQUE,    1,
    NORMAL,    1,
    FULL_TEXT, 1, # MySQL only (?)
};

# ----------------------------------------------------------------------
sub init {

=pod

=head2 new

Object constructor.

  my $schema = SQL::Translator::Schema::Index->new;

=cut

    my ( $self, $config ) = @_;

    for my $arg ( qw[ name type fields table ] ) {
        next unless $config->{ $arg };
        $self->$arg( $config->{ $arg } ) or return;
    }

    return $self;
}

# ----------------------------------------------------------------------
sub fields {

=pod

=head2 fields

Gets and set the fields the constraint is on.  Accepts a string, list or
arrayref; returns an array or array reference.  Will unique the field
names and keep them in order by the first occurrence of a field name.

  $constraint->fields('id');
  $constraint->fields('id', 'name');
  $constraint->fields( 'id, name' );
  $constraint->fields( [ 'id', 'name' ] );
  $constraint->fields( qw[ id name ] );

  my @fields = $constraint->fields;

=cut

    my $self   = shift;
    my $fields = parse_list_arg( @_ );

    if ( @$fields ) {
        my ( %unique, @unique );
        for my $f ( @$fields ) {
            next if $unique{ $f };
            $unique{ $f } = 1;
            push @unique, $f;
        }

        $self->{'fields'} = \@unique;
    }

    return wantarray ? @{ $self->{'fields'} || [] } : $self->{'fields'};
}

# ----------------------------------------------------------------------
sub name {

=pod

=head2 name

Get or set the index's name.

  my $name = $index->name('foo');

=cut

    my $self = shift;
    $self->{'name'} = shift if @_;
    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub options {

=pod

=head2 options

Get or set the index's options (e.g., "using" or "where" for PG).  Returns
an array or array reference.

  my @options = $index->options;

=cut

    my $self    = shift;
    my $options = parse_list_arg( @_ );

    push @{ $self->{'options'} }, @$options;

    if ( ref $self->{'options'} ) {
        return wantarray ? @{ $self->{'options'} || [] } : $self->{'options'};
    }
    else {
        return wantarray ? () : [];
    }
}

# ----------------------------------------------------------------------
sub table {

=pod

=head2 table

Get or set the index's table object.

  my $table = $index->table;

=cut

    my $self = shift;
    if ( my $arg = shift ) {
        return $self->error('Not a table object') unless
            UNIVERSAL::isa( $arg, 'SQL::Translator::Schema::Table' );
        $self->{'table'} = $arg;
    }

    return $self->{'table'};
}

# ----------------------------------------------------------------------
sub type {

=pod

=head2 type

Get or set the index's type.

  my $type = $index->type('unique');

=cut

    my $self = shift;

    if ( my $type = shift ) {
        return $self->error("Invalid index type: $type") 
            unless VALID_TYPE->{ $type };
        $self->{'type'} = $type;
    }

    return $self->{'type'} || NORMAL;
}


# ----------------------------------------------------------------------
sub is_valid {

=pod

=head2 is_valid

Determine whether the index is valid or not.

  my $ok = $index->is_valid;

=cut

    my $self   = shift;
    my $table  = $self->table  or return $self->error('No table');
    my @fields = $self->fields or return $self->error('No fields');

    for my $field ( @fields ) {
        return $self->error(
            "Field '$field' does not exist in table '", $table->name, "'"
        ) unless $table->get_field( $field );
    }

    return 1;
}

# ----------------------------------------------------------------------
sub DESTROY {
    my $self = shift;
    undef $self->{'table'}; # destroy cyclical reference
}

1;

# ----------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
