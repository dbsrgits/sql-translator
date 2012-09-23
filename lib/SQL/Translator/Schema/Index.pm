package SQL::Translator::Schema::Index;

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

Primary and unique keys are table constraints, not indices.

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

my %VALID_INDEX_TYPE = (
  UNIQUE         => 1,
  NORMAL         => 1,
  FULLTEXT       => 1, # MySQL only (?)
  FULL_TEXT      => 1, # MySQL only (?)
  SPATIAL        => 1, # MySQL only (?)
);

=head2 new

Object constructor.

  my $schema = SQL::Translator::Schema::Index->new;

=head2 fields

Gets and set the fields the index is on.  Accepts a string, list or
arrayref; returns an array or array reference.  Will unique the field
names and keep them in order by the first occurrence of a field name.

  $index->fields('id');
  $index->fields('id', 'name');
  $index->fields( 'id, name' );
  $index->fields( [ 'id', 'name' ] );
  $index->fields( qw[ id name ] );

  my @fields = $index->fields;

=cut

with ListAttr fields => ( uniq => 1 );

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

=head2 name

Get or set the index's name.

  my $name = $index->name('foo');

=cut

has name => (
    is => 'rw',
    coerce => quote_sub(q{ defined $_[0] ? $_[0] : '' }),
    default => quote_sub(q{ '' }),
);

=head2 options

Get or set the index's options (e.g., "using" or "where" for PG).  Returns
an array or array reference.

  my @options = $index->options;

=cut

with ListAttr options => ();

=head2 table

Get or set the index's table object.

  my $table = $index->table;

=cut

has table => ( is => 'rw', isa => schema_obj('Table'), weak_ref => 1 );

around table => \&ex2err;

=head2 type

Get or set the index's type.

  my $type = $index->type('unique');

Get or set the index's type.

Currently there are only four acceptable types: UNIQUE, NORMAL, FULL_TEXT,
and SPATIAL. The latter two might be MySQL-specific. While both lowercase
and uppercase types are acceptable input, this method returns the type in
uppercase.

=cut

has type => (
    is => 'rw',
    coerce => quote_sub(q{ uc $_[0] }),
    default => quote_sub(q{ 'NORMAL' }),
    isa => enum([keys %VALID_INDEX_TYPE], {
        msg => "Invalid index type: %s", allow_false => 1,
    }),
);

around type => \&ex2err;

=head2 equals

Determines if this index is the same as another

  my $isIdentical = $index1->equals( $index2 );

=cut

around equals => sub {
    my $orig = shift;
    my $self = shift;
    my $other = shift;
    my $case_insensitive = shift;
    my $ignore_index_names = shift;

    return 0 unless $self->$orig($other);

    unless ($ignore_index_names) {
      unless ((!$self->name && ($other->name eq $other->fields->[0])) ||
        (!$other->name && ($self->name eq $self->fields->[0]))) {
        return 0 unless $case_insensitive ? uc($self->name) eq uc($other->name) : $self->name eq $other->name;
      }
    }
    #return 0 unless $self->is_valid eq $other->is_valid;
    return 0 unless $self->type eq $other->type;

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
