package SQL::Translator::Schema::Role::Compare;
use Moo::Role;

sub equals {

=pod

=head2 equals

Determines if this object is the same as another.

  my $isIdentical = $object1->equals( $object2 );

=cut

    my $self = shift;
    my $other = shift;

    return 0 unless $other;
    return 1 if overload::StrVal($self) eq overload::StrVal($other);
    return 0 unless $other->isa( ref($self) );
    return 1;
}

sub _compare_objects {
#   my ($self, $obj1, $obj2) = @_;

   my $result = (
      Data::Dumper->new([$_[1]])->Terse(1)->Indent(0)->Deparse(1)->Sortkeys(1)->Maxdepth(0)->Dump
        eq
      Data::Dumper->new([$_[2]])->Terse(1)->Indent(0)->Deparse(1)->Sortkeys(1)->Maxdepth(0)->Dump
   );
#  if ( !$result ) {
#     use Carp qw(cluck);
#     cluck("How did I get here?");
#     use Data::Dumper;
#     $Data::Dumper::Maxdepth = 1;
#     print "obj1: ", Dumper($obj1), "\n";
#     print "obj2: ", Dumper($obj2), "\n";
#  }
   return $result;
}

1;
