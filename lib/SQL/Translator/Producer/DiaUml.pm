package SQL::Translator::Producer::DiaUml;

=pod

=head1 NAME

SQL::Translator::Producer::DiaUml -
    Produces dia UML diagrams from schema.

=head1 SYNOPSIS

  use SQL::Translator;
  my $translator     = SQL::Translator->new(
      from           => 'MySQL',
      filename       => 'foo_schema.sql',
      to             => 'DiaUml',
  );
  print $translator->translate;

=head1 DESCRIPTION

Currently you will get one class (with the a table
stereotype) generated per table in the schema. The fields are added as
attributes of the classes and their datatypes set. It doesn't currently set any
of the relationships. It doesn't do any layout, all the classes are in one big
stack. However it is still useful as you can use the layout tools in Dia to
automatically arrange them horizontally or vertically.

=head2 Producer Args

=cut

use strict;
use warnings;

our ($DEBUG, @EXPORT_OK);
our $VERSION = '1.66';
$DEBUG = 0 unless defined $DEBUG;

use File::ShareDir qw/dist_dir/;

use SQL::Translator::Utils 'debug';
use base qw/SQL::Translator::Producer::TT::Base/;

# Convert produce call into a method call on our class
sub produce { return __PACKAGE__->new(translator => shift)->run; }

sub tt_config {
  (INCLUDE_PATH => File::Spec->catdir(dist_dir('SQL-Translator'), 'DiaUml'));
}

sub tt_schema {'schema.tt2'}

1;

=pod

=head1 AUTHOR

Mark Addison E<lt>grommit@users.sourceforge.netE<gt>.

=head1 TODO

* Add the foreign keys from the schema as UML relations.

* Layout the classes.

=head1 SEE ALSO

SQL::Translator.

=cut
