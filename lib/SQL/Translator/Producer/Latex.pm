package SQL::Translator::Producer::Latex;

=pod

=head1 NAME

SQL::Translator::Producer::Latex -
    Produces latex formatted tables ready for import from schema.

=head1 SYNOPSIS

  use SQL::Translator;
  my $translator     = SQL::Translator->new(
      from           => 'MySQL',
      filename       => 'foo_schema.sql',
      to             => 'Latex',
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

our @EXPORT_OK;
our $VERSION = '1.66';

use SQL::Translator::Utils 'debug';

sub produce {
  my $translator = shift;
  my $schema     = $translator->schema;
  my $o          = '';
  for my $table ($schema->get_tables) {
    my $table_name = $table->name or next;
    my $n          = latex($table_name);
    $o .= sprintf '
\subsubsection{%s}
%s
\begin{table}[htb]
\caption{%s}
\label{tab:%s}
\center
{ \small
  \begin{tabular}{l l p{8cm}}
  Column & Datatype & Description \\\\ \hline
', $n, latex($table->comments), $n, $table_name;

    foreach my $f ($table->get_fields) {
      $o .= sprintf '%s & %s & %s \\\\', map { latex($_) } ($f->name, $f->data_type, $f->comments || '');
      $o .= "\n";

    }
    $o .= sprintf '
\end{tabular}
}
\end{table}
\clearpage
';
  }
  return $o;
}

sub latex {
  my $s = shift;
  return '' unless defined $s;
  $s =~ s/([\&\_\$\{\#])/\\$1/g;
  return $s;
}

1;

=pod

=head1 AUTHOR

Chris Mungall

=head1 SEE ALSO

SQL::Translator.

=cut
