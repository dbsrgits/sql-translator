package SQL::Translator::Schema::Constraint;

# ----------------------------------------------------------------------
# $Id: Constraint.pm,v 1.1 2003-05-01 04:24:59 kycl4rk Exp $
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

SQL::Translator::Schema::Constraint - SQL::Translator constraint object

=head1 SYNOPSIS

  use SQL::Translator::Schema::Constraint;
  my $constraint = SQL::Translator::Schema::Constraint->new(
      name   => 'foo',
      fields => [ id ],
      type   => 'primary_key',
  );

=head1 DESCRIPTION

C<SQL::Translator::Schema::Constraint> is the constraint object.

=head1 METHODS

=cut

use strict;
use Class::Base;

use base 'Class::Base';
use vars qw($VERSION $TABLE_COUNT $VIEW_COUNT);

$VERSION = 1.00;

use constant VALID_TYPE => {
    primary_key => 1,
    unique      => 1,
    check       => 1,
    foreign_key => 1,
};

# ----------------------------------------------------------------------
sub init {

=pod

=head2 new

Object constructor.

  my $schema           =  SQL::Translator::Schema::Constraint->new(
      type             => 'foreign_key', # type of table constraint
      name             => 'fk_phone_id', # the name of the constraint
      fields           => 'phone_id',    # the field in the referring table
      reference_fields => 'phone_id',    # the referenced table
      reference_table  => 'phone',       # the referenced fields
      match_type       => 'full',        # how to match
      on_delete_do     => 'cascade',     # what to do on deletes
      on_update_do     => '',            # what to do on updates
  );

=cut

    my ( $self, $config ) = @_;
#        reference_fields reference_table 
#        match_type on_delete_do on_update_do
    my @fields = qw[ name type fields ];

    for my $arg ( @fields ) {
        next unless $config->{ $arg };
        $self->$arg( $config->{ $arg } ) or return;
    }

    return $self;
}

# ----------------------------------------------------------------------
sub fields {

=pod

=head2 fields

Gets and set the fields the constraint is on.  Accepts a list or arrayref, 
return both, too.

  my @fields = $constraint->fields( 'id' );

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

Get or set the constraint's name.

  my $name = $constraint->name('foo');

=cut

    my $self = shift;
    $self->{'name'} = shift if @_;
    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub type {

=pod

=head2 type

Get or set the constraint's type.

  my $type = $constraint->type('primary_key');

=cut

    my $self = shift;

    if ( my $type = shift ) {
        return $self->error("Invalid constraint type: $type") 
            unless VALID_TYPE->{ $type };
        $self->{'type'} = $type;
    }

    return $self->{'type'} || '';
}


# ----------------------------------------------------------------------
sub is_valid {

=pod

=head2 is_valid

Determine whether the constraint is valid or not.

  my $ok = $constraint->is_valid;

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
