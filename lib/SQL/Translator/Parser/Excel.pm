package SQL::Translator::Parser::Excel;

# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>,
#                    darren chamberlain <darren@cpan.org>,
#                    Chris Mungall <cjm@fruitfly.org>,
#                    Mike Mellilo <mmelillo@users.sourceforge.net>
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

SQL::Translator::Parser::Excel - parser for Excel

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::Excel;

  my $translator = SQL::Translator->new;
  $translator->parser("SQL::Translator::Parser::Excel");

=head1 DESCRIPTION

Parses an Excel spreadsheet file for SQL::Translator.  You can then
turn the data into a database tables or graphs.

=cut

use strict;
use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$DEBUG   = 0 unless defined $DEBUG;

use Data::Dumper;
use Spreadsheet::ParseExcel;
use Exporter;
use base qw(Exporter);

@EXPORT_OK = qw(parse);

# -------------------------------------------------------------------
sub parse {
    my ( $translator, $data ) = @_;
    my $parsed        =  {
        table1        => {
            "type"    => undef,
            "indices" => [ { } ],
            "fields"  => { },
        },
    };

    my $tr = Spreadsheet::ParseExcel->new;
    $tr->Parse( $data ); 
    my $r = 1; # For now we will assume all column names are in the first row 
    my $c = 0; 

    #
    # Mikey, what's going on here?
    #
    my @parsed = map { return $tr->{'Cells'}[$r][$c] } ( 
        $c  = $tr->{'MinCol'}; 
        $c <= $tr->{'MaxCol'}; # Is "<=" right?
        $c++;
    );

    for ( my $i = 0; $i < @parsed; $i++ ) {
        $parsed->{'table1'}->{'fields'}->{$parsed[$i]} = {
            type           => 'field',
            order          => $i,
            name           => $parsed[$i],

            # Default datatype is 'char'
            data_type      => 'char',

            # default size is 8bits; something more reasonable?
            size           => 255,
            null           => 1,
            default        => '',
            is_auto_inc    => undef,

            # field field is the primary key
            is_primary_key => ($i == 0) ? 1 : undef,
        }
    }

   
    # Field 0 is primary key, by default, so add an index
    for ($parsed->{'table1'}->{'indices'}->[0]) {
        $_->{'type'} = 'primary_key';
        $_->{'name'} = undef;
        $_->{'fields'} = [ $parsed[0] ];
    }

   return $parsed;
}

1;

=pod

=head1 AUTHORS

Mike Mellilo <mmelillo@users.sourceforge.net>,
Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=head1 SEE ALSO

perl(1), Spreadsheet::ParseExcel.

=cut
