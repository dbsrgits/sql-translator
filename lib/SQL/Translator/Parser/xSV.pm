package SQL::Translator::Parser::xSV;

# -------------------------------------------------------------------
# $Id: xSV.pm,v 1.7 2003-05-09 17:15:30 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>,
#                    darren chamberlain <darren@cpan.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
# 02111-1307  USA
# -------------------------------------------------------------------

=head1 NAME

SQL::Translator::Parser::xSV - parser for arbitrarily delimited text files

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::xSV;

  my $translator  =  SQL::Translator->new(
      parser      => 'xSV',
      parser_args => { field_separator => "\t" },
  );

=head1 DESCRIPTION

Parses arbitrarily delimited text files.  See the 
Text::RecordParser manpage for arguments on how to parse the file
(e.g., C<field_separator>, C<record_separator>).  Other arguments
include:

=over

=item * scan_fields

Indicates that the columns should be scanned to determine data types
and field sizes.  True by default.

=item * trim_fields

A shortcut to sending filters to Text::RecordParser, will create 
callbacks that trim leading and trailing spaces from fields and headers.
True by default.

=back

Field names will automatically be normalized by 
C<SQL::Translator::Utils::normalize>.

=cut

# -------------------------------------------------------------------

use strict;
use vars qw($VERSION @EXPORT);
$VERSION = sprintf "%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/;

use Exporter;
use Text::ParseWords qw(quotewords);
use Text::RecordParser;
use SQL::Translator::Utils qw(debug normalize_name);

use base qw(Exporter);
@EXPORT = qw(parse);

#
# Passed a SQL::Translator instance and a string containing the data
#
sub parse {
    my ($tr, $data, $schema) = @_;
    my $args             = $tr->parser_args;
    my $parser           = Text::RecordParser->new(
        field_separator  => $args->{'field_separator'}  || ',',
        record_separator => $args->{'record_separator'} || "\n",
        data             => $data,
        header_filter    => \&normalize_name,
    );

    $parser->field_filter( sub { $_ = shift; s/^\s+|\s+$//g; $_ } ) 
        unless defined $args->{'trim_fields'} && $args->{'trim_fields'} == 0;

    #
    # Create skeleton structure, mostly empty.
    #
    my $parsed      =  {
        table1      => {
            type    => undef,
            indices => [ { } ],
            fields  => { },
        },
    };

    my $table = $schema->add_table( name => 'table1' );

    #
    # Get the field names from the first row.
    #
    $parser->bind_header;
    my @field_names = $parser->field_list;

    for ( my $i = 0; $i < @field_names; $i++ ) {
        $parsed->{'table1'}{'fields'}{ $field_names[$i] } = {
            type           => 'field',
            order          => $i,
            name           => $field_names[$i],

            # Default datatype is "char"
            data_type      => 'char',

            # default size is 8bits; something more reasonable?
            size           => [ 255 ],
            null           => 1,
            default        => '',
            is_auto_inc    => undef,

            # field field is the primary key
            is_primary_key => ($i == 0) ? 1 : undef,
        };

        my $field = $table->add_field(
            name              => $field_names[$i],
            data_type         => 'char',
            default_value     => '',
            size              => 255,
            is_nullable       => 1,
            is_auto_increment => undef,
        ) or die $table->error;

        if ( $i == 0 ) {
            $table->primary_key( $field->name );
            $field->is_primary_key(1);
        }
    }

    #
    # If directed, look at every field's values to guess size and type.
    #
    unless ( 
        defined $args->{'scan_fields'} &&
        $args->{'scan_fields'} == 0
    ) {
        my %field_info = map { $_, {} } @field_names;
        while ( my $rec = $parser->fetchrow_hashref ) {
            for my $field ( @field_names ) {
                my $data = defined $rec->{ $field } ? $rec->{ $field } : '';
                my $size = length $data;
                my $type;

                if ( $data =~ /^-?\d+$/ ) {
                    $type = 'integer';
                }
                elsif ( $data =~ /^-?[\d.]+$/ ) {
                    $type = 'float';
                }
                else {
                    $type = 'char';
                }

                my $fsize = $field_info{ $field }{'size'} || 0;
                if ( $size > $fsize ) {
                    $field_info{ $field }{'size'} = $size;
                }

                $field_info{ $field }{ $type }++;
            }
        }

        for my $field ( keys %field_info ) {
            my $size      = $field_info{ $field }{'size'};
            my $data_type = 
                $field_info{ $field }{'char'}  ? 'char'  : 
                $field_info{ $field }{'float'} ? 'float' : 'integer';

            $parsed->{'table1'}{'fields'}{ $field }{'size'} = 
                [ $field_info{ $field }{'size'} ];

            $parsed->{'table1'}{'fields'}{ $field }{'data_type'} = $data_type;

            my $field = $table->get_field( $field );
            $field->size( $size );
            $field->data_type( $data_type );
        }
    }

    #
    # Field 0 is primary key, by default, so add an index
    #
    for ( $parsed->{'table1'}->{'indices'}->[0] ) {
        $_->{'type'}   = 'primary_key';
        $_->{'name'}   = undef;
        $_->{'fields'} = [ $field_names[0] ];
    }

    return $parsed;
}

1;

# -------------------------------------------------------------------
=pod

=head1 AUTHOR

Darren Chamberlain E<lt>darren@cpan.orgE<gt>,
Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

Text::RecordParser.

=cut
