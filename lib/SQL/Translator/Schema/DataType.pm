package SQL::Translator::Schema::DataType;

=pod

=head1 NAME

SQL::Translator::Schema::DataType - SQL::Translator data type object

=head1 SYNOPSIS

  use SQL::Translator::Schema::DataType;
  my $data_type = SQL::Translator::Schema::DataType->new(
      data_type  => 'integer',
      size => 20,
  );

=head1 DESCRIPTION

C<SQL::Translator::Schema::DataType> is used in situations
where a data type is required as part of an other object,
e.g. in C<SQL::Translator::Schema::Sequence>.
Data type is its own object because some data types
consist of several defining elements, for instance,
character and length, numeric and decimal precision
or timestamp with or without timezone.
Data type has to be expressed precisely so that it can be
interpreted differently for each database.
There are differences, for instance, in what is the size
of "bigint" or "long".
Some databases, for example, Oracle, do not support defining
the data type for sequences.


=head1 METHODS

=cut

use Moo;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Types qw(schema_obj);
use SQL::Translator::Utils qw(parse_list_arg ex2err throw carp_ro);
use Sub::Quote             qw(quote_sub);
use Scalar::Util           ();

extends 'SQL::Translator::Schema::Object';

our $VERSION = '1.66';

# Stringify to our name, being careful not to pass any args through so we don't
# accidentally set it to undef. We also have to tweak bool so the object is
# still true when it doesn't have a name (which shouldn't happen!).
use overload
    '""'     => sub { shift->name },
    'bool'   => sub { $_[0]->name || $_[0] },
    fallback => 1,
    ;

use DBI qw(:sql_types);

# Mapping from string to sql constant
our %type_mapping = (
  integer => SQL_INTEGER,
  int     => SQL_INTEGER,

  tinyint  => SQL_TINYINT,
  smallint => SQL_SMALLINT,
  bigint   => SQL_BIGINT,

  double             => SQL_DOUBLE,
  'double precision' => SQL_DOUBLE,

  decimal => SQL_DECIMAL,
  dec     => SQL_DECIMAL,
  numeric => SQL_NUMERIC,

  real  => SQL_REAL,
  float => SQL_FLOAT,

  bit => SQL_BIT,

  date      => SQL_DATE,
  datetime  => SQL_DATETIME,
  timestamp => SQL_TIMESTAMP,
  time      => SQL_TIME,

  char      => SQL_CHAR,
  varchar   => SQL_VARCHAR,
  binary    => SQL_BINARY,
  varbinary => SQL_VARBINARY,
  tinyblob  => SQL_BLOB,
  blob      => SQL_BLOB,
  text      => SQL_LONGVARCHAR,

);

has _numeric_sql_data_types => (is => 'lazy');

sub _build__numeric_sql_data_types {
  return {
    map { $_ => 1 } (
      SQL_INTEGER, SQL_TINYINT, SQL_SMALLINT, SQL_BIGINT, SQL_DOUBLE, SQL_NUMERIC, SQL_DECIMAL, SQL_FLOAT, SQL_REAL
    )
  };
}

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
  is      => 'rw',
  coerce  => quote_sub(q{ ref($_[0]) eq 'ARRAY' ? $_[0] : [$_[0]] }),
  default => quote_sub(q{ [] }),
);

around comments => sub {
  my $orig = shift;
  my $self = shift;

  for my $arg (@_) {
    $arg = $arg->[0] if ref $arg;
    push @{ $self->$orig }, $arg if $arg;
  }

  return wantarray
      ? @{ $self->$orig }
      : join "\n", @{ $self->$orig };
};

=head2 type

Get or set the field's data type.

  my $data_type = $field->type('integer');

=cut

has type => (is => 'rw');

=head2 sql_data_type

Constant from DBI package representing this data type. See L<DBI/DBI Constants>
for more details.

=cut

has sql_data_type => (is => 'rw', lazy => 1, builder => 1);

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

has name => (is => 'rw', isa => sub { throw("No field name") unless $_[0] });

around name => sub {
  my $orig = shift;
  my $self = shift;

  if (my ($arg) = @_) {
    if (my $schema = $self->table) {
      return $self->error(qq[Can't use field name "$arg": field exists])
          if $schema->get_field($arg);
    }
  }

  return ex2err($orig, $self, @_);
};

=head2 order

Get or set the field's order.

  my $order = $field->order(3);

=cut

has order => (is => 'rw', default => quote_sub(q{ 0 }));

around order => sub {
  my ($orig, $self, $arg) = @_;

  if (defined $arg && $arg =~ /^\d+$/msx) {
    return $self->$orig($arg);
  }

  return $self->$orig;
};

=head2 size

Get or set the field's size.  Accepts a string, array or arrayref of
numbers and returns a string.

  $field->size( 30 );

=cut

has size => (
  is      => 'rw',
  default => quote_sub(q{ 0 }),
);

=head2 equals

Determines if this field is the same as another

  my $isIdentical = $field1->equals( $field2 );

=cut

around equals => sub {
  my $orig             = shift;
  my $self             = shift;
  my $other            = shift;
  my $case_insensitive = shift;

  return 0 unless $self->$orig($other);
  return 0
      unless $case_insensitive
      ? uc($self->name) eq uc($other->name)
      : $self->name eq $other->name;

# Comparing types: use sql_data_type if both are not 0. Else use string data_type
  if ($self->sql_data_type && $other->sql_data_type) {
    return 0 unless $self->sql_data_type == $other->sql_data_type;
  } else {
    return 0 unless lc($self->data_type) eq lc($other->data_type);
  }

  return 0 unless $self->size eq $other->size;

  {
    my $lhs = $self->default_value;
    $lhs = \'NULL' unless defined $lhs;
    my $lhs_is_ref = !!ref $lhs;

    my $rhs = $other->default_value;
    $rhs = \'NULL' unless defined $rhs;
    my $rhs_is_ref = !!ref $rhs;

    # If only one is a ref, fail. -- rjbs, 2008-12-02
    return 0 if $lhs_is_ref xor $rhs_is_ref;

    my $effective_lhs = $lhs_is_ref ? ${$lhs} : $lhs;
    my $effective_rhs = $rhs_is_ref ? ${$rhs} : $rhs;

    if ( $self->_is_numeric_data_type
      && Scalar::Util::looks_like_number($effective_lhs)
      && Scalar::Util::looks_like_number($effective_rhs)) {
      return 0 if ($effective_lhs + 0) != ($effective_rhs + 0);
    } else {
      return 0 if $effective_lhs ne $effective_rhs;
    }
  }

  return 0 unless $self->is_nullable eq $other->is_nullable;
  return 0 unless $self->is_primary_key eq $other->is_primary_key;
  return 0 unless $self->is_auto_increment eq $other->is_auto_increment;
  return 0 unless $self->_compare_objects(scalar $self->extra, scalar $other->extra);
  return 1;
};

# Must come after all 'has' declarations
around new => \&ex2err;

sub _is_numeric_data_type {
  my $self = shift;
  return $self->_numeric_sql_data_types->{ $self->sql_data_type };
}

1;

=pod

=head1 AUTHOR

Mikko Koivunalho E<lt>mikkoi@cpan.orgE<gt>.

=cut
