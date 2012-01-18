package SQL::Translator::Schema::Object;

=pod

=head1 NAME

SQL::Translator::Schema::Object - Base class SQL::Translator Schema objects.

=head1 SYNOPSIS

=head1 DESCSIPTION

Base class for Schema objects. Sub classes L<Class::Base> and adds the following
extra functionality.

=cut

use strict;
use warnings;
use base 'Class::Data::Inheritable';
use base 'Class::Base';
use Data::Dumper ();

our $VERSION = '1.59';

=head1 Construction

Derived classes should declare their attributes using the C<_attributes>
method. They can then inherit the C<init> method from here which will call
accessors of the same name for any values given in the hash passed to C<new>.
Note that you will have to impliment the accessors your self and we expect perl
style methods; call with no args to get and with arg to set.

e.g. If we setup our class as follows;

 package SQL::Translator::Schema::Table;
 use base qw/SQL::Translator::Schema::Object/;

 __PACKAGE__->_attributes( qw/schema name/ );

 sub name   { ... }
 sub schema { ... }

Then we can construct it with

 my $table  =  SQL::Translator::Schema::Table->new(
     schema => $schema,
     name   => 'foo',
 );

and init will call C<< $table->name("foo") >> and C<< $table->schema($schema) >>
to set it up. Any undefined args will be ignored.

Multiple calls to C<_attributes> are cumulative and sub classes will inherit
their parents attribute names.

This is currently experimental, but will hopefull go on to form an introspection
API for the Schema objects.

=cut


__PACKAGE__->mk_classdata("__attributes");

# Define any global attributes here
__PACKAGE__->__attributes([qw/extra/]);

# Set the classes attribute names. Multiple calls are cumulative.
# We need to be careful to create a new ref so that all classes don't end up
# with the same ref and hence the same attributes!
sub _attributes {
    my $class = shift;
    if (@_) { $class->__attributes( [ @{$class->__attributes}, @_ ] ); }
    return @{$class->__attributes};
}

# Call accessors for any args in hashref passed
sub init {
    my ( $self, $config ) = @_;

    for my $arg ( $self->_attributes ) {
        next unless defined $config->{$arg};
        defined $self->$arg( $config->{$arg} ) or return;
    }

    return $self;
}

sub extra {

=pod

=head1 Global Attributes

The following attributes are defined here, therefore all schema objects will
have them.

=head2 extra

Get or set the objects "extra" attibutes (e.g., "ZEROFILL" for MySQL fields).
Call with no args to get all the extra data.
Call with a single name arg to get the value of the named extra attribute,
returned as a scalar. Call with a hash or hashref to set extra attributes.
Returns a hash or a hashref.

  $field->extra( qualifier => 'ZEROFILL' );

  $qualifier = $field->extra('qualifier');

  %extra = $field->extra;
  $extra = $field->extra;

=cut

    my $self = shift;
    @_ = %{$_[0]} if ref $_[0] eq "HASH";
    my $extra = $self->{'extra'} ||= {};

    if (@_==1) {
        return exists($extra->{$_[0]}) ? $extra->{$_[0]} : undef ;
    }
    elsif (@_) {
        my %args = @_;
        while ( my ( $key, $value ) = each %args ) {
            $extra->{$key} = $value;
        }
    }

    return wantarray ? %$extra : $extra;
}

sub remove_extra {

=head2 remove_extra

L</extra> can only be used to get or set "extra" attributes but not to
remove some. Call with no args to remove all extra attributes that
have been set before. Call with a list of key names to remove
certain extra attributes only.

  # remove all extra attributes
  $field->remove_extra();

  # remove timezone and locale attributes only
  $field->remove_extra(qw/timezone locale/);

=cut

    my ( $self, @keys ) = @_;
    unless (@keys) {
        $self->{'extra'} = {};
    }
    else {
        delete $self->{'extra'}{$_} for @keys;
    }
}

sub equals {

=pod

=head2 equals

Determines if this object is the same as another.

  my $isIdentical = $object1->equals( $object2 );

=cut

    my $self = shift;
    my $other = shift;

    return 0 unless $other;
    return 1 if overload::StrVal($self) eq overload::StrVal($other);
    return 0 unless $other->isa( __PACKAGE__ );
    return 1;
}

sub _compare_objects {
#   my ($self, $obj1, $obj2) = @_;

   my $result = (
      Data::Dumper->new([$_[1]])->Terse(1)->Indent(0)->Deparse(1)->Sortkeys(1)->Maxdepth(0)->Dump
        eq
      Data::Dumper->new([$_[2]])->Terse(1)->Indent(0)->Deparse(1)->Sortkeys(1)->Maxdepth(0)->Dump
   );
#  if ( !$result ) {
#     use Carp qw(cluck);
#     cluck("How did I get here?");
#     use Data::Dumper;
#     $Data::Dumper::Maxdepth = 1;
#     print "obj1: ", Dumper($obj1), "\n";
#     print "obj2: ", Dumper($obj2), "\n";
#  }
   return $result;
}

1;

=pod

=head1 SEE ALSO

=head1 TODO

=head1 BUGS

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>,
Mark Addison E<lt>mark.addison@itn.co.ukE<gt>.

=cut
