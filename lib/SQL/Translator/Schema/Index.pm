package SQL::Translator::Schema::Index;

# ----------------------------------------------------------------------
# $Id: Index.pm,v 1.2 2003-05-05 04:32:39 kycl4rk Exp $
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

use base 'Class::Base';
use vars qw($VERSION $TABLE_COUNT $VIEW_COUNT);

$VERSION = 1.00;

use constant VALID_TYPE => {
    unique      => 1,
    normal      => 1,
    full_text   => 1, # MySQL only (?)
};

# ----------------------------------------------------------------------
sub init {

=pod

=head2 new

Object constructor.

  my $schema = SQL::Translator::Schema::Index->new;

=cut

    my ( $self, $config ) = @_;
    for my $arg ( qw[ name type fields ] ) {
        next unless $config->{ $arg };
        $self->$arg( $config->{ $arg } ) or return;
    }
    return $self;
}

# ----------------------------------------------------------------------
sub fields {

=pod

=head2 fields

Gets and set the fields the index is on.  Accepts a list or arrayref, 
return both, too.

  my @fields = $index->fields( 'id' );

=cut

    my $self   = shift;
    my $fields = ref $_[0] eq 'ARRAY' ? shift : [ @_ ];

    if ( @$fields ) {
        $self->{'fields'} = $fields;
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

    return $self->{'type'} || '';
}


# ----------------------------------------------------------------------
sub is_valid {

=pod

=head2 is_valid

Determine whether the index is valid or not.

  my $ok = $index->is_valid;

=cut

    my $self = shift;
    return ( $self->name && $self->{'type'} && @{ $self->fields } ) ? 1 : 0;
}

1;

# ----------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
