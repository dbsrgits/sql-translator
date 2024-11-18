package SQL::Translator::Filter::DefaultExtra;

=head1 NAME

SQL::Translator::Filter::DefaultExtra - Set default extra data values for schema
objects.

=head1 SYNOPSIS

  use SQL::Translator;

  my $sqlt = SQL::Translator->new(
      from => 'MySQL',
      to   => 'MySQL',
      filters => [
        DefaultExtra => {
            # XXX - These should really be ordered

            # Default widget for fields to basic text edit.
            'field.widget' => 'text',
            # idea:
            'field(data_type=BIT).widget' => 'yesno',

            # Default label (human formated name) for fields and tables
            'field.label'  => '=ucfirst($name)',
            'table.label'  => '=ucfirst($name)',
        },
      ],
  ) || die "SQLFairy error : ".SQL::Translator->error;
  my $sql = $sqlt->translate || die "SQLFairy error : ".$sqlt->error;

=cut

use strict;
use warnings;
our $VERSION = '1.66';

sub filter {
  my $schema = shift;
  my %args   = { +shift };

  # Tables
  foreach ($schema->get_tables) {
    my %extra = $_->extra;

    $extra{label} ||= ucfirst($_->name);
    $_->extra(%extra);
  }

  # Fields
  foreach (map { $_->get_fields } $schema->get_tables) {
    my %extra = $_->extra;

    $extra{label} ||= ucfirst($_->name);
    $_->extra(%extra);
  }
}

1;

__END__

=head1 DESCRIPTION

Maybe I'm trying to do too much in one go. Args set a match and then an update,
if you want to set lots of things, use lots of filters!

=head1 SEE ALSO

C<perl(1)>, L<SQL::Translator>

=cut
