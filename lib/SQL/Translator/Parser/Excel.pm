package SQL::Translator::Parser::Excel;

=head1 NAME

SQL::Translator::Parser::Excel - parser for Excel

=head1 SYNOPSIS

  use SQL::Translator;

  my $translator = SQL::Translator->new;
  $translator->parser('Excel');

=head1 DESCRIPTION

Parses an Excel spreadsheet file using Spreadsheet::ParseExcel.

=head1 OPTIONS

=over

=item * scan_fields

Indicates that the columns should be scanned to determine data types
and field sizes.  True by default.

=back

=cut

use strict;
use warnings;
our ($DEBUG, @EXPORT_OK);
$DEBUG = 0 unless defined $DEBUG;
our $VERSION = '1.66';

use Spreadsheet::ParseExcel;
use Exporter;
use SQL::Translator::Utils qw(debug normalize_name);

use base qw(Exporter);

@EXPORT_OK = qw(parse);

my %ET_to_ST = (
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
  my $args     = $tr->parser_args;
  my $filename = $tr->filename || return;
  my $wb       = Spreadsheet::ParseExcel::Workbook->Parse($filename);
  my $schema   = $tr->schema;
  my $table_no = 0;

  my $wb_count = $wb->{'SheetCount'} || 0;
  for my $num (0 .. $wb_count - 1) {
    $table_no++;
    my $ws         = $wb->Worksheet($num);
    my $table_name = normalize_name($ws->{'Name'} || "Table$table_no");

    my @cols = $ws->ColRange;
    next unless $cols[1] > 0;

    my $table = $schema->add_table(name => $table_name);

    my @field_names = ();
    for my $col ($cols[0] .. $cols[1]) {
      my $cell      = $ws->Cell(0, $col);
      my $col_name  = normalize_name($cell->{'Val'});
      my $data_type = ET_to_ST($cell->{'Type'});
      push @field_names, $col_name;

      my $field = $table->add_field(
        name              => $col_name,
        data_type         => $data_type,
        default_value     => '',
        size              => 255,
        is_nullable       => 1,
        is_auto_increment => undef,
      ) or die $table->error;

      if ($col == 0) {
        $table->primary_key($field->name);
        $field->is_primary_key(1);
      }
    }

    #
    # If directed, look at every field's values to guess size and type.
    #
    unless (defined $args->{'scan_fields'}
      && $args->{'scan_fields'} == 0) {
      my %field_info = map { $_, {} } @field_names;

      for (
        my $iR = $ws->{'MinRow'} == 0 ? 1 : $ws->{'MinRow'};
        defined $ws->{'MaxRow'} && $iR <= $ws->{'MaxRow'};
        $iR++
      ) {
        for (my $iC = $ws->{'MinCol'}; defined $ws->{'MaxCol'} && $iC <= $ws->{'MaxCol'}; $iC++) {
          my $field = $field_names[$iC];
          my $data  = $ws->{'Cells'}[$iR][$iC]->{'_Value'};
          next if !defined $data || $data eq '';
          my $size = [ length $data ];
          my $type;

          if ($data =~ /^-?\d+$/) {
            $type = 'integer';
          } elsif ($data =~ /^-?[,\d]+\.[\d+]?$/
            || $data =~ /^-?[,\d]+?\.\d+$/
            || $data =~ /^-?\.\d+$/) {
            $type = 'float';
            my ($w, $d) = map { s/,//g; length $_ || 1 }
                split(/\./, $data);
            $size = [ $w + $d, $d ];
          } else {
            $type = 'char';
          }

          for my $i (0, 1) {
            next unless defined $size->[$i];
            my $fsize = $field_info{$field}{'size'}[$i] || 0;
            if ($size->[$i] > $fsize) {
              $field_info{$field}{'size'}[$i] = $size->[$i];
            }
          }

          $field_info{$field}{$type}++;
        }
      }

      for my $field (keys %field_info) {
        my $size = $field_info{$field}{'size'} || [1];
        my $data_type
            = $field_info{$field}{'char'}    ? 'char'
            : $field_info{$field}{'float'}   ? 'float'
            : $field_info{$field}{'integer'} ? 'integer'
            :                                  'char';

        if ($data_type eq 'char' && scalar @$size == 2) {
          $size = [ $size->[0] + $size->[1] ];
        }

        my $field = $table->get_field($field);
        $field->size($size) if $size;
        $field->data_type($data_type);
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
darren chamberlain E<lt>dlc@users.sourceforge.netE<gt>,
Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

Spreadsheet::ParseExcel, SQL::Translator.

=cut
