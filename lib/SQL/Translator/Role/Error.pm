package SQL::Translator::Role::Error;
use Moo::Role;
use Sub::Quote qw(quote_sub);

has _ERROR => (
    is => 'rw',
    accessor => 'error',
    init_arg => undef,
    default => quote_sub(q{ '' }),
);

around error => sub {
    my ($orig, $self) = (shift, shift);

    # Emulate horrible Class::Base API
    unless (ref($self)) {
        my $errref = do { no strict 'refs'; \${"${self}::ERROR"} };
        return $$errref unless @_;
        $$errref = $_[0];
        return undef;
    }

    return $self->$orig unless @_;
    $self->$orig(@_);
    return undef;
};

1;
