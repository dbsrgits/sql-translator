package SQL::Translator::Parser;

#-----------------------------------------------------
# $Id: Parser.pm,v 1.1.1.1 2002-03-01 02:26:25 kycl4rk Exp $
#
# File       : SQL/Translator/Parser.pm
# Programmer : Ken Y. Clark, kclark@logsoft.com
# Created    : 2002/02/27
# Purpose    : base object for parsers
#-----------------------------------------------------

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1.1.1 $)[-1];

use Parse::RecDescent;
use SQL::Translator;
use base qw[ SQL::Translator ];

sub parse {
#
# Override this method if you intend not to use Parse::RecDescent
#
    my $self = shift;
    return $self->parser->file( shift() );
}

sub parser {
    my $self   = shift;
    unless ( $self->{'parser'} ) {
        $self->{'parser'} = Parse::RecDescent->new( $self->grammar );
    }
    return $self->{'parser'};
}

1;

#-----------------------------------------------------
# Enough! or Too much.
# William Blake
#-----------------------------------------------------

=head1 NAME

SQL::Translator::Parser - base object for parsers

=head1 SYNOPSIS

  package SQL::Translator::Parser::Foo;
  use SQL::Translator::Parser;
  use base( 'SQL::Translator::Parser' );
  1;

=head1 DESCRIPTION

Blah blah blah.

=head1 AUTHOR

Ken Y. Clark, kclark@logsoft.com

=head1 SEE ALSO

perl(1).

=cut
