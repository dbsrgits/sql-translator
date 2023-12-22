package SQL::Translator::Generator::DDL::PostgreSQL;

=head1 NAME

SQL::Translator::Generator::DDL::PostgreSQL - A Moo based PostgreSQL DDL generation
engine.

=head1 DESCRIPTION

I<documentation volunteers needed>

=cut

use Moo;

has quote_chars => (
  is      => 'rw',
  default => sub { +[qw(" ")] },
  trigger => sub { $_[0]->clear_escape_char },
);

with 'SQL::Translator::Generator::Role::Quote';

sub name_sep {q(.)}

1;

=head1 AUTHORS

See the included AUTHORS file:
L<http://search.cpan.org/dist/SQL-Translator/AUTHORS>

=head1 COPYRIGHT

Copyright (c) 2012 the SQL::Translator L</AUTHORS> as listed above.

=head1 LICENSE

This code is free software and may be distributed under the same terms as Perl
itself.

=cut
