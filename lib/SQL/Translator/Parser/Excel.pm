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
use vars qw($DEBUG $VERSION @EXPORT_OK);
$DEBUG = 0 unless defined $DEBUG;

use Spreadsheet::ParseExcel;
use Exporter;
use SQL::Translator::Utils qw(debug normalize_name);

use base qw(Exporter);

@EXPORT_OK = qw(parse);

# -------------------------------------------------------------------
# parse($tr, $data)
#
# Note that $data, in the case of this parser, is unuseful.
# Spreadsheet::ParseExcel works on files, not data streams.
# -------------------------------------------------------------------
sub parse {
    my ($tr, $data) = @_;
    my $filename = $tr->filename || return;
    my $wb = Spreadsheet::ParseExcel::Workbook->Parse($filename);
    my (%parsed, $wb_count, $num);
    my $table_no = 0;

    $wb_count = $wb->{'SheetCount'} || 0;
    for $num (0 .. $wb_count - 1) {
        my $ws = $wb->Worksheet($num);
        my $name = $ws->{Name} || ++$table_no;

        $name = normalize_name($name);

        my @cols = $ws->ColRange;
        next unless $cols[1] > 0;

        $parsed{$name} = {
            table_name  => $name,
            type        => undef,
            indices     => [ {} ],
            fields      => { },
        };

        for my $col ($cols[0] .. $cols[1]) {
            my $cell = $ws->Cell(0, $col);
            $parsed{$name}->{'fields'}->{$cell->{Val}} = {
                type           => 'field',
                order          => $col,
                name           => $cell->{Val},

                # Default datatype is 'char'
                data_type      => ET_to_ST($cell->{Type}),

                # default size is 8bits; something more reasonable?
                size           => [ 255 ],
                null           => 1,
                default        => '',
                is_auto_inc    => undef,

                # field field is the primary key
                is_primary_key => ($col == 0) ? 1 : undef,
            }
        }
    }

    return \%parsed;
}

my %ET_to_ST = (
    'Text'    => 'VARCHAR',
    'Date'    => 'DATETIME',
    'Numeric' => 'DOUBLE',
);
sub ET_to_ST {
    my $et = shift;
    $ET_to_ST{$et} || $ET_to_ST{'Text'};
}

1;

=pod

=head1 AUTHORS

Mike Mellilo <mmelillo@users.sourceforge.net>,
darren chamberlain E<lt>dlc@users.sourceforge.netE<gt>
Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=head1 SEE ALSO

perl(1), Spreadsheet::ParseExcel.

=cut
