package SQL::Translator::Producer;

#-----------------------------------------------------
# $Id: Producer.pm,v 1.1.1.1 2002-03-01 02:26:25 kycl4rk Exp $
#
# File       : SQL/Translator/Producer.pm
# Programmer : Ken Y. Clark, kclark@logsoft.com
# Created    : 2002/02/27
# Purpose    : base object for Producers
#-----------------------------------------------------

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1.1.1 $)[-1];

use SQL::Translator;
use base qw[ SQL::Translator ];

sub from { return shift()->{'from'} }

sub header {
    my $self = shift;
    my $from = $self->from || '';
    my $to   = $self->to   || '';
    return <<"HEADER";
#
# $from-to-$to translator
# Version: $SQL::Translator::VERSION
#

HEADER
}

1;

#-----------------------------------------------------
# A burnt child loves the fire.
# Oscar Wilde
#-----------------------------------------------------

=head1 NAME

SQL::Translator::Producer - base object for Producers

=head1 SYNOPSIS

  package SQL::Translator::Producer::Foo;
  use SQL::Translator::Producer;
  use base( 'SQL::Translator::Producer' );
  1;

=head1 DESCRIPTION

Intended to serve as a base class for all SQL Translator producers.

=head1 AUTHOR

Ken Y. Clark, kclark@logsoft.com

=head1 SEE ALSO

perl(1).

=cut
