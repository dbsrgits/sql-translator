package SQL::Translator::Schema::Role::Error;
use Moo::Role;

has error => (is => 'rw', default => sub { '' });

around error => sub {
    my ($orig, $self) = (shift, shift);

    return $self->$orig unless @_;
    $self->$orig(ref($_[0]) ? $_[0] : join('', @_));
    return undef;
};

1;
