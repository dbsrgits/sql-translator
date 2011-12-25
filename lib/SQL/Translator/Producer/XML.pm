package SQL::Translator::Producer::XML;

=pod

=head1 NAME

SQL::Translator::Producer::XML - Alias to XML::SQLFairy producer

=head1 DESCRIPTION

Previous versions of SQL::Translator included an XML producer, but the
namespace has since been further subdivided.  Therefore, this module is
now just just an alias to the XML::SQLFairy producer.

=head1 SEE ALSO

SQL::Translator::Producer::XML::SQLFairy.

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut

use strict;
use warnings;
our $DEBUG;
our $VERSION = '1.59';
$DEBUG = 1 unless defined $DEBUG;

use SQL::Translator::Producer::XML::SQLFairy;

*produce = \&SQL::Translator::Producer::XML::SQLFairy::produce;

1;
