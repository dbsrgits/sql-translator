package SQL::Translator;

#-----------------------------------------------------
# $Id: Translator.pm,v 1.3 2002-03-07 14:11:40 dlc Exp $
#
# File       : SQL/Translator.pm
# Programmer : Ken Y. Clark, kclark@logsoft.com
# Created    : 2002/02/27
# Purpose    : convert schema from one database to another
#-----------------------------------------------------

use strict;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.3 $)[-1];

use Data::Dumper;

use SQL::Translator::Parser::MySQL;
use SQL::Translator::Parser::Sybase;
use SQL::Translator::Producer::Oracle;
use SQL::Translator::Producer::XML;

#
# These are the inputs we can parse.
#
my %parsers = (
    mysql    => 'MySQL',
    sybase   => 'Sybase',
);

#
# These are the formats we can produce.
#
my %producers = (
    oracle    => 'Oracle',
    xml       => 'XML',
);

#-----------------------------------------------------
sub new {
#
# Makes a new object.  Intentionally made very bare as 
# it is used by all subclasses (unless they override, 
# of course).
#
    my $class = shift;
    my %args  = @_;
    my $self  = { %args };
    return bless $self, $class;
}

#-----------------------------------------------------
sub error {
#
# Return the last error.
#
    return shift()->{'error'} || '';
}

#-----------------------------------------------------
sub error_out {
#
# Record the error and return undef.
#
    my $self = shift;
    if ( my $error = shift ) {
        $self->{'error'} = $error;
    }
    return;
}

#-----------------------------------------------------
sub translate {
#
# Translates any number of given files.
#
    my ( $self, %args ) = @_;
    my $from            = $args{'from'}        || '';
    my $to              = $args{'to'}          || '';
    my $input           = $args{'input'}       || [];
    my $verbose         = $args{'verbose'}     ||  0;
    my $no_comments     = $args{'no_comments'} ||  0;

    if ( exists $parsers{ $from } ) {
        $self->{'from'} = $from;
        warn "Using parser '$from.'\n" if $verbose;
    }
    else {
        my $msg = "The parsers '$from' is not valid.\n" .
                  "Please choose from the following list:\n";
        $msg .= "  $_\n" for sort keys %parsers;
        return $self->error_out( $msg );
    }

    if ( exists $producers{ $to } ) {
        $self->{'to'} = $to;
        warn "Using producer '$to.'\n" if $verbose;
    }
    else {
        my $msg = "The producer '$to' is not valid.\n" .
                  "Please choose from the following list:\n";
        $msg .= "  $_\n" for sort keys %producers;
        return $self->error_out( $msg );
    }

    #
    # Slurp the entire text file we're parsing.
    #
    my $parser   = $self->parser;
    my $producer = $self->producer;
    my $data;
    for my $file ( @$input ) {
        warn "Parsing file '$file.'\n" if $verbose;
        open my $fh, $file or return $self->error_out( "Can't read $file: $!" );
        local $/;
        $data = $parser->parse( <$fh> );
    }

    warn "Data =\n", Dumper( $data ) if $verbose;
    my $output = $producer->translate( $data );
}

#-----------------------------------------------------
sub parser {
#
# Figures out which module to load based on the "from" argument
#
    my $self = shift;
    unless ( $self->{'parser'} ) {
        my $parser_module = 
            'SQL::Translator::Parser::'.$parsers{ $self->{'from'} };
        $self->{'parser'} = $parser_module->new;
    }
    return $self->{'parser'};
}

#-----------------------------------------------------
sub producer {
#
# Figures out which module to load based on the "to" argument
#
    my $self = shift;
    unless ( $self->{'producer'} ) {
        my $from            = $parsers{ $self->{'from'} };
        my $producer_module = 
            'SQL::Translator::Producer::'.$producers{ $self->{'to'} };
        $self->{'producer'} = $producer_module->new( from => $from );
    }
    return $self->{'producer'};
}

1;

#-----------------------------------------------------
# Rescue the drowning and tie your shoestrings.
# Henry David Thoreau 
#-----------------------------------------------------

=head1 NAME

SQL::Translator - convert schema from one database to another

=head1 SYNOPSIS

  use SQL::Translator;
  my $translator = SQL::Translator->new;
  my $output     =  $translator->translate(
      from => 'mysql',
      to   => 'oracle',
      file => $file,
  ) or die $translator->error;
  print $output;

=head1 DESCRIPTION

This module attempts to simplify the task of converting one database
create syntax to another through the use of Parsers and Producers.
The idea is that any Parser can be used with any Producer in the
conversion process.  So, if you wanted PostgreSQL-to-Oracle, you could
just write the PostgreSQL parser and use an existing Oracle producer.

Currently, the existing parsers use Parse::RecDescent, and the
producers are just printing formatted output of the parsed data
structure.  New parsers don't necessarily have to use
Parse::RecDescent, however, as long as the data structure conforms to
what the producers are expecting.  With this separation of code, it is
hoped that developers will find it easy to add more database dialects
by using what's written, writing only what they need, and then
contributing their parsers or producers back to the project.

=head1 AUTHOR

Ken Y. Clark, kclark@logsoft.com

=head1 SEE ALSO

perl(1).

=cut
