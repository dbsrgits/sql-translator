package SQL::Translator::Role::ListAttr;
use strictures 1;
use SQL::Translator::Utils qw(parse_list_arg ex2err);
use List::MoreUtils qw(uniq);
use Sub::Quote qw(quote_sub);

use Package::Variant (
    importing => {
        'Moo::Role' => [],
    },
    subs => [qw(has around)],
);


sub make_variant {
    my ($class, $target_package, $name, %arguments) = @_;

    my $may_throw = delete $arguments{may_throw};
    my $undef_if_empty = delete $arguments{undef_if_empty};
    my $append = delete $arguments{append};
    my $coerce = delete $arguments{uniq}
        ? sub { [ uniq @{parse_list_arg($_[0])} ] }
        : \&parse_list_arg;

    has($name => (
        is => 'rw',
        (!$arguments{builder} ? (
            default => quote_sub(q{ [] }),
        ) : ()),
        coerce => $coerce,
        %arguments,
    ));

    around($name => sub {
        my ($orig, $self) = (shift, shift);
        my $list = parse_list_arg(@_);
        $self->$orig([ @{$append ? $self->$orig : []}, @$list ])
            if @$list;

        my $return;
        if ($may_throw) {
            $return = ex2err($orig, $self) or return;
        }
        else {
            $return = $self->$orig;
        }
        my $scalar_return = !@{$return} && $undef_if_empty ? undef : $return;
        return wantarray ? @{$return} : $scalar_return;
    });
}

1;
