package SQL::Translator::Schema::Graph::Edge;

use strict;

use vars qw[ $VERSION ];
$VERSION = '1.60';

use Class::MakeMethods::Template::Hash (
    new    => ['new'],
    scalar => [qw( type )],
    array  => [qw( traversals )],
    object => [
        'thisfield' => { class => 'SQL::Translator::Schema::Field' },    #FIXME
        'thatfield' => { class => 'SQL::Translator::Schema::Field' },    #FIXME
        'thisnode'  => { class => 'SQL::Translator::Schema::Graph::Node' },
        'thatnode'  => { class => 'SQL::Translator::Schema::Graph::Node' },

    ],
);

sub flip {
    my $self = shift;

    return SQL::Translator::Schema::Graph::Edge->new(
        thisfield => $self->thatfield,
        thatfield => $self->thisfield,
        thisnode  => $self->thatnode,
        thatnode  => $self->thisnode,
        type      => $self->type eq 'import' ? 'export' : 'import'
    );
}

1;
