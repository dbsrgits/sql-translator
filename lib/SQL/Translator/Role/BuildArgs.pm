package SQL::Translator::Role::BuildArgs;
use Moo::Role;

around BUILDARGS => sub {
    my $orig = shift;
    my $self = shift;
    my $args = $self->$orig(@_);

    foreach my $arg (keys %{$args}) {
        delete $args->{$arg} unless defined($args->{$arg});
    }
    return $args;
};

1;
