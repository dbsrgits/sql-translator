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

my %ET_to_ST  = (
    'Text'    => 'VARCHAR',
    'Date'    => 'DATETIME',
    'Numeric' => 'DOUBLE',
);

# -------------------------------------------------------------------
# parse($tr, $data)
#
# Note that $data, in the case of this parser, is unuseful.
# Spreadsheet::ParseExcel works on files, not data streams.
# -------------------------------------------------------------------
sub parse {
    my ($tr, $data) = @_;
    my $filename    = $tr->filename || return;
    my $wb          = Spreadsheet::ParseExcel::Workbook->Parse( $filename );
    my $schema      = $tr->schema;
    my $table_no    = 0;

    my $wb_count = $wb->{'SheetCount'} || 0;
    for my $num ( 0 .. $wb_count - 1 ) {
        $table_no++;
        my $ws         = $wb->Worksheet( $num );
        my $table_name = normalize_name( $ws->{'Name'} || "Table$table_no" );

        my @cols = $ws->ColRange;
        next unless $cols[1] > 0;

        my $table = $schema->add_table( name => $table_name );

        for my $col ( $cols[0] .. $cols[1] ) {
            my $cell      = $ws->Cell(0, $col);
            my $col_name  = normalize_name( $cell->{'Val'} );
            my $data_type = ET_to_ST( $cell->{'Type'} );

            my $field = $table->add_field(
                name              => $col_name,
                data_type         => $data_type,
                default_value     => '',
                size              => 255,
                is_nullable       => 1,
                is_auto_increment => undef,
            ) or die $table->error;

            if ( $col == 0 ) {
                $table->primary_key( $field->name );
                $field->is_primary_key(1);
            }
        }
    }

    return 1;
}

sub ET_to_ST {
    my $et = shift;
    $ET_to_ST{$et} || $ET_to_ST{'Text'};
}

1;

# -------------------------------------------------------------------
# Education is an admirable thing,
# but it is as well to remember that
# nothing that is worth knowing can be taught.
# Oscar Wilde
# -------------------------------------------------------------------

=pod

=head1 AUTHORS

Mike Mellilo <mmelillo@users.sourceforge.net>,
darren chamberlain E<lt>dlc@users.sourceforge.netE<gt>
Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=head1 SEE ALSO

perl(1), Spreadsheet::ParseExcel.

=cut
