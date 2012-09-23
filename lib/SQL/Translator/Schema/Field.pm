package SQL::Translator::Schema::Field;

=pod

=head1 NAME

SQL::Translator::Schema::Field - SQL::Translator field object

=head1 SYNOPSIS

  use SQL::Translator::Schema::Field;
  my $field = SQL::Translator::Schema::Field->new(
      name  => 'foo',
      table => $table,
  );

=head1 DESCRIPTION

C<SQL::Translator::Schema::Field> is the field object.

=head1 METHODS

=cut

use Moo;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Types qw(schema_obj);
use SQL::Translator::Utils qw(parse_list_arg ex2err throw carp_ro);
use Sub::Quote qw(quote_sub);

extends 'SQL::Translator::Schema::Object';

our $VERSION = '1.59';

# Stringify to our name, being careful not to pass any args through so we don't
# accidentally set it to undef. We also have to tweak bool so the object is
# still true when it doesn't have a name (which shouldn't happen!).
use overload
    '""'     => sub { shift->name },
    'bool'   => sub { $_[0]->name || $_[0] },
    fallback => 1,
;

use DBI qw(:sql_types);

# Mapping from string to sql contstant
our %type_mapping = (
  integer => SQL_INTEGER,
  int     => SQL_INTEGER,

  smallint => SQL_SMALLINT,
  bigint => 9999, # DBI doesn't export a constatn for this. Le suck

  double => SQL_DOUBLE,

  decimal => SQL_DECIMAL,
  numeric => SQL_NUMERIC,
  dec => SQL_DECIMAL,

  bit => SQL_BIT,

  date => SQL_DATE,
  datetime => SQL_DATETIME,
  timestamp => SQL_TIMESTAMP,
  time => SQL_TIME,

  char => SQL_CHAR,
  varchar => SQL_VARCHAR,
  binary => SQL_BINARY,
  varbinary => SQL_VARBINARY,
  tinyblob => SQL_BLOB,
  blob => SQL_BLOB,
  text => SQL_LONGVARCHAR

);

=head2 new

Object constructor.

  my $field = SQL::Translator::Schema::Field->new(
      name  => 'foo',
      table => $table,
  );

=head2 comments

Get or set the comments on a field.  May be called several times to
set and it will accumulate the comments.  Called in an array context,
returns each comment individually; called in a scalar context, returns
all the comments joined on newlines.

  $field->comments('foo');
  $field->comments('bar');
  print join( ', ', $field->comments ); # prints "foo, bar"

=cut

has comments => (
    is => 'rw',
    coerce => quote_sub(q{ ref($_[0]) eq 'ARRAY' ? $_[0] : [$_[0]] }),
    default => quote_sub(q{ [] }),
);

around comments => sub {
    my $orig = shift;
    my $self = shift;

    for my $arg ( @_ ) {
        $arg = $arg->[0] if ref $arg;
        push @{ $self->$orig }, $arg if $arg;
    }

    return wantarray
        ? @{ $self->$orig }
        : join( "\n", @{ $self->$orig } );
};


=head2 data_type

Get or set the field's data type.

  my $data_type = $field->data_type('integer');

=cut

has data_type => ( is => 'rw', default => quote_sub(q{ '' }) );

=head2 sql_data_type

Constant from DBI package representing this data type. See L<DBI/DBI Constants>
for more details.

=cut

has sql_data_type => ( is => 'rw', lazy => 1, builder => 1 );

sub _build_sql_data_type {
    $type_mapping{lc $_[0]->data_type} || SQL_UNKNOWN_TYPE;
}

=head2 default_value

Get or set the field's default value.  Will return undef if not defined
and could return the empty string (it's a valid default value), so don't
assume an error like other methods.

  my $default = $field->default_value('foo');

=cut

has default_value => ( is => 'rw' );

=head2 extra

Get or set the field's "extra" attibutes (e.g., "ZEROFILL" for MySQL).
Accepts a hash(ref) of name/value pairs to store;  returns a hash.

  $field->extra( qualifier => 'ZEROFILL' );
  my %extra = $field->extra;

=cut

=head2 foreign_key_reference

Get or set the field's foreign key reference;

  my $constraint = $field->foreign_key_reference( $constraint );

=cut

has foreign_key_reference => (
    is => 'rw',
    predicate => '_has_foreign_key_reference',
    isa => schema_obj('Constraint'),
    weak_ref => 1,
);

around foreign_key_reference => sub {
    my $orig = shift;
    my $self = shift;

    if ( my $arg = shift ) {
        return $self->error(
            'Foreign key reference for ', $self->name, 'already defined'
        ) if $self->_has_foreign_key_reference;

        return ex2err($orig, $self, $arg);
    }
    $self->$orig;
};

=head2 is_auto_increment

Get or set the field's C<is_auto_increment> attribute.

  my $is_auto = $field->is_auto_increment(1);

=cut

has is_auto_increment => (
    is => 'rw',
    coerce => quote_sub(q{ $_[0] ? 1 : 0 }),
    builder => 1,
    lazy => 1,
);

sub _build_is_auto_increment {
    my ( $self ) = @_;

    if ( my $table = $self->table ) {
        if ( my $schema = $table->schema ) {
            if (
                $schema->database eq 'PostgreSQL' &&
                $self->data_type eq 'serial'
            ) {
                return 1;
            }
        }
    }
    return 0;
}

=head2 is_foreign_key

Returns whether or not the field is a foreign key.

  my $is_fk = $field->is_foreign_key;

=cut

has is_foreign_key => (
    is => 'rw',
    coerce => quote_sub(q{ $_[0] ? 1 : 0 }),
    builder => 1,
    lazy => 1,
);

sub _build_is_foreign_key {
    my ( $self ) = @_;

    if ( my $table = $self->table ) {
        for my $c ( $table->get_constraints ) {
            if ( $c->type eq FOREIGN_KEY ) {
                my %fields = map { $_, 1 } $c->fields;
                if ( $fields{ $self->name } ) {
                    $self->foreign_key_reference( $c );
                    return 1;
                }
            }
        }
    }
    return 0;
}

=head2 is_nullable

Get or set whether the field can be null.  If not defined, then
returns "1" (assumes the field can be null).  The argument is evaluated
by Perl for True or False, so the following are eqivalent:

  $is_nullable = $field->is_nullable(0);
  $is_nullable = $field->is_nullable('');
  $is_nullable = $field->is_nullable('0');

While this is technically a field constraint, it's probably easier to
represent this as an attribute of the field.  In order keep things
consistent, any other constraint on the field (unique, primary, and
foreign keys; checks) are represented as table constraints.

=cut

has is_nullable => (
    is => 'rw',
    coerce => quote_sub(q{ $_[0] ? 1 : 0 }),
    default => quote_sub(q{ 1 }),
 );

around is_nullable => sub {
    my ($orig, $self, $arg) = @_;

    $self->$orig($self->is_primary_key ? 0 : defined $arg ? $arg : ());
};

=head2 is_primary_key

Get or set the field's C<is_primary_key> attribute.  Does not create
a table constraint (should it?).

  my $is_pk = $field->is_primary_key(1);

=cut

has is_primary_key => (
    is => 'rw',
    coerce => quote_sub(q{ $_[0] ? 1 : 0 }),
    lazy => 1,
    builder => 1,
);

sub _build_is_primary_key {
    my ( $self ) = @_;

    if ( my $table = $self->table ) {
        if ( my $pk = $table->primary_key ) {
            my %fields = map { $_, 1 } $pk->fields;
            return $fields{ $self->name } || 0;
        }
    }
    return 0;
}

=head2 is_unique

Determine whether the field has a UNIQUE constraint or not.

  my $is_unique = $field->is_unique;

=cut

has is_unique => ( is => 'lazy', init_arg => undef );

around is_unique => carp_ro('is_unique');

sub _build_is_unique {
    my ( $self ) = @_;

    if ( my $table = $self->table ) {
        for my $c ( $table->get_constraints ) {
            if ( $c->type eq UNIQUE ) {
                my %fields = map { $_, 1 } $c->fields;
                if ( $fields{ $self->name } ) {
                    return 1;
                }
            }
        }
    }
    return 0;
}

sub is_valid {

=pod

=head2 is_valid

Determine whether the field is valid or not.

  my $ok = $field->is_valid;

=cut

    my $self = shift;
    return $self->error('No name')         unless $self->name;
    return $self->error('No data type')    unless $self->data_type;
    return $self->error('No table object') unless $self->table;
    return 1;
}

=head2 name

Get or set the field's name.

 my $name = $field->name('foo');

The field object will also stringify to its name.

 my $setter_name = "set_$field";

Errors ("No field name") if you try to set a blank name.

=cut

has name => ( is => 'rw', isa => sub { throw( "No field name" ) unless $_[0] } );

around name => sub {
    my $orig = shift;
    my $self = shift;

    if ( my ($arg) = @_ ) {
        if ( my $schema = $self->table ) {
            return $self->error( qq[Can't use field name "$arg": field exists] )
                if $schema->get_field( $arg );
        }
    }

    return ex2err($orig, $self, @_);
};

sub full_name {

=head2 full_name

Read only method to return the fields name with its table name pre-pended.
e.g. "person.foo".

=cut

    my $self = shift;
    return $self->table.".".$self->name;
}

=head2 order

Get or set the field's order.

  my $order = $field->order(3);

=cut

has order => ( is => 'rw', default => quote_sub(q{ 0 }) );

around order => sub {
    my ( $orig, $self, $arg ) = @_;

    if ( defined $arg && $arg =~ /^\d+$/ ) {
        return $self->$orig($arg);
    }

    return $self->$orig;
};

sub schema {

=head2 schema

Shortcut to get the fields schema ($field->table->schema) or undef if it
doesn't have one.

  my $schema = $field->schema;

=cut

    my $self = shift;
    if ( my $table = $self->table ) { return $table->schema || undef; }
    return undef;
}

=head2 size

Get or set the field's size.  Accepts a string, array or arrayref of
numbers and returns a string.

  $field->size( 30 );
  $field->size( [ 255 ] );
  $size = $field->size( 10, 2 );
  print $size; # prints "10,2"

  $size = $field->size( '10, 2' );
  print $size; # prints "10,2"

=cut

has size => (
    is => 'rw',
    default => quote_sub(q{ [0] }),
    coerce => sub {
        my @sizes = grep { defined && m/^\d+(?:\.\d+)?$/ } @{parse_list_arg($_[0])};
        @sizes ? \@sizes : [0];
    },
);

around size => sub {
    my $orig    = shift;
    my $self    = shift;
    my $numbers = parse_list_arg( @_ );

    if ( @$numbers ) {
        my @new;
        for my $num ( @$numbers ) {
            if ( defined $num && $num =~ m/^\d+(?:\.\d+)?$/ ) {
                push @new, $num;
            }
        }
        $self->$orig(\@new) if @new; # only set if all OK
    }

    return wantarray
        ? @{ $self->$orig || [0] }
        : join( ',', @{ $self->$orig || [0] } )
    ;
};

=head2 table

Get or set the field's table object. As the table object stringifies this can
also be used to get the table name.

  my $table = $field->table;
  print "Table name: $table";

=cut

has table => ( is => 'rw', isa => schema_obj('Table'), weak_ref => 1 );

around table => \&ex2err;

=head2

Returns the field exactly as the parser found it

=cut

has parsed_field => ( is => 'rw' );

around parsed_field => sub {
    my $orig = shift;
    my $self = shift;

    return $self->$orig(@_) || $self;
};

=head2 equals

Determines if this field is the same as another

  my $isIdentical = $field1->equals( $field2 );

=cut

around equals => sub {
    my $orig = shift;
    my $self = shift;
    my $other = shift;
    my $case_insensitive = shift;

    return 0 unless $self->$orig($other);
    return 0 unless $case_insensitive ? uc($self->name) eq uc($other->name) : $self->name eq $other->name;

    # Comparing types: use sql_data_type if both are not 0. Else use string data_type
    if ($self->sql_data_type && $other->sql_data_type) {
        return 0 unless $self->sql_data_type == $other->sql_data_type
    } else {
        return 0 unless lc($self->data_type) eq lc($other->data_type)
    }

    return 0 unless $self->size eq $other->size;

    {
        my $lhs = $self->default_value;
           $lhs = \'NULL' unless defined $lhs;
        my $lhs_is_ref = ! ! ref $lhs;

        my $rhs = $other->default_value;
           $rhs = \'NULL' unless defined $rhs;
        my $rhs_is_ref = ! ! ref $rhs;

        # If only one is a ref, fail. -- rjbs, 2008-12-02
        return 0 if $lhs_is_ref xor $rhs_is_ref;

        my $effective_lhs = $lhs_is_ref ? $$lhs : $lhs;
        my $effective_rhs = $rhs_is_ref ? $$rhs : $rhs;

        return 0 if $effective_lhs ne $effective_rhs;
    }

    return 0 unless $self->is_nullable eq $other->is_nullable;
#    return 0 unless $self->is_unique eq $other->is_unique;
    return 0 unless $self->is_primary_key eq $other->is_primary_key;
#    return 0 unless $self->is_foreign_key eq $other->is_foreign_key;
    return 0 unless $self->is_auto_increment eq $other->is_auto_increment;
#    return 0 unless $self->comments eq $other->comments;
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
