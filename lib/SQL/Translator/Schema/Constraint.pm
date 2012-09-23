package SQL::Translator::Schema::Constraint;

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

use Moo;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(ex2err throw);
use SQL::Translator::Role::ListAttr;
use SQL::Translator::Types qw(schema_obj enum);
use Sub::Quote qw(quote_sub);

extends 'SQL::Translator::Schema::Object';

our $VERSION = '1.59';

my %VALID_CONSTRAINT_TYPE = (
    PRIMARY_KEY, 1,
    UNIQUE,      1,
    CHECK_C,     1,
    FOREIGN_KEY, 1,
    NOT_NULL,    1,
);

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

# Override to remove empty arrays from args.
# t/14postgres-parser breaks without this.
around BUILDARGS => sub {
    my $orig = shift;
    my $self = shift;
    my $args = $self->$orig(@_);

    foreach my $arg (keys %{$args}) {
        delete $args->{$arg} if ref($args->{$arg}) eq "ARRAY" && !@{$args->{$arg}};
    }
    if (exists $args->{fields}) {
        $args->{field_names} = delete $args->{fields};
    }
    return $args;
};

=head2 deferrable

Get or set whether the constraint is deferrable.  If not defined,
then returns "1."  The argument is evaluated by Perl for True or
False, so the following are eqivalent:

  $deferrable = $field->deferrable(0);
  $deferrable = $field->deferrable('');
  $deferrable = $field->deferrable('0');

=cut

has deferrable => (
    is => 'rw',
    coerce => quote_sub(q{ $_[0] ? 1 : 0 }),
    default => quote_sub(q{ 1 }),
);

=head2 expression

Gets and set the expression used in a CHECK constraint.

  my $expression = $constraint->expression('...');

=cut

has expression => ( is => 'rw', default => quote_sub(q{ '' }) );

around expression => sub {
    my ($orig, $self, $arg) = @_;
    $self->$orig($arg || ());
};

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
                "Constraint from field(s) ".
                join(', ', map {qq['$table_name.$_']} @fields).
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

sub fields {
    my $self = shift;
    my $table = $self->table;
    my @tables = map { $table->get_field($_) || $_ } @{$self->field_names(@_) || []};
    return wantarray ? @tables
        : @tables ? \@tables
        : undef;
}

=head2 field_names

Read-only method to return a list or array ref of the field names. Returns undef
or an empty list if the constraint has no fields set. Useful if you want to
avoid the overload magic of the Field objects returned by the fields method.

  my @names = $constraint->field_names;

=cut

with ListAttr field_names => ( uniq => 1, undef_if_empty => 1 );

=head2 match_type

Get or set the constraint's match_type.  Only valid values are "full"
"partial" and "simple"

  my $match_type = $constraint->match_type('FULL');

=cut

has match_type => (
    is => 'rw',
    default => quote_sub(q{ '' }),
    coerce => quote_sub(q{ lc $_[0] }),
    isa => enum([qw(full partial simple)], {
        msg => "Invalid match type: %s", allow_false => 1,
    }),
);

around match_type => \&ex2err;

=head2 name

Get or set the constraint's name.

  my $name = $constraint->name('foo');

=cut

has name => ( is => 'rw', default => quote_sub(q{ '' }) );

around name => sub {
    my ($orig, $self, $arg) = @_;
    $self->$orig($arg || ());
};

=head2 options

Gets or adds to the constraints's options (e.g., "INITIALLY IMMEDIATE").
Returns an array or array reference.

  $constraint->options('NORELY');
  my @options = $constraint->options;

=cut

with ListAttr options => ();

=head2 on_delete

Get or set the constraint's "on delete" action.

  my $action = $constraint->on_delete('cascade');

=cut

has on_delete => ( is => 'rw', default => quote_sub(q{ '' }) );

around on_delete => sub {
    my ($orig, $self, $arg) = @_;
    $self->$orig($arg || ());
};

=head2 on_update

Get or set the constraint's "on update" action.

  my $action = $constraint->on_update('no action');

=cut

has on_update => ( is => 'rw', default => quote_sub(q{ '' }) );

around on_update => sub {
    my ($orig, $self, $arg) = @_;
    $self->$orig($arg || ());
};

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

with ListAttr reference_fields => (
    may_throw => 1,
    builder => 1,
    lazy => 1,
);

sub _build_reference_fields {
    my ($self) = @_;

    my $table   = $self->table   or throw('No table');
    my $schema  = $table->schema or throw('No schema');
    if ( my $ref_table_name = $self->reference_table ) {
        my $ref_table  = $schema->get_table( $ref_table_name ) or
            throw("Can't find table '$ref_table_name'");

        if ( my $constraint = $ref_table->primary_key ) {
            return [ $constraint->fields ];
        }
        else {
            throw(
                'No reference fields defined and cannot find primary key in ',
                "reference table '$ref_table_name'"
            );
        }
    }
}

=head2 reference_table

Get or set the table referred to by the constraint.

  my $reference_table = $constraint->reference_table('foo');

=cut

has reference_table => ( is => 'rw', default => quote_sub(q{ '' }) );

=head2 table

Get or set the constraint's table object.

  my $table = $field->table;

=cut

has table => ( is => 'rw', isa => schema_obj('Table'), weak_ref => 1 );

around table => \&ex2err;

=head2 type

Get or set the constraint's type.

  my $type = $constraint->type( PRIMARY_KEY );

=cut

has type => (
    is => 'rw',
    default => quote_sub(q{ '' }),
    coerce => quote_sub(q{ (my $t = $_[0]) =~ s/_/ /g; uc $t }),
    isa => enum([keys %VALID_CONSTRAINT_TYPE], {
        msg => "Invalid constraint type: %s", allow_false => 1,
    }),
);

around type => \&ex2err;

=head2 equals

Determines if this constraint is the same as another

  my $isIdentical = $constraint1->equals( $constraint2 );

=cut

around equals => sub {
    my $orig = shift;
    my $self = shift;
    my $other = shift;
    my $case_insensitive = shift;
    my $ignore_constraint_names = shift;

    return 0 unless $self->$orig($other);
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
    my %otherFields = ();  # create a hash of the other fields
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
    my %otherRefFields = ();  # create a hash of the other reference fields
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
};

# Must come after all 'has' declarations
around new => \&ex2err;

1;

=pod

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut
