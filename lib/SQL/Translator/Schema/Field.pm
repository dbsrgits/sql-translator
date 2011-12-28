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

use strict;
use warnings;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils 'parse_list_arg';

use base 'SQL::Translator::Schema::Object';

our ( $TABLE_COUNT, $VIEW_COUNT );

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

__PACKAGE__->_attributes( qw/
    table name data_type size is_primary_key is_nullable
    is_auto_increment default_value comments is_foreign_key
    is_unique order sql_data_type
/);

=pod

=head2 new

Object constructor.

  my $field = SQL::Translator::Schema::Field->new(
      name  => 'foo',
      table => $table,
  );

=cut

sub comments {

=pod

=head2 comments

Get or set the comments on a field.  May be called several times to
set and it will accumulate the comments.  Called in an array context,
returns each comment individually; called in a scalar context, returns
all the comments joined on newlines.

  $field->comments('foo');
  $field->comments('bar');
  print join( ', ', $field->comments ); # prints "foo, bar"

=cut

    my $self = shift;

    for my $arg ( @_ ) {
        $arg = $arg->[0] if ref $arg;
        push @{ $self->{'comments'} }, $arg if $arg;
    }

    if ( @{ $self->{'comments'} || [] } ) {
        return wantarray
            ? @{ $self->{'comments'} || [] }
            : join( "\n", @{ $self->{'comments'} || [] } );
    }
    else {
        return wantarray ? () : '';
    }
}


sub data_type {

=pod

=head2 data_type

Get or set the field's data type.

  my $data_type = $field->data_type('integer');

=cut

    my $self = shift;
    if (@_) {
      $self->{'data_type'} = $_[0];
      $self->{'sql_data_type'} = $type_mapping{lc $_[0]} || SQL_UNKNOWN_TYPE unless exists $self->{sql_data_type};
    }
    return $self->{'data_type'} || '';
}

sub sql_data_type {

=head2 sql_data_type

Constant from DBI package representing this data type. See L<DBI/DBI Constants>
for more details.

=cut

    my $self = shift;
    $self->{sql_data_type} = shift if @_;
    return $self->{sql_data_type} || 0;

}

sub default_value {

=pod

=head2 default_value

Get or set the field's default value.  Will return undef if not defined
and could return the empty string (it's a valid default value), so don't
assume an error like other methods.

  my $default = $field->default_value('foo');

=cut

    my $self = shift;
    $self->{'default_value'} = shift if @_;
    return $self->{'default_value'};
}

=pod

=head2 extra

Get or set the field's "extra" attibutes (e.g., "ZEROFILL" for MySQL).
Accepts a hash(ref) of name/value pairs to store;  returns a hash.

  $field->extra( qualifier => 'ZEROFILL' );
  my %extra = $field->extra;

=cut

sub foreign_key_reference {

=pod

=head2 foreign_key_reference

Get or set the field's foreign key reference;

  my $constraint = $field->foreign_key_reference( $constraint );

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        my $class = 'SQL::Translator::Schema::Constraint';
        if ( UNIVERSAL::isa( $arg, $class ) ) {
            return $self->error(
                'Foreign key reference for ', $self->name, 'already defined'
            ) if $self->{'foreign_key_reference'};

            $self->{'foreign_key_reference'} = $arg;
        }
        else {
            return $self->error(
                "Argument to foreign_key_reference is not an $class object"
            );
        }
    }

    return $self->{'foreign_key_reference'};
}

sub is_auto_increment {

=pod

=head2 is_auto_increment

Get or set the field's C<is_auto_increment> attribute.

  my $is_auto = $field->is_auto_increment(1);

=cut

    my ( $self, $arg ) = @_;

    if ( defined $arg ) {
        $self->{'is_auto_increment'} = $arg ? 1 : 0;
    }

    unless ( defined $self->{'is_auto_increment'} ) {
        if ( my $table = $self->table ) {
            if ( my $schema = $table->schema ) {
                if (
                    $schema->database eq 'PostgreSQL' &&
                    $self->data_type eq 'serial'
                ) {
                    $self->{'is_auto_increment'} = 1;
                }
            }
        }
    }

    return $self->{'is_auto_increment'} || 0;
}

sub is_foreign_key {

=pod

=head2 is_foreign_key

Returns whether or not the field is a foreign key.

  my $is_fk = $field->is_foreign_key;

=cut

    my ( $self, $arg ) = @_;

    unless ( defined $self->{'is_foreign_key'} ) {
        if ( my $table = $self->table ) {
            for my $c ( $table->get_constraints ) {
                if ( $c->type eq FOREIGN_KEY ) {
                    my %fields = map { $_, 1 } $c->fields;
                    if ( $fields{ $self->name } ) {
                        $self->{'is_foreign_key'} = 1;
                        $self->foreign_key_reference( $c );
                        last;
                    }
                }
            }
        }
    }

    return $self->{'is_foreign_key'} || 0;
}

sub is_nullable {

=pod

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

    my ( $self, $arg ) = @_;

    if ( defined $arg ) {
        $self->{'is_nullable'} = $arg ? 1 : 0;
    }

    if (
        defined $self->{'is_nullable'} &&
        $self->{'is_nullable'} == 1    &&
        $self->is_primary_key
    ) {
        $self->{'is_nullable'} = 0;
    }

    return defined $self->{'is_nullable'} ? $self->{'is_nullable'} : 1;
}

sub is_primary_key {

=pod

=head2 is_primary_key

Get or set the field's C<is_primary_key> attribute.  Does not create
a table constraint (should it?).

  my $is_pk = $field->is_primary_key(1);

=cut

    my ( $self, $arg ) = @_;

    if ( defined $arg ) {
        $self->{'is_primary_key'} = $arg ? 1 : 0;
    }

    unless ( defined $self->{'is_primary_key'} ) {
        if ( my $table = $self->table ) {
            if ( my $pk = $table->primary_key ) {
                my %fields = map { $_, 1 } $pk->fields;
                $self->{'is_primary_key'} = $fields{ $self->name } || 0;
            }
            else {
                $self->{'is_primary_key'} = 0;
            }
        }
    }

    return $self->{'is_primary_key'} || 0;
}

sub is_unique {

=pod

=head2 is_unique

Determine whether the field has a UNIQUE constraint or not.

  my $is_unique = $field->is_unique;

=cut

    my $self = shift;

    unless ( defined $self->{'is_unique'} ) {
        if ( my $table = $self->table ) {
            for my $c ( $table->get_constraints ) {
                if ( $c->type eq UNIQUE ) {
                    my %fields = map { $_, 1 } $c->fields;
                    if ( $fields{ $self->name } ) {
                        $self->{'is_unique'} = 1;
                        last;
                    }
                }
            }
        }
    }

    return $self->{'is_unique'} || 0;
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

sub name {

=pod

=head2 name

Get or set the field's name.

 my $name = $field->name('foo');

The field object will also stringify to its name.

 my $setter_name = "set_$field";

Errors ("No field name") if you try to set a blank name.

=cut

    my $self = shift;

    if ( @_ ) {
        my $arg = shift || return $self->error( "No field name" );
        if ( my $table = $self->table ) {
            return $self->error( qq[Can't use field name "$arg": field exists] )
                if $table->get_field( $arg );
        }

        $self->{'name'} = $arg;
    }

    return $self->{'name'} || '';
}

sub full_name {

=head2 full_name

Read only method to return the fields name with its table name pre-pended.
e.g. "person.foo".

=cut

    my $self = shift;
    return $self->table.".".$self->name;
}

sub order {

=pod

=head2 order

Get or set the field's order.

  my $order = $field->order(3);

=cut

    my ( $self, $arg ) = @_;

    if ( defined $arg && $arg =~ /^\d+$/ ) {
        $self->{'order'} = $arg;
    }

    return $self->{'order'} || 0;
}

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

sub size {

=pod

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

    my $self    = shift;
    my $numbers = parse_list_arg( @_ );

    if ( @$numbers ) {
        my @new;
        for my $num ( @$numbers ) {
            if ( defined $num && $num =~ m/^\d+(?:\.\d+)?$/ ) {
                push @new, $num;
            }
        }
        $self->{'size'} = \@new if @new; # only set if all OK
    }

    return wantarray
        ? @{ $self->{'size'} || [0] }
        : join( ',', @{ $self->{'size'} || [0] } )
    ;
}

sub table {

=pod

=head2 table

Get or set the field's table object. As the table object stringifies this can
also be used to get the table name.

  my $table = $field->table;
  print "Table name: $table";

=cut

    my $self = shift;
    if ( my $arg = shift ) {
        return $self->error('Not a table object') unless
            UNIVERSAL::isa( $arg, 'SQL::Translator::Schema::Table' );
        $self->{'table'} = $arg;
    }

    return $self->{'table'};
}

sub parsed_field {

=head2

Returns the field exactly as the parser found it

=cut

    my $self = shift;

    if (@_) {
      my $value = shift;
      $self->{parsed_field} = $value;
      return $value || $self;
    }
    return $self->{parsed_field} || $self;
}

sub equals {

=pod

=head2 equals

Determines if this field is the same as another

  my $isIdentical = $field1->equals( $field2 );

=cut

    my $self = shift;
    my $other = shift;
    my $case_insensitive = shift;

    return 0 unless $self->SUPER::equals($other);
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
}

sub DESTROY {
#
# Destroy cyclical references.
#
    my $self = shift;
    undef $self->{'table'};
    undef $self->{'foreign_key_reference'};
}

1;

=pod

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut
