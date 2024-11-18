package SQL::Translator::Parser::XML;

=pod

=head1 NAME

SQL::Translator::Parser::XML - Alias to XML::SQLFairy parser

=head1 DESCRIPTION

This module is an alias to the XML::SQLFairy parser.

=head1 SEE ALSO

SQL::Translator::Parser::XML::SQLFairy.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=cut

use strict;
use warnings;
our $DEBUG;
our $VERSION = '1.66';
$DEBUG = 1 unless defined $DEBUG;

use SQL::Translator::Parser::XML::SQLFairy;

*parse = \&SQL::Translator::Parser::XML::SQLFairy::parse;

1;
