package SQL::Translator::Schema::Constraint;

# ----------------------------------------------------------------------
# Copyright (C) 2002-2009 SQLFairy Authors
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
      type   => PRIMARY_KEY,
  );

=head1 DESCRIPTION

C<SQL::Translator::Schema::Constraint> is the constraint object.

=head1 METHODS

=cut

use strict;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils 'parse_list_arg';

use base 'SQL::Translator::Schema::Object';

use vars qw($VERSION $TABLE_COUNT $VIEW_COUNT);

$VERSION = '1.59';

my %VALID_CONSTRAINT_TYPE = (
    PRIMARY_KEY, 1,
    UNIQUE,      1,
    CHECK_C,     1,
    FOREIGN_KEY, 1,
    NOT_NULL,    1,
);

# ----------------------------------------------------------------------

__PACKAGE__->_attributes( qw/
    table name type fields reference_fields reference_table 
    match_type on_delete on_update expression deferrable
/);

# Override to remove empty arrays from args.
# t/14postgres-parser breaks without this.
sub init {
    
=pod

=head2 new

Object constructor.

  my $schema           =  SQL::Translator::Schema::Constraint->new(
      table            => $table,        # table to which it belongs
      type             => 'foreign_key', # type of table constraint
      name             => 'fk_phone_id', # name of the constraint
      fields           => 'phone_id',    # field in the referring table
      reference_fields => 'phone_id',    # referenced field
      reference_table  => 'phone',       # referenced table
      match_type       => 'full',        # how to match
      on_delete        => 'cascade',     # what to do on deletes
      on_update        => '',            # what to do on updates
  );

=cut

    my $self = shift;
    foreach ( values %{$_[0]} ) { $_ = undef if ref($_) eq "ARRAY" && ! @$_; }
    $self->SUPER::init(@_);
}

# ----------------------------------------------------------------------
sub deferrable {

=pod

=head2 deferrable

Get or set whether the constraint is deferrable.  If not defined,
then returns "1."  The argument is evaluated by Perl for True or
False, so the following are eqivalent:

  $deferrable = $field->deferrable(0);
  $deferrable = $field->deferrable('');
  $deferrable = $field->deferrable('0');

=cut

    my ( $self, $arg ) = @_;

    if ( defined $arg ) {
        $self->{'deferrable'} = $arg ? 1 : 0;
    }

    return defined $self->{'deferrable'} ? $self->{'deferrable'} : 1;
}

# ----------------------------------------------------------------------
sub expression {

=pod

=head2 expression

Gets and set the expression used in a CHECK constraint.

  my $expression = $constraint->expression('...');

=cut

    my $self = shift;
    
    if ( my $arg = shift ) {
        # check arg here?
        $self->{'expression'} = $arg;
    }

    return $self->{'expression'} || '';
}

# ----------------------------------------------------------------------
sub is_valid {

=pod

=head2 is_valid

Determine whether the constraint is valid or not.

  my $ok = $constraint->is_valid;

=cut

    my $self       = shift;
    my $type       = $self->type   or return $self->error('No type');
    my $table      = $self->table  or return $self->error('No table');
    my @fields     = $self->fields or return $self->error('No fields');
    my $table_name = $table->name  or return $self->error('No table name');

    for my $f ( @fields ) {
        next if $table->get_field( $f );
        return $self->error(
            "Constraint references non-existent field '$f' ",
            "in table '$table_name'"
        );
    }

    my $schema = $table->schema or return $self->error(
        'Table ', $table->name, ' has no schema object'
    );

    if ( $type eq FOREIGN_KEY ) {
        return $self->error('Only one field allowed for foreign key')
            if scalar @fields > 1;

        my $ref_table_name  = $self->reference_table or 
            return $self->error('No reference table');

        my $ref_table = $schema->get_table( $ref_table_name ) or
            return $self->error("No table named '$ref_table_name' in schema");

        my @ref_fields = $self->reference_fields or return;

        return $self->error('Only one field allowed for foreign key reference')
            if scalar @ref_fields > 1;

        for my $ref_field ( @ref_fields ) {
            next if $ref_table->get_field( $ref_field );
            return $self->error(
                "Constraint from field(s) ", 
                join(', ', map {qq['$table_name.$_']} @fields),
                " to non-existent field '$ref_table_name.$ref_field'"
            );
        }
    }
    elsif ( $type eq CHECK_C ) {
        return $self->error('No expression for CHECK') unless 
            $self->expression;
    }

    return 1;
}

# ----------------------------------------------------------------------
sub fields {

=pod

=head2 fields

Gets and set the fields the constraint is on.  Accepts a string, list or
arrayref; returns an array or array reference.  Will unique the field
names and keep them in order by the first occurrence of a field name.

The fields are returned as Field objects if they exist or as plain
names if not. (If you just want the names and want to avoid the Field's overload
magic use L<field_names>).

Returns undef or an empty list if the constraint has no fields set.

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

    if ( @{ $self->{'fields'} || [] } ) {
        # We have to return fields that don't exist on the table as names in
        # case those fields havn't been created yet.
        my @ret = map {
            $self->table->get_field($_) || $_ } @{ $self->{'fields'} };
        return wantarray ? @ret : \@ret;
    }
    else {
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub field_names {

=head2 field_names

Read-only method to return a list or array ref of the field names. Returns undef
or an empty list if the constraint has no fields set. Usefull if you want to
avoid the overload magic of the Field objects returned by the fields method.

  my @names = $constraint->field_names;

=cut

    my $self = shift;
    return wantarray ? @{ $self->{'fields'} || [] } : ($self->{'fields'} || '');
}

# ----------------------------------------------------------------------
sub match_type {

=pod

=head2 match_type

Get or set the constraint's match_type.  Only valid values are "full"
or "partial."

  my $match_type = $constraint->match_type('FULL');

=cut

    my ( $self, $arg ) = @_;
    
    if ( $arg ) {
        $arg = lc $arg;
        return $self->error("Invalid match type: $arg")
            unless $arg eq 'full' || $arg eq 'partial';
        $self->{'match_type'} = $arg;
    }

    return $self->{'match_type'} || '';
}

# ----------------------------------------------------------------------
sub name {

=pod

=head2 name

Get or set the constraint's name.

  my $name = $constraint->name('foo');

=cut

    my $self = shift;
    my $arg  = shift || '';
    $self->{'name'} = $arg if $arg;
    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub options {

=pod

=head2 options

Gets or adds to the constraints's options (e.g., "INITIALLY IMMEDIATE").  
Returns an array or array reference.

  $constraint->options('NORELY');
  my @options = $constraint->options;

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
sub on_delete {

=pod

=head2 on_delete

Get or set the constraint's "on delete" action.

  my $action = $constraint->on_delete('cascade');

=cut

    my $self = shift;
    
    if ( my $arg = shift ) {
        # validate $arg?
        $self->{'on_delete'} = $arg;
    }

    return $self->{'on_delete'} || '';
}

# ----------------------------------------------------------------------
sub on_update {

=pod

=head2 on_update

Get or set the constraint's "on update" action.

  my $action = $constraint->on_update('no action');

=cut

    my $self = shift;
    
    if ( my $arg = shift ) {
        # validate $arg?
        $self->{'on_update'} = $arg;
    }

    return $self->{'on_update'} || '';
}

# ----------------------------------------------------------------------
sub reference_fields {

=pod

=head2 reference_fields

Gets and set the fields in the referred table.  Accepts a string, list or
arrayref; returns an array or array reference.

  $constraint->reference_fields('id');
  $constraint->reference_fields('id', 'name');
  $constraint->reference_fields( 'id, name' );
  $constraint->reference_fields( [ 'id', 'name' ] );
  $constraint->reference_fields( qw[ id name ] );

  my @reference_fields = $constraint->reference_fields;

=cut

    my $self   = shift;
    my $fields = parse_list_arg( @_ );

    if ( @$fields ) {
        $self->{'reference_fields'} = $fields;
    }

    # Nothing set so try and derive it from the other constraint data
    unless ( ref $self->{'reference_fields'} ) {
        my $table   = $self->table   or return $self->error('No table');
        my $schema  = $table->schema or return $self->error('No schema');
        if ( my $ref_table_name = $self->reference_table ) { 
            my $ref_table  = $schema->get_table( $ref_table_name ) or
                return $self->error("Can't find table '$ref_table_name'");

            if ( my $constraint = $ref_table->primary_key ) { 
                $self->{'reference_fields'} = [ $constraint->fields ];
            }
            else {
                $self->error(
                 'No reference fields defined and cannot find primary key in ',
                 "reference table '$ref_table_name'"
                );
            }
        }
        # No ref table so we are not that sort of constraint, hence no ref
        # fields. So we let the return below return an empty list.
    }

    if ( ref $self->{'reference_fields'} ) {
        return wantarray 
            ?  @{ $self->{'reference_fields'} } 
            :     $self->{'reference_fields'};
    }
    else {
        return wantarray ? () : [];
    }
}

# ----------------------------------------------------------------------
sub reference_table {

=pod

=head2 reference_table

Get or set the table referred to by the constraint.

  my $reference_table = $constraint->reference_table('foo');

=cut

    my $self = shift;
    $self->{'reference_table'} = shift if @_;
    return $self->{'reference_table'} || '';
}

# ----------------------------------------------------------------------
sub table {

=pod

=head2 table

Get or set the constraint's table object.

  my $table = $field->table;

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

Get or set the constraint's type.

  my $type = $constraint->type( PRIMARY_KEY );

=cut

    my ( $self, $type ) = @_;

    if ( $type ) {
        $type = uc $type;
        $type =~ s/_/ /g;
        return $self->error("Invalid constraint type: $type") 
            unless $VALID_CONSTRAINT_TYPE{ $type };
        $self->{'type'} = $type;
    }

    return $self->{'type'} || '';
}

# ----------------------------------------------------------------------
sub equals {

=pod

=head2 equals

Determines if this constraint is the same as another

  my $isIdentical = $constraint1->equals( $constraint2 );

=cut

    my $self = shift;
    my $other = shift;
    my $case_insensitive = shift;
    my $ignore_constraint_names = shift;
    
    return 0 unless $self->SUPER::equals($other);
    return 0 unless $self->type eq $other->type;
    unless ($ignore_constraint_names) {
        return 0 unless $case_insensitive ? uc($self->name) eq uc($other->name) : $self->name eq $other->name;
    }
    return 0 unless $self->deferrable eq $other->deferrable;
    #return 0 unless $self->is_valid eq $other->is_valid;
    return 0 unless $case_insensitive ? uc($self->table->name) eq uc($other->table->name)
    	: $self->table->name eq $other->table->name;
    return 0 unless $self->expression eq $other->expression;
    
    # Check fields, regardless of order
    my %otherFields = ();	# create a hash of the other fields
    foreach my $otherField ($other->fields) {
    	$otherField = uc($otherField) if $case_insensitive;
    	$otherFields{$otherField} = 1;
    }
    foreach my $selfField ($self->fields) { # check for self fields in hash
    	$selfField = uc($selfField) if $case_insensitive;
    	return 0 unless $otherFields{$selfField};
    	delete $otherFields{$selfField};
    }
    # Check all other fields were accounted for
    return 0 unless keys %otherFields == 0;

    # Check reference fields, regardless of order
    my %otherRefFields = ();	# create a hash of the other reference fields
    foreach my $otherRefField ($other->reference_fields) {
    	$otherRefField = uc($otherRefField) if $case_insensitive;
    	$otherRefFields{$otherRefField} = 1;
    }
    foreach my $selfRefField ($self->reference_fields) { # check for self reference fields in hash
    	$selfRefField = uc($selfRefField) if $case_insensitive;
    	return 0 unless $otherRefFields{$selfRefField};
    	delete $otherRefFields{$selfRefField};
    }
    # Check all other reference fields were accounted for
    return 0 unless keys %otherRefFields == 0;

    return 0 unless $case_insensitive ? uc($self->reference_table) eq uc($other->reference_table) : $self->reference_table eq $other->reference_table;
    return 0 unless $self->match_type eq $other->match_type;
    return 0 unless $self->on_delete eq $other->on_delete;
    return 0 unless $self->on_update eq $other->on_update;
    return 0 unless $self->_compare_objects(scalar $self->options, scalar $other->options);
    return 0 unless $self->_compare_objects(scalar $self->extra, scalar $other->extra);
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

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut
