package SQL::Translator::Parser::MySQL;

# -------------------------------------------------------------------
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>,
#                    darren chamberlain <darren@cpan.org>,
#                    Chris Mungall <cjm@fruitfly.org>
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

   The basic point of this module is to parse out any SQL or DB Schema information
   from an Excel spreadsheet file.

=cut

use strict;
use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$DEBUG   = 0 unless defined $DEBUG;

use Data::Dumper;
#use Spreadsheet::ParseExcel;
use Exporter;
use base qw(Exporter);

@EXPORT_OK = qw(parse);




# -------------------------------------------------------------------
sub parse {
    my ( $translator, $data ) = @_;
    my $parsed = {
        table1 => {
            "type" => undef,
            "indices" => [ { } ],
            "fields" => { },
        },
    };


    my $tr = new Spreadsheet::ParseExcel;
    $tr->Parse($data); 
    my ($R, $C);
    $R = 1; # For now we will assume all column names are in the first row 
  
    my @parsed = map { return $tr->{Cells}[$R][$C] }  ( $C = $tr->{MinCol} ; $C <= $tr->{MaxCol} ; $C++;) ;
 

    for (my $i = 0; $i < @parsed; $i++) {
        $parsed->{"table1"}->{"fields"}->{$parsed[$i]} = {
            type           => "field",
            order          => $i,
            name           => $parsed[$i],

            # Default datatype is "char"
            data_type      => "char",

            # default size is 8bits; something more reasonable?
            size           => 255,
            null           => 1,
            default        => "",
            is_auto_inc    => undef,

            # field field is the primary key
            is_primary_key => ($i == 0) ? 1 : undef,
        }
    }

   
    # Field 0 is primary key, by default, so add an index
    for ($parsed->{"table1"}->{"indices"}->[0]) {
        $_->{"type"} = "primary_key";
        $_->{"name"} = undef;
        $_->{"fields"} = [ $parsed[0] ];
    }



   return $parsed;


}

1;


=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>,
Chris Mungall

=head1 SEE ALSO

perl(1), Spreadsheet::ParseExcel.

=cut
