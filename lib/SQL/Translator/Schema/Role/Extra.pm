package SQL::Translator::Schema::Role::Extra;

=head1 NAME

SQL::Translator::Schema::Role::Extra - "extra" attribute for schema classes

=head1 SYNOPSIS

    package Foo;
    use Moo;
    with qw(SQL::Translator::Schema::Role::Extra);

=head1 DESCRIPTION

This role provides methods to set and get a hashref of extra attributes
for schema objects.

=cut

use Moo::Role;
use Sub::Quote qw(quote_sub);


=head1 METHODS

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

has extra => ( is => 'rwp', default => quote_sub(q{ +{} }) );

around extra => sub {
    my ($orig, $self) = (shift, shift);

    @_ = %{$_[0]} if ref $_[0] eq "HASH";
    my $extra = $self->$orig;

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
};

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

sub remove_extra {
    my ( $self, @keys ) = @_;
    unless (@keys) {
        $self->_set_extra({});
    }
    else {
        delete @{$self->extra}{@keys};
    }
}

1;
