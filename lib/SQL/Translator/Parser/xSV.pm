package SQL::Translator::Parser::xSV;

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

=head1 OPTIONS

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
C<SQL::Translator::Utils::normalize_name>.

=cut

use strict;
use warnings;
our @EXPORT;
our $VERSION = '1.66';

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
  my ($tr, $data) = @_;
  my $args   = $tr->parser_args;
  my $parser = Text::RecordParser->new(
    field_separator  => $args->{'field_separator'}  || ',',
    record_separator => $args->{'record_separator'} || "\n",
    data             => $data,
    header_filter    => \&normalize_name,
  );

  $parser->field_filter(sub { $_ = shift || ''; s/^\s+|\s+$//g; $_ })
      unless defined $args->{'trim_fields'} && $args->{'trim_fields'} == 0;

  my $schema = $tr->schema;
  my $table  = $schema->add_table(name => 'table1');

  #
  # Get the field names from the first row.
  #
  $parser->bind_header;
  my @field_names = $parser->field_list;

  for (my $i = 0; $i < @field_names; $i++) {
    my $field = $table->add_field(
      name              => $field_names[$i],
      data_type         => 'char',
      default_value     => '',
      size              => 255,
      is_nullable       => 1,
      is_auto_increment => undef,
    ) or die $table->error;

    if ($i == 0) {
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
    while (my $rec = $parser->fetchrow_hashref) {
      for my $field (@field_names) {
        my $data = defined $rec->{$field} ? $rec->{$field} : '';
        my $size = [ length $data ];
        my $type;

        if ($data =~ /^-?\d+$/) {
          $type = 'integer';
        } elsif ($data =~ /^-?[,\d]+\.[\d+]?$/
          || $data =~ /^-?[,\d]+?\.\d+$/
          || $data =~ /^-?\.\d+$/) {
          $type = 'float';
          my ($w, $d)
              = map { s/,//g; length $_ || 1 } split(/\./, $data);
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
      $field->size($size);
      $field->data_type($data_type);
    }
  }

  return 1;
}

1;

=pod

=head1 AUTHORS

Darren Chamberlain E<lt>darren@cpan.orgE<gt>,
Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

Text::RecordParser, SQL::Translator.

=cut
