package SQL::Translator::Schema::Table;

=pod

=head1 NAME

SQL::Translator::Schema::Table - SQL::Translator table object

=head1 SYNOPSIS

  use SQL::Translator::Schema::Table;
  my $table = SQL::Translator::Schema::Table->new( name => 'foo' );

=head1 DESCRIPTION

C<SQL::Translator::Schema::Table> is the table object.

=head1 METHODS

=cut

use Moo;
use SQL::Translator::Utils qw(parse_list_arg ex2err throw carp_ro);
use SQL::Translator::Types qw(schema_obj);
use SQL::Translator::Role::ListAttr;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Schema::Constraint;
use SQL::Translator::Schema::Field;
use SQL::Translator::Schema::Index;

use Carp::Clan '^SQL::Translator';
use List::Util 'max';
use Sub::Quote qw(quote_sub);

extends 'SQL::Translator::Schema::Object';

our $VERSION = '1.62';

# Stringify to our name, being careful not to pass any args through so we don't
# accidentally set it to undef. We also have to tweak bool so the object is
# still true when it doesn't have a name (which shouldn't happen!).
use overload
    '""'     => sub { shift->name },
    'bool'   => sub { $_[0]->name || $_[0] },
    fallback => 1,
;

=pod

=head2 new

Object constructor.

  my $table  =  SQL::Translator::Schema::Table->new(
      schema => $schema,
      name   => 'foo',
  );

=head2 add_constraint

Add a constraint to the table.  Returns the newly created
C<SQL::Translator::Schema::Constraint> object.

  my $c1     = $table->add_constraint(
      name   => 'pk',
      type   => PRIMARY_KEY,
      fields => [ 'foo_id' ],
  );

  my $c2 = SQL::Translator::Schema::Constraint->new( name => 'uniq' );
  $c2    = $table->add_constraint( $constraint );

=cut

has _constraints => (
    is => 'ro',
    init_arg => undef,
    default => quote_sub(q{ +[] }),
    predicate => 1,
    lazy => 1,
);

sub add_constraint {
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
        $pk->name($constraint->name) if $constraint->name;
        my %extra = $constraint->extra;
        $pk->extra(%extra) if keys %extra;
        $constraint = $pk;
        $ok         = 0;
    }
    elsif ( $constraint->type eq PRIMARY_KEY ) {
        for my $fname ( $constraint->fields ) {
            if ( my $f = $self->get_field( $fname ) ) {
                $f->is_primary_key( 1 );
            }
        }
    }
    #
    # See if another constraint of the same type
    # covers the same fields.  -- This doesn't work!  ky
    #
#    elsif ( $constraint->type ne CHECK_C ) {
#        my @field_names = $constraint->fields;
#        for my $c (
#            grep { $_->type eq $constraint->type }
#            $self->get_constraints
#        ) {
#            my %fields = map { $_, 1 } $c->fields;
#            for my $field_name ( @field_names ) {
#                if ( $fields{ $field_name } ) {
#                    $constraint = $c;
#                    $ok = 0;
#                    last;
#                }
#            }
#            last unless $ok;
#        }
#    }

    if ( $ok ) {
        push @{ $self->_constraints }, $constraint;
    }

    return $constraint;
}

=head2 drop_constraint

Remove a constraint from the table. Returns the constraint object if the index
was found and removed, an error otherwise. The single parameter can be either
an index name or an C<SQL::Translator::Schema::Constraint> object.

  $table->drop_constraint('myconstraint');

=cut

sub drop_constraint {
    my $self             = shift;
    my $constraint_class = 'SQL::Translator::Schema::Constraint';
    my $constraint_name;

    if ( UNIVERSAL::isa( $_[0], $constraint_class ) ) {
        $constraint_name = shift->name;
    }
    else {
        $constraint_name = shift;
    }

    if ( ! ($self->_has_constraints && grep { $_->name eq $constraint_name } @ { $self->_constraints }) ) {
        return $self->error(qq[Can't drop constraint: "$constraint_name" doesn't exist]);
    }

    my @cs = @{ $self->_constraints };
    my ($constraint_id) = grep { $cs[$_]->name eq  $constraint_name } (0..$#cs);
    my $constraint = splice(@{$self->_constraints}, $constraint_id, 1);

    return $constraint;
}

=head2 add_index

Add an index to the table.  Returns the newly created
C<SQL::Translator::Schema::Index> object.

  my $i1     = $table->add_index(
      name   => 'name',
      fields => [ 'name' ],
      type   => 'normal',
  );

  my $i2 = SQL::Translator::Schema::Index->new( name => 'id' );
  $i2    = $table->add_index( $index );

=cut

has _indices => (
    is => 'ro',
    init_arg => undef,
    default => quote_sub(q{ [] }),
    predicate => 1,
    lazy => 1,
);

sub add_index {
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
    foreach my $ex_index ($self->get_indices) {
       return if ($ex_index->equals($index));
    }
    push @{ $self->_indices }, $index;
    return $index;
}

=head2 drop_index

Remove an index from the table. Returns the index object if the index was
found and removed, an error otherwise. The single parameter can be either
an index name of an C<SQL::Translator::Schema::Index> object.

  $table->drop_index('myindex');

=cut

sub drop_index {
    my $self        = shift;
    my $index_class = 'SQL::Translator::Schema::Index';
    my $index_name;

    if ( UNIVERSAL::isa( $_[0], $index_class ) ) {
        $index_name = shift->name;
    }
    else {
        $index_name = shift;
    }

    if ( ! ($self->_has_indices && grep { $_->name eq  $index_name } @{ $self->_indices }) ) {
        return $self->error(qq[Can't drop index: "$index_name" doesn't exist]);
    }

    my @is = @{ $self->_indices };
    my ($index_id) = grep { $is[$_]->name eq  $index_name } (0..$#is);
    my $index = splice(@{$self->_indices}, $index_id, 1);

    return $index;
}

=head2 add_field

Add an field to the table.  Returns the newly created
C<SQL::Translator::Schema::Field> object.  The "name" parameter is
required.  If you try to create a field with the same name as an
existing field, you will get an error and the field will not be created.

  my $f1        =  $table->add_field(
      name      => 'foo_id',
      data_type => 'integer',
      size      => 11,
  );

  my $f2     =  SQL::Translator::Schema::Field->new(
      name   => 'name',
      table  => $table,
  );
  $f2 = $table->add_field( $field2 ) or die $table->error;

=cut

has _fields => (
    is => 'ro',
    init_arg => undef,
    default => quote_sub(q{ +{} }),
    predicate => 1,
    lazy => 1
);

sub add_field {
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

    my $existing_order = { map { $_->order => $_->name } $self->get_fields };

    # supplied order, possible unordered assembly
    if ( $field->order ) {
        if($existing_order->{$field->order}) {
            croak sprintf
                "Requested order '%d' for column '%s' conflicts with already existing column '%s'",
                $field->order,
                $field->name,
                $existing_order->{$field->order},
            ;
        }
    }
    else {
        my $last_field_no = max(keys %$existing_order) || 0;
        if ( $last_field_no != scalar keys %$existing_order ) {
            croak sprintf
                "Table '%s' field order incomplete - unable to auto-determine order for newly added field",
                $self->name,
            ;
        }

        $field->order( $last_field_no + 1 );
    }

    # We know we have a name as the Field->new above errors if none given.
    my $field_name = $field->name;

    if ( $self->get_field($field_name) ) {
        return $self->error(qq[Can't use field name "$field_name": field exists]);
    }
    else {
        $self->_fields->{ $field_name } = $field;
    }

    return $field;
}

=head2 drop_field

Remove a field from the table. Returns the field object if the field was
found and removed, an error otherwise. The single parameter can be either
a field name or an C<SQL::Translator::Schema::Field> object.

  $table->drop_field('myfield');

=cut

sub drop_field {
    my $self        = shift;
    my $field_class = 'SQL::Translator::Schema::Field';
    my $field_name;

    if ( UNIVERSAL::isa( $_[0], $field_class ) ) {
        $field_name = shift->name;
    }
    else {
        $field_name = shift;
    }
    my %args = @_;
    my $cascade = $args{'cascade'};

    if ( ! ($self->_has_fields && exists $self->_fields->{ $field_name } ) ) {
        return $self->error(qq[Can't drop field: "$field_name" doesn't exists]);
    }

    my $field = delete $self->_fields->{ $field_name };

    if ( $cascade ) {
        # Remove this field from all indices using it
        foreach my $i ($self->get_indices()) {
            my @fs = $i->fields();
            @fs = grep { $_ ne $field->name } @fs;
            $i->fields(@fs);
        }

        # Remove this field from all constraints using it
        foreach my $c ($self->get_constraints()) {
            my @cs = $c->fields();
            @cs = grep { $_ ne $field->name } @cs;
            $c->fields(@cs);
        }
    }

    return $field;
}

=head2 comments

Get or set the comments on a table.  May be called several times to
set and it will accumulate the comments.  Called in an array context,
returns each comment individually; called in a scalar context, returns
all the comments joined on newlines.

  $table->comments('foo');
  $table->comments('bar');
  print join( ', ', $table->comments ); # prints "foo, bar"

=cut

has comments => (
    is => 'rw',
    coerce => quote_sub(q{ ref($_[0]) eq 'ARRAY' ? $_[0] : [$_[0]] }),
    default => quote_sub(q{ [] }),
);

around comments => sub {
    my $orig     = shift;
    my $self     = shift;
    my @comments = ref $_[0] ? @{ $_[0] } : @_;

    for my $arg ( @comments ) {
        $arg = $arg->[0] if ref $arg;
        push @{ $self->$orig }, $arg if defined $arg && $arg;
    }

    @comments = @{$self->$orig};
    return wantarray ? @comments
        : @comments ? join( "\n", @comments )
        : undef;
};

=head2 get_constraints

Returns all the constraint objects as an array or array reference.

  my @constraints = $table->get_constraints;

=cut

sub get_constraints {
    my $self = shift;

    if ( $self->_has_constraints ) {
        return wantarray
            ? @{ $self->_constraints } : $self->_constraints;
    }
    else {
        $self->error('No constraints');
        return;
    }
}

=head2 get_indices

Returns all the index objects as an array or array reference.

  my @indices = $table->get_indices;

=cut

sub get_indices {
    my $self = shift;

    if ( $self->_has_indices ) {
        return wantarray
            ? @{ $self->_indices }
            : $self->_indices;
    }
    else {
        $self->error('No indices');
        return;
    }
}

=head2 get_field

Returns a field by the name provided.

  my $field = $table->get_field('foo');

=cut

sub get_field {
    my $self       = shift;
    my $field_name = shift or return $self->error('No field name');
    my $case_insensitive = shift;
    return $self->error(qq[Field "$field_name" does not exist])
        unless $self->_has_fields;
    if ( $case_insensitive ) {
      $field_name = uc($field_name);
      foreach my $field ( keys %{$self->_fields} ) {
         return $self->_fields->{$field} if $field_name eq uc($field);
      }
      return $self->error(qq[Field "$field_name" does not exist]);
    }
    return $self->error( qq[Field "$field_name" does not exist] ) unless
        exists $self->_fields->{ $field_name };
    return $self->_fields->{ $field_name };
}

=head2 get_fields

Returns all the field objects as an array or array reference.

  my @fields = $table->get_fields;

=cut

sub get_fields {
    my $self = shift;
    my @fields =
        map  { $_->[1] }
        sort { $a->[0] <=> $b->[0] }
        map  { [ $_->order, $_ ] }
        values %{ $self->_has_fields ? $self->_fields : {} };

    if ( @fields ) {
        return wantarray ? @fields : \@fields;
    }
    else {
        $self->error('No fields');
        return;
    }
}

=head2 is_valid

Determine whether the view is valid or not.

  my $ok = $view->is_valid;

=cut

sub is_valid {
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

=head2 is_trivial_link

True if table has no data (non-key) fields and only uses single key joins.

=cut

has is_trivial_link => ( is => 'lazy', init_arg => undef );

around is_trivial_link => carp_ro('is_trivial_link');

sub _build_is_trivial_link {
    my $self = shift;
    return 0 if $self->is_data;

    my %fk = ();

    foreach my $field ( $self->get_fields ) {
     next unless $field->is_foreign_key;
     $fk{$field->foreign_key_reference->reference_table}++;
   }

    foreach my $referenced (keys %fk){
   if($fk{$referenced} > 1){
       return 0;
   }
    }

    return 1;
}

=head2 is_data

Returns true if the table has some non-key fields.

=cut

has is_data => ( is => 'lazy', init_arg => undef );

around is_data => carp_ro('is_data');

sub _build_is_data {
    my $self = shift;

    foreach my $field ( $self->get_fields ) {
        if ( !$field->is_primary_key and !$field->is_foreign_key ) {
            return 1;
        }
    }

    return 0;
}

=head2 can_link

Determine whether the table can link two arg tables via many-to-many.

  my $ok = $table->can_link($table1,$table2);

=cut

has _can_link => ( is => 'ro', init_arg => undef, default => quote_sub(q{ +{} }) );

sub can_link {
    my ( $self, $table1, $table2 ) = @_;

    return $self->_can_link->{ $table1->name }{ $table2->name }
      if defined $self->_can_link->{ $table1->name }{ $table2->name };

    if ( $self->is_data == 1 ) {
        $self->_can_link->{ $table1->name }{ $table2->name } = [0];
        $self->_can_link->{ $table2->name }{ $table1->name } = [0];
        return $self->_can_link->{ $table1->name }{ $table2->name };
    }

    my %fk = ();

    foreach my $field ( $self->get_fields ) {
        if ( $field->is_foreign_key ) {
            push @{ $fk{ $field->foreign_key_reference->reference_table } },
              $field->foreign_key_reference;
        }
    }

    if ( !defined( $fk{ $table1->name } ) or !defined( $fk{ $table2->name } ) )
    {
        $self->_can_link->{ $table1->name }{ $table2->name } = [0];
        $self->_can_link->{ $table2->name }{ $table1->name } = [0];
        return $self->_can_link->{ $table1->name }{ $table2->name };
    }

    # trivial traversal, only one way to link the two tables
    if (    scalar( @{ $fk{ $table1->name } } == 1 )
        and scalar( @{ $fk{ $table2->name } } == 1 ) )
    {
        $self->_can_link->{ $table1->name }{ $table2->name } =
          [ 'one2one', $fk{ $table1->name }, $fk{ $table2->name } ];
        $self->_can_link->{ $table1->name }{ $table2->name } =
          [ 'one2one', $fk{ $table2->name }, $fk{ $table1->name } ];

        # non-trivial traversal.  one way to link table2,
        # many ways to link table1
    }
    elsif ( scalar( @{ $fk{ $table1->name } } > 1 )
        and scalar( @{ $fk{ $table2->name } } == 1 ) )
    {
        $self->_can_link->{ $table1->name }{ $table2->name } =
          [ 'many2one', $fk{ $table1->name }, $fk{ $table2->name } ];
        $self->_can_link->{ $table2->name }{ $table1->name } =
          [ 'one2many', $fk{ $table2->name }, $fk{ $table1->name } ];

        # non-trivial traversal.  one way to link table1,
        # many ways to link table2
    }
    elsif ( scalar( @{ $fk{ $table1->name } } == 1 )
        and scalar( @{ $fk{ $table2->name } } > 1 ) )
    {
        $self->_can_link->{ $table1->name }{ $table2->name } =
          [ 'one2many', $fk{ $table1->name }, $fk{ $table2->name } ];
        $self->_can_link->{ $table2->name }{ $table1->name } =
          [ 'many2one', $fk{ $table2->name }, $fk{ $table1->name } ];

        # non-trivial traversal.  many ways to link table1 and table2
    }
    elsif ( scalar( @{ $fk{ $table1->name } } > 1 )
        and scalar( @{ $fk{ $table2->name } } > 1 ) )
    {
        $self->_can_link->{ $table1->name }{ $table2->name } =
          [ 'many2many', $fk{ $table1->name }, $fk{ $table2->name } ];
        $self->_can_link->{ $table2->name }{ $table1->name } =
          [ 'many2many', $fk{ $table2->name }, $fk{ $table1->name } ];

        # one of the tables didn't export a key
        # to this table, no linking possible
    }
    else {
        $self->_can_link->{ $table1->name }{ $table2->name } = [0];
        $self->_can_link->{ $table2->name }{ $table1->name } = [0];
    }

    return $self->_can_link->{ $table1->name }{ $table2->name };
}

=head2 name

Get or set the table's name.

Errors ("No table name") if you try to set a blank name.

If provided an argument, checks the schema object for a table of
that name and disallows the change if one exists (setting the error to
"Can't use table name "%s": table exists").

  my $table_name = $table->name('foo');

=cut

has name => (
    is => 'rw',
    isa => sub { throw("No table name") unless $_[0] },
);

around name => sub {
    my $orig = shift;
    my $self = shift;

    if ( my ($arg) = @_ ) {
        if ( my $schema = $self->schema ) {
            return $self->error( qq[Can't use table name "$arg": table exists] )
                if $schema->get_table( $arg );
        }
    }

    return ex2err($orig, $self, @_);
};

=head2 schema

Get or set the table's schema object.

  my $schema = $table->schema;

=cut

has schema => ( is => 'rw', isa => schema_obj('Schema'), weak_ref => 1 );

around schema => \&ex2err;

sub primary_key {

=pod

=head2 primary_key

Gets or sets the table's primary key(s).  Takes one or more field
names (as a string, list or array[ref]) as an argument.  If the field
names are present, it will create a new PK if none exists, or it will
add to the fields of an existing PK (and will unique the field names).
Returns the C<SQL::Translator::Schema::Constraint> object representing
the primary key.

These are equivalent:

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

=head2 options

Get or append to the table's options (e.g., table types for MySQL).
Returns an array or array reference.

  my @options = $table->options;

=cut

with ListAttr options => ( append => 1 );

=head2 order

Get or set the table's order.

  my $order = $table->order(3);

=cut

has order => ( is => 'rw', default => quote_sub(q{ 0 }) );

around order => sub {
    my ( $orig, $self, $arg ) = @_;

    if ( defined $arg && $arg =~ /^\d+$/ ) {
        return $self->$orig($arg);
    }

    return $self->$orig;
};

=head2 field_names

Read-only method to return a list or array ref of the field names. Returns undef
or an empty list if the table has no fields set. Useful if you want to
avoid the overload magic of the Field objects returned by the get_fields method.

  my @names = $constraint->field_names;

=cut

sub field_names {
    my $self = shift;
    my @fields =
        map  { $_->name }
        $self->get_fields;

    if ( @fields ) {
        return wantarray ? @fields : \@fields;
    }
    else {
        $self->error('No fields');
        return;
    }
}

sub equals {

=pod

=head2 equals

Determines if this table is the same as another

  my $isIdentical = $table1->equals( $table2 );

=cut

    my $self = shift;
    my $other = shift;
    my $case_insensitive = shift;

    return 0 unless $self->SUPER::equals($other);
    return 0 unless $case_insensitive ? uc($self->name) eq uc($other->name) : $self->name eq $other->name;
    return 0 unless $self->_compare_objects(scalar $self->options, scalar $other->options);
    return 0 unless $self->_compare_objects(scalar $self->extra, scalar $other->extra);

    # Fields
    # Go through our fields
    my %checkedFields;
    foreach my $field ( $self->get_fields ) {
      my $otherField = $other->get_field($field->name, $case_insensitive);
      return 0 unless $field->equals($otherField, $case_insensitive);
      $checkedFields{$field->name} = 1;
    }
    # Go through the other table's fields
    foreach my $otherField ( $other->get_fields ) {
      next if $checkedFields{$otherField->name};
      return 0;
    }

    # Constraints
    # Go through our constraints
    my %checkedConstraints;
CONSTRAINT:
    foreach my $constraint ( $self->get_constraints ) {
      foreach my $otherConstraint ( $other->get_constraints ) {
         if ( $constraint->equals($otherConstraint, $case_insensitive) ) {
            $checkedConstraints{$otherConstraint} = 1;
            next CONSTRAINT;
         }
      }
      return 0;
    }
    # Go through the other table's constraints
CONSTRAINT2:
    foreach my $otherConstraint ( $other->get_constraints ) {
      next if $checkedFields{$otherConstraint};
      foreach my $constraint ( $self->get_constraints ) {
         if ( $otherConstraint->equals($constraint, $case_insensitive) ) {
            next CONSTRAINT2;
         }
      }
      return 0;
    }

    # Indices
    # Go through our indices
    my %checkedIndices;
INDEX:
    foreach my $index ( $self->get_indices ) {
      foreach my $otherIndex ( $other->get_indices ) {
         if ( $index->equals($otherIndex, $case_insensitive) ) {
            $checkedIndices{$otherIndex} = 1;
            next INDEX;
         }
      }
      return 0;
    }
    # Go through the other table's indices
INDEX2:
    foreach my $otherIndex ( $other->get_indices ) {
      next if $checkedIndices{$otherIndex};
      foreach my $index ( $self->get_indices ) {
         if ( $otherIndex->equals($index, $case_insensitive) ) {
            next INDEX2;
         }
      }
      return 0;
    }

   return 1;
}

=head1 LOOKUP METHODS

The following are a set of shortcut methods for getting commonly used lists of
fields and constraints. They all return lists or array refs of Field or
Constraint objects.

=over 4

=item pkey_fields

The primary key fields.

=item fkey_fields

All foreign key fields.

=item nonpkey_fields

All the fields except the primary key.

=item data_fields

All non key fields.

=item unique_fields

All fields with unique constraints.

=item unique_constraints

All this tables unique constraints.

=item fkey_constraints

All this tables foreign key constraints. (See primary_key method to get the
primary key constraint)

=back

=cut

sub pkey_fields {
    my $me = shift;
    my @fields = grep { $_->is_primary_key } $me->get_fields;
    return wantarray ? @fields : \@fields;
}

sub fkey_fields {
    my $me = shift;
    my @fields;
    push @fields, $_->fields foreach $me->fkey_constraints;
    return wantarray ? @fields : \@fields;
}

sub nonpkey_fields {
    my $me = shift;
    my @fields = grep { !$_->is_primary_key } $me->get_fields;
    return wantarray ? @fields : \@fields;
}

sub data_fields {
    my $me = shift;
    my @fields =
        grep { !$_->is_foreign_key and !$_->is_primary_key } $me->get_fields;
    return wantarray ? @fields : \@fields;
}

sub unique_fields {
    my $me = shift;
    my @fields;
    push @fields, $_->fields foreach $me->unique_constraints;
    return wantarray ? @fields : \@fields;
}

sub unique_constraints {
    my $me = shift;
    my @cons = grep { $_->type eq UNIQUE } $me->get_constraints;
    return wantarray ? @cons : \@cons;
}

sub fkey_constraints {
    my $me = shift;
    my @cons = grep { $_->type eq FOREIGN_KEY } $me->get_constraints;
    return wantarray ? @cons : \@cons;
}

# Must come after all 'has' declarations
around new => \&ex2err;

1;

=pod

=head1 AUTHORS

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>,
Allen Day E<lt>allenday@ucla.eduE<gt>.

=cut
