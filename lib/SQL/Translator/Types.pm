package SQL::Translator::Types;
use strictures 1;

use SQL::Translator::Utils qw(throw);
use Scalar::Util qw(blessed);

use Exporter qw(import);
our @EXPORT_OK = qw(schema_obj);

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
