package SQL::Translator::Producer::XML;

#-----------------------------------------------------
# $Id: XML.pm,v 1.2 2002-03-21 18:50:53 dlc Exp $
#
# File       : SQL/Translator/Producer/XML.pm
# Programmer : Ken Y. Clark, kclark@logsoft.com
# Created    : 2002/02/27
# Purpose    : XML output
#-----------------------------------------------------

use strict;
use vars qw( $VERSION );
$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;

use XML::Dumper;

sub produce {
    my ( $self, $data ) = @_;
    my $dumper = XML::Dumper->new;
    return $dumper->pl2xml( $data );
}

1;
#-----------------------------------------------------
# The eyes of fire, the nostrils of air,
# The mouth of water, the beard of earth.
# William Blake
#-----------------------------------------------------
__END__


=head1 NAME

SQL::Translator::Producer::XML - XML output

=head1 SYNOPSIS

  use SQL::Translator::Producer::XML;

=head1 DESCRIPTION

Blah blah blah.

=head1 AUTHOR

Ken Y. Clark, kclark@logsoft.com

=head1 SEE ALSO

perl(1).

=cut
