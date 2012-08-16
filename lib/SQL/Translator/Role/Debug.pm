package SQL::Translator::Role::Debug;
use Moo::Role;
use Sub::Quote qw(quote_sub);

has _DEBUG => (
    is => 'rw',
    accessor => 'debugging',
    init_arg => 'debugging',
    coerce => quote_sub(q{ $_[0] ? 1 : 0 }),
    lazy => 1,
    builder => 1,
);

sub _build__DEBUG {
    my ($self) = @_;
    my $class = ref $self;
    no strict 'refs';
    return ${"${class}::DEBUG"};
}

around debugging => sub {
    my ($orig, $self) = (shift, shift);

    # Emulate horrible Class::Base API
    unless (ref $self) {
        my $dbgref = do { no strict 'refs'; \${"${self}::DEBUG"} };
        $$dbgref = $_[0] if @_;
        return $$dbgref;
    }
    return $self->$orig(@_);
};

sub debug {
    my $self = shift;

    return unless $self->debugging;

    print STDERR '[', (ref $self || $self), '] ', @_, "\n";
}

1;
