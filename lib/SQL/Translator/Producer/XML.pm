package SQL::Translator::Producer::XML;

#-----------------------------------------------------
# $Id: XML.pm,v 1.1.1.1 2002-03-01 02:26:25 kycl4rk Exp $
#
# File       : SQL/Translator/Producer/XML.pm
# Programmer : Ken Y. Clark, kclark@logsoft.com
# Created    : 2002/02/27
# Purpose    : XML output
#-----------------------------------------------------

use strict;
use SQL::Translator::Producer;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1.1.1 $)[-1];

use XML::Dumper;

use base qw[ SQL::Translator::Producer ];

sub to { 'XML' }

sub translate {
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
