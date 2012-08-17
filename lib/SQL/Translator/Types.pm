package SQL::Translator::Types;

=head1 NAME

SQL::Translator::Types - Type checking functions

=head1 SYNOPSIS

    package Foo;
    use Moo;
    use SQL::Translator::Types qw(schema_obj);

    has foo => ( is => 'rw', isa => schema_obj('Trigger') );

=head1 DESCRIPTIONS

This module exports fuctions that return coderefs suitable for L<Moo>
C<isa> type checks.
Errors are reported using L<SQL::Translator::Utils/throw>.

=cut

use strictures 1;

use SQL::Translator::Utils qw(throw);
use Scalar::Util qw(blessed);

use Exporter qw(import);
our @EXPORT_OK = qw(schema_obj);

=head1 FUNCTIONS

=head2 schema_obj($type)

Returns a coderef that checks that its arguments is an object of the
class C<< SQL::Translator::Schema::I<$type> >>.

=cut

sub schema_obj {
    my ($class) = @_;
    my $name = lc $class;
    $class = 'SQL::Translator::Schema' . ($class eq 'Schema' ? '' : "::$class");
    return sub {
        throw("Not a $name object")
            unless blessed($_[0]) and $_[0]->isa($class);
    };
}

1;
