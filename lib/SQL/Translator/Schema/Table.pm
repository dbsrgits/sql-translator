package SQL::Translator::Schema::Table;

# ----------------------------------------------------------------------
# $Id: Table.pm,v 1.13 2003-08-21 18:10:47 kycl4rk Exp $
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
use SQL::Translator::Utils 'parse_list_arg';
use SQL::Translator::Schema::Constants;
use SQL::Translator::Schema::Constraint;
use SQL::Translator::Schema::Field;
use SQL::Translator::Schema::Index;

use base 'Class::Base';
use vars qw( $VERSION $FIELD_ORDER );

$VERSION = sprintf "%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/;

# ----------------------------------------------------------------------
sub init {

=pod

=head2 new

Object constructor.

  my $table  =  SQL::Translator::Schema::Table->new( 
      schema => $schema,
      name   => 'foo',
  );

=cut

    my ( $self, $config ) = @_;
    
    for my $arg ( qw[ schema name comments ] ) {
        next unless defined $config->{ $arg };
        defined $self->$arg( $config->{ $arg } ) or return;
    }

    return $self;
}

# ----------------------------------------------------------------------
sub add_constraint {

=pod

=head2 add_constraint

Add a constraint to the table.  Returns the newly created 
C<SQL::Translator::Schema::Constraint> object.

  my $c1 = $table->add_constraint(
      name        => 'pk',
      type        => PRIMARY_KEY,
      fields      => [ 'foo_id' ],
  );

  my $c2 = SQL::Translator::Schema::Constraint->new( name => 'uniq' );
  $c2    = $table->add_constraint( $constraint );

=cut

    my $self             = shift;
    my $constraint_class = 'SQL::Translator::Schema::Constraint';
    my $constraint;

    if ( UNIVERSAL::isa( $_[0], $constraint_class ) ) {
        $constraint = shift;
        $constraint->table( $self );
    }
    else {
        my %args = @_;
        $args{'table'} = $self;
        $constraint = $constraint_class->new( \%args ) or 
            return $self->error( $constraint_class->error );
    }

    #
    # If we're trying to add a PK when one is already defined,
    # then just add the fields to the existing definition.
    #
    my $ok = 1;
    my $pk = $self->primary_key;
    if ( $pk && $constraint->type eq PRIMARY_KEY ) {
        $self->primary_key( $constraint->fields );
        $constraint = $pk;
        $ok         = 0;
    }
    #
    # See if another constraint of the same type 
    # covers the same fields.
    #
    elsif ( $constraint->type ne CHECK_C ) {
        my @field_names = $constraint->fields;
        for my $c ( 
            grep { $_->type eq $constraint->type } 
            $self->get_constraints 
        ) {
            my %fields = map { $_, 1 } $c->fields;
            for my $field_name ( @field_names ) {
                if ( $fields{ $field_name } ) {
                    $constraint = $c;
                    $ok = 0; 
                    last;
                }
            }
            last unless $ok;
        }
    }

    if ( $ok ) {
        push @{ $self->{'constraints'} }, $constraint;
    }

    return $constraint;
}

# ----------------------------------------------------------------------
sub add_index {

=pod

=head2 add_index

Add an index to the table.  Returns the newly created
C<SQL::Translator::Schema::Index> object.

  my $i1 = $table->add_index(
      name   => 'name',
      fields => [ 'name' ],
      type   => 'normal',
  );

  my $i2 = SQL::Translator::Schema::Index->new( name => 'id' );
  $i2    = $table->add_index( $index );

=cut

    my $self        = shift;
    my $index_class = 'SQL::Translator::Schema::Index';
    my $index;

    if ( UNIVERSAL::isa( $_[0], $index_class ) ) {
        $index = shift;
        $index->table( $self );
    }
    else {
        my %args = @_;
        $args{'table'} = $self;
        $index = $index_class->new( \%args ) or return 
            $self->error( $index_class->error );
    }

    push @{ $self->{'indices'} }, $index;
    return $index;
}

# ----------------------------------------------------------------------
sub add_field {

=pod

=head2 add_field

Add an field to the table.  Returns the newly created
C<SQL::Translator::Schema::Field> object.  The "name" parameter is 
required.  If you try to create a field with the same name as an 
existing field, you will get an error and the field will not be created.

  my $f1    =  $table->add_field(
      name      => 'foo_id',
      data_type => 'integer',
      size      => 11,
  );

  my $f2 =  SQL::Translator::Schema::Field->new( 
      name   => 'name', 
      table  => $table,
  );
  $f2    = $table->add_field( $field2 ) or die $table->error;

=cut

    my $self        = shift;
    my $field_class = 'SQL::Translator::Schema::Field';
    my $field;

    if ( UNIVERSAL::isa( $_[0], $field_class ) ) {
        $field = shift;
        $field->table( $self );
    }
    else {
        my %args = @_;
        $args{'table'} = $self;
        $field = $field_class->new( \%args ) or return 
            $self->error( $field_class->error );
    }

    $field->order( ++$FIELD_ORDER );
    my $field_name = $field->name or return $self->error('No name');

    if ( exists $self->{'fields'}{ $field_name } ) { 
        return $self->error(qq[Can't create field: "$field_name" exists]);
    }
    else {
        $self->{'fields'}{ $field_name } = $field;
    }

    return $field;
}

# ----------------------------------------------------------------------
sub comments {

=pod

=head2 comments

Get or set the comments on a table.  May be called several times to 
set and it will accumulate the comments.  Called in an array context,
returns each comment individually; called in a scalar context, returns
all the comments joined on newlines.

  $table->comments('foo');
  $table->comments('bar');
  print join( ', ', $table->comments ); # prints "foo, bar"

=cut

    my $self     = shift;
    my @comments = ref $_[0] ? @{ $_[0] } : @_;

    for my $arg ( @comments ) {
        $arg = $arg->[0] if ref $arg;
        push @{ $self->{'comments'} }, $arg if defined $arg && $arg;
    }

    if ( @{ $self->{'comments'} || [] } ) {
        return wantarray 
            ? @{ $self->{'comments'} }
            : join( "\n", @{ $self->{'comments'} } )
        ;
    } 
    else {
        return wantarray ? () : undef;
    }
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
sub get_field {

=pod

=head2 get_field

Returns a field by the name provided.

  my $field = $table->get_field('foo');

=cut

    my $self       = shift;
    my $field_name = shift or return $self->error('No field name');
    return $self->error( qq[Field "$field_name" does not exist] ) unless
        exists $self->{'fields'}{ $field_name };
    return $self->{'fields'}{ $field_name };
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
        map  { $_->[1] }
        sort { $a->[0] <=> $b->[0] }
        map  { [ $_->order, $_ ] }
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
    return $self->error('No name')   unless $self->name;
    return $self->error('No fields') unless $self->get_fields;

    for my $object ( 
        $self->get_fields, $self->get_indices, $self->get_constraints 
    ) {
        return $object->error unless $object->is_valid;
    }

    return 1;
}

# ----------------------------------------------------------------------
sub name {

=pod

=head2 name

Get or set the table's name.

If provided an argument, checks the schema object for a table of 
that name and disallows the change if one exists.

  my $table_name = $table->name('foo');

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        if ( my $schema = $self->schema ) {
            return $self->error( qq[Can't use table name "$arg": table exists] )
                if $schema->get_table( $arg );
        }
        $self->{'name'} = $arg;
    }

    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub schema {

=pod

=head2 schema

Get or set the table's schema object.

  my $schema = $table->schema;

=cut

    my $self = shift;
    if ( my $arg = shift ) {
        return $self->error('Not a schema object') unless
            UNIVERSAL::isa( $arg, 'SQL::Translator::Schema' );
        $self->{'schema'} = $arg;
    }

    return $self->{'schema'};
}

# ----------------------------------------------------------------------
sub primary_key {

=pod

=head2 options

Gets or sets the table's primary key(s).  Takes one or more field
names (as a string, list or array[ref]) as an argument.  If the field
names are present, it will create a new PK if none exists, or it will
add to the fields of an existing PK (and will unique the field names).
Returns the C<SQL::Translator::Schema::Constraint> object representing
the primary key.

These are eqivalent:

  $table->primary_key('id');
  $table->primary_key(['name']);
  $table->primary_key('id','name']);
  $table->primary_key(['id','name']);
  $table->primary_key('id,name');
  $table->primary_key(qw[ id name ]);

  my $pk = $table->primary_key;

=cut

    my $self   = shift;
    my $fields = parse_list_arg( @_ );

    my $constraint;
    if ( @$fields ) {
        for my $f ( @$fields ) {
            return $self->error(qq[Invalid field "$f"]) unless 
                $self->get_field($f);
        }

        my $has_pk;
        for my $c ( $self->get_constraints ) {
            if ( $c->type eq PRIMARY_KEY ) {
                $has_pk = 1;
                $c->fields( @{ $c->fields }, @$fields );
                $constraint = $c;
            } 
        }

        unless ( $has_pk ) {
            $constraint = $self->add_constraint(
                type   => PRIMARY_KEY,
                fields => $fields,
            ) or return;
        }
    }

    if ( $constraint ) {
        return $constraint;
    }
    else {
        for my $c ( $self->get_constraints ) {
            return $c if $c->type eq PRIMARY_KEY;
        }
    }

    return;
}

# ----------------------------------------------------------------------
sub options {

=pod

=head2 options

Get or set the table's options (e.g., table types for MySQL).  Returns
an array or array reference.

  my @options = $table->options;

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
sub order {

=pod

=head2 order

Get or set the table's order.

  my $order = $table->order(3);

=cut

    my ( $self, $arg ) = @_;

    if ( defined $arg && $arg =~ /^\d+$/ ) {
        $self->{'order'} = $arg;
    }

    return $self->{'order'} || 0;
}

# ----------------------------------------------------------------------
sub DESTROY {
    my $self = shift;
    undef $self->{'schema'}; # destroy cyclical reference
    undef $_ for @{ $self->{'constraints'} };
    undef $_ for @{ $self->{'indices'} };
    undef $_ for values %{ $self->{'fields'} };
}

1;

# ----------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
