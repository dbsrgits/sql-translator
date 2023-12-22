package SQL::Translator::Schema::IndexField;

=pod

=head1 NAME

SQL::Translator::Schema::IndexField - SQL::Translator index field object

=head1 DESCRIPTION

C<SQL::Translator::Schema::IndexField> is the index field object.

Different databases allow for different options on index fields. Those are supported through here

=head1 METHODS

=cut

use Moo;

extends 'SQL::Translator::Schema::Object';

use overload '""' => sub { shift->name };

=head2 new

Object constructor.

  my $schema = SQL::Translator::Schema::IndexField->new;

=head2 name

The name of the index. The object stringifies to this. In addition, you can simply pass
a string to the constructor to only set this attribute.

=head2 extra

All options for the field are stored under the extra hash. The constructor will collect
them for you if passed in straight. In addition, an accessor is provided for all supported options

Currently supported options:

=over 4

=item prefix_length

Supported by MySQL. Indicates that only N characters of the column are indexed.

=back

=cut

around BUILDARGS => sub {
  my ($orig, $self, @args) = @_;
  if (@args == 1 && !ref $args[0]) {
    @args = (name => $args[0]);
  }

# there are some weird pathological cases where we get an object passed in rather than a
# hashref. We'll just clone it
  if (ref $args[0] eq $self) {
    return { %{ $args[0] } };
  }
  my $args  = $self->$orig(@args);
  my $extra = delete $args->{extra} || {};
  my $name  = delete $args->{name};
  return {
    name  => $name,
    extra => { %$extra, %$args }
  };
};

has name => (
  is       => 'rw',
  required => 1,
);

has extra => (
  is      => 'rw',
  default => sub { {} },
);

=pod

=head1 AUTHOR

Veesh Goldman E<lt>veesh@cpan.orgE<gt>.

=cut

9007
