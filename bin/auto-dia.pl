#!/usr/bin/perl

# $Id: auto-dia.pl,v 1.1 2003-02-14 20:29:12 kycl4rk Exp $

=head1 NAME 

auto-dia.pl - Automatically create a diagram from a database schema

=head1 SYNOPSIS

  ./auto-dia.pl -d|--db=db_parser [options] schema.sql

  Options:

    -o|--output  Output file name (default STDOUT)
    -i|--image   Output image type (default PNG)
    -t|--title   Title to give schema
    -c|--cols    Number of columns

=head1 DESCRIPTION

This script will create a picture of your schema.  Only the database
driver argument is required.  If no output file name is given, then
image will be printed to STDOUT, so you should redirect the output
into a file.

=cut

use strict;
use Getopt::Long;
use GD;
use Pod::Usage;
use SQL::Translator;

my $VERSION = (qw$Revision: 1.1 $)[-1];

my ( $out_file, $image_type, $db_driver, $title, $no_columns );
GetOptions(
    'd|db=s'      => \$db_driver,
    'o|output:s'  => \$out_file,
    'i|image:s'   => \$image_type,
    't|title:s'   => \$title,
    'c|columns:i' => \$no_columns,
) or die pod2usage;
my $file = shift @ARGV or pod2usage( -message => 'No input file' );

pod2usage( -message => "No db driver specified" ) unless $db_driver;
$image_type = $image_type ? lc $image_type : 'png';
$title    ||= $file;

my $t    = SQL::Translator->new( parser => $db_driver, producer => 'Raw' );
my $data = $t->translate( $file ) or die $t->error;
my $font = gdTinyFont;

my $no_tables    = scalar keys %$data;
$no_columns    ||= sprintf( "%.0f", sqrt( $no_tables ) + .5 );
my $no_per_col   = sprintf( "%.0f", $no_tables/$no_columns + .5 );
warn "no per col = '$no_per_col'\n";

my ( @shapes, $max_x, $max_y );
my $orig_y      = 40;
my ( $x, $y )   = ( 20, $orig_y );
my $cur_col     = 1;
my $no_this_col = 0;
my $this_col_x  = $x;

for my $table (
    map  { $_->[1] }
    sort { $a->[0] <=> $b->[0] }
    map  { [ $_->{'order'}, $_ ] }
    values %$data 
) {
    my $table_name = $table->{'table_name'};
    my $top        = $y;
    push @shapes, [ 'string', $font, $this_col_x, $y, $table_name ];

    $y                   += $font->height + 2;
    my $below_table_name  = $y;
    $y                   += 2;
    my $this_max_x        = $this_col_x + ($font->width * length($table_name));

    my @fields = 
        map  { $_->[1] }
        sort { $a->[0] <=> $b->[0] }
        map  { [ $_->{'order'}, $_ ] }
        values %{ $table->{'fields'} };

    my $pk;
    for my $index ( @{ $table->{'indices'} || [] } ) {
        next unless $index->{'type'} eq 'primary_key';
        my @fields = @{ $index->{'fields'} || [] } or next;
        $pk = $fields[0];
    }

    my ( @fld_desc, $max_name );
    for my $f ( @fields ) {
        my $name = $f->{'name'} or next;
        $name   .= ' *' if $name eq $pk;

        my $size = @{ $f->{'size'} || [] } 
            ? '(' . join( ',', @{ $f->{'size'} } ) . ')'
            : '';
        my $desc = join( ' ', map { $_ || () } $f->{'data_type'}, $size );
        
        my $nlen  = length $name;
        $max_name = $nlen if $nlen > $max_name;
        push @fld_desc, [ $name, $desc ];
    }

    $max_name += 4;
    for my $fld_desc ( @fld_desc ) {
        my ( $name, $desc ) = @$fld_desc;
        my $diff = $max_name - length $name;
        $name   .= ' ' x $diff;
        $desc    = $name . $desc;

        push @shapes, [ 'string', $font, $this_col_x, $y, $desc ];
        $y         += $font->height + 2;
        my $length  = $this_col_x + ( $font->width * length( $desc ) );
        $this_max_x = $length if $length > $this_max_x;
    }

    $this_max_x += 5;
    push @shapes, [ 'line', $this_col_x - 5, $below_table_name, 
        $this_max_x, $below_table_name ];
    push @shapes, [ 
        'rectangle', $this_col_x - 5, $top - 5, $this_max_x, $y + 5 
    ];
    $max_x = $this_max_x if $this_max_x > $max_x;
    $y    += 25;
    
    if ( ++$no_this_col == $no_per_col ) {
        $cur_col++;
        $no_this_col = 0;    
        $max_x      += 20;
        $this_col_x  = $max_x;
        $max_y       = $y if $y > $max_y;
        $y           = $orig_y;
    }
}

#
# Add the title and signature.
#
my $large_font = gdLargeFont;
my $title_len  = $large_font->width * length $title;
push @shapes, [ 'string', $large_font, $max_x/2 - $title_len/2, 10, $title ];

my $sig = "auto-dia.pl $VERSION";
push @shapes, [ 'string', $font, $max_x/2 - $title_len/2, 10, $title ];

my $gd = GD::Image->new( $max_x + 10, $max_y );
unless ( $gd->can( $image_type ) ) {
    die "GD can't create images of type '$image_type'\n";
}
my $white = $gd->colorAllocate(255,255,255);
my $black = $gd->colorAllocate(00,00,00);
$gd->interlaced( 'true' );
$gd->fill( 0, 0, $white );
for my $shape ( @shapes ) {
    my $method = shift @$shape;
    $gd->$method( @$shape, $black );
}

if ( $out_file ) {
    open my $fh, ">$out_file" or die "Can't write '$out_file': $!\n";
    print $fh $gd->$image_type;
    close $fh;
    print "Image written to '$out_file'.  Done.\n";
}
else {
    print $gd->$image_type;
}

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
