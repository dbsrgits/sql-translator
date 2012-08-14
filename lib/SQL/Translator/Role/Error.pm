package SQL::Translator::Role::Error;
use Moo::Role;

has error => (is => 'rw', default => sub { '' });

around error => sub {
    my ($orig, $self) = (shift, shift);

    # Emulate horrible Class::Base API
    unless (ref ($self)) {
        my $errref = do { no strict 'refs'; \${"${self}::_ERROR"} };
        return $$errref unless @_;
        $$errref = $_[0];
        return undef;
    }

    return $self->$orig unless @_;
    $self->$orig(@_);
    return undef;
};

1;
