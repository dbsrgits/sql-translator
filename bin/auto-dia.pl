#!/usr/bin/perl

# $Id: auto-dia.pl,v 1.3 2003-02-15 23:38:35 kycl4rk Exp $

=head1 NAME 

auto-dia.pl - Automatically create a diagram from a database schema

=head1 SYNOPSIS

  ./auto-dia.pl -d|--db=db_parser [options] schema.sql

  Options:

    -o|--output     Output file name (default STDOUT)
    -i|--image      Output image type (default PNG)
    -t|--title      Title to give schema
    -c|--cols       Number of columns
    -n|--no-lines   Don't draw lines
    -s|--skip       Fields to skip in natural joins
    --join-pk-only  Perform natural joins from primary keys only

=head1 DESCRIPTION

This script will create a picture of your schema.  Only the database
driver argument (for SQL::Translator) is required.  If no output file
name is given, then image will be printed to STDOUT, so you should
redirect the output into a file.

=cut

use strict;
use Getopt::Long;
use GD;
use Pod::Usage;
use SQL::Translator;

my $VERSION = (qw$Revision: 1.3 $)[-1];

#
# Get arguments.
#
my ( $out_file, $image_type, $db_driver, $title, $no_columns, 
    $no_lines, $skip_fields, $join_pk_only );
GetOptions(
    'd|db=s'         => \$db_driver,
    'o|output:s'     => \$out_file,
    'i|image:s'      => \$image_type,
    't|title:s'      => \$title,
    'c|columns:i'    => \$no_columns,
    'n|no-lines'     => \$no_lines,
    's|skip:s'       => \$skip_fields,
    '--join-pk-only' => \$join_pk_only,
) or die pod2usage;
my $file = shift @ARGV or pod2usage( -message => 'No input file' );

pod2usage( -message => "No db driver specified" ) unless $db_driver;
$image_type = $image_type ? lc $image_type : 'png';
$title    ||= $file;
my %skip    = map { $_, 1 } split ( /,/, $skip_fields );

#
# Parse file.
#
my $t    = SQL::Translator->new( parser => $db_driver, producer => 'Raw' );
my $data = $t->translate( $file ) or die $t->error;
use Data::Dumper;
#print Dumper( $data );
#exit;

#
# Layout the image.
#
my $font         = gdTinyFont;
my $no_tables    = scalar keys %$data;
$no_columns    ||= sprintf( "%.0f", sqrt( $no_tables ) + .5 );
my $no_per_col   = sprintf( "%.0f", $no_tables/$no_columns + .5 );

my @shapes;            
my ( $max_x, $max_y );           # the furthest x and y used
my $orig_y      = 40;            # used to reset y for each column
my ( $x, $y )   = (20, $orig_y); # where to start
my $cur_col     = 1;             # the current column
my $no_this_col = 0;             # number of tables in current column
my $this_col_x  = $x;            # current column's x
my $gutter      = 30;            # distance b/w columns
my %registry;                    # for locations of fields
my %table_x;                     # for max x of each table
my $field_no;                    # counter to give distinct no. to each field

for my $table (
    map  { $_->[1] }
    sort { $a->[0] <=> $b->[0] }
    map  { [ $_->{'order'}, $_ ] }
    values %$data 
) {
    my $table_name = $table->{'table_name'};
    my $top        = $y;
    push @shapes, [ 'string', $font, $this_col_x, $y, $table_name, 'black' ];

    $y                   += $font->height + 2;
    my $below_table_name  = $y;
    $y                   += 2;
    my $this_max_x        = $this_col_x + ($font->width * length($table_name));

    my @fields = 
        map  { $_->[1] }
        sort { $a->[0] <=> $b->[0] }
        map  { [ $_->{'order'}, $_ ] }
        values %{ $table->{'fields'} };

    my %pk;
    for my $index ( @{ $table->{'indices'} || [] } ) {
        next unless $index->{'type'} eq 'primary_key';
        my @fields = @{ $index->{'fields'} || [] } or next;
        $pk{ $_ } = 1 for @fields;
    }

    my ( @fld_desc, $max_name );
    for my $f ( @fields ) {
        my $name  = $f->{'name'} or next;
        my $is_pk = $pk{ $name };
        $name   .= ' *' if $is_pk;

        my $size = @{ $f->{'size'} || [] } 
            ? '(' . join( ',', @{ $f->{'size'} } ) . ')'
            : '';
        my $desc = join( ' ', map { $_ || () } $f->{'data_type'}, $size );
        
        my $nlen  = length $name;
        $max_name = $nlen if $nlen > $max_name;
        push @fld_desc, [ $name, $desc, $f->{'name'}, $is_pk ];
    }

    $max_name += 4;
    for my $fld_desc ( @fld_desc ) {
        my ( $name, $desc, $orig_name, $is_pk ) = @$fld_desc;
        my $diff = $max_name - length $name;
        $name   .= ' ' x $diff;
        $desc    = $name . $desc;

        push @shapes, [ 'string', $font, $this_col_x, $y, $desc, 'black' ];
        $y         += $font->height + 2;
        my $length  = $this_col_x + ( $font->width * length( $desc ) );
        $this_max_x = $length if $length > $this_max_x;

        unless ( $skip{ $orig_name } ) {
            my $y_link = $y - $font->height * .75;
            push @{ $registry{ $orig_name } }, {
                left     => [ $this_col_x - 2, $y_link ],
                right    => [ $length,         $y_link ],
                table    => $table_name,
                field_no => ++$field_no,
                is_pk    => $is_pk,
            };
        }
    }

    $this_max_x += 5;
    $table_x{ $table_name } = $this_max_x + 5;
    push @shapes, [ 'line', $this_col_x - 5, $below_table_name, 
        $this_max_x, $below_table_name, 'black' ];
    push @shapes, [ 
        'rectangle', $this_col_x - 5, $top - 5, $this_max_x, $y + 5, 'black'
    ];
    $max_x = $this_max_x if $this_max_x > $max_x;
    $y    += 25;
    
    if ( ++$no_this_col == $no_per_col ) { # if we've filled up this column
        $cur_col++;                        # up the column number
        $no_this_col = 0;                  # reset the number of tables
        $max_x      += $gutter;            # push the x over for next column
        $this_col_x  = $max_x;             # remember the max x for this column
        $max_y       = $y if $y > $max_y;  # note the max y
        $y           = $orig_y;            # reset the y for next column
    }
}

#
# Connect the lines.
#
my %horz_taken;
my %done;
unless ( $no_lines ) {
    for my $field_name ( keys %registry ) {
        my @positions = @{ $registry{ $field_name } || [] } or next;
        next if scalar @positions == 1;

        for my $i ( 0 .. $#positions ) {
            my $pos1        = $positions[ $i ];
            my ( $ax, $ay ) = @{ $pos1->{'left'}  };
            my ( $bx, $by ) = @{ $pos1->{'right'} };
            my $table1      = $pos1->{'table'};
            my $fno1        = $pos1->{'field_no'};
            my $is_pk       = $pos1->{'is_pk'};
            next if $join_pk_only and !$is_pk;

            for my $j ( 0 .. $#positions ) {
                my $pos2        = $positions[ $j ];
                my ( $cx, $cy ) = @{ $pos2->{'left'}  };
                my ( $dx, $dy ) = @{ $pos2->{'right'} };
                my $table2      = $pos2->{'table'};
                my $fno2        = $pos2->{'field_no'};
                next if $done{ $fno1 }{ $fno2 };
                next if $fno1 == $fno2;

                my @distances = ();
                push @distances, [
                    abs ( $ax - $cx ) + abs ( $ay - $cy ),
                    [ $ax, $ay, $cx, $cy ],
                    [ 'left', 'left' ]
                ];
                push @distances, [
                    abs ( $ax - $dx ) + abs ( $ay - $dy ),
                    [ $ax, $ay, $dx, $dy ],
                    [ 'left', 'right' ],
                ];
                push @distances, [
                    abs ( $bx - $cx ) + abs ( $by - $cy ),
                    [ $bx, $by, $cx, $cy ],
                    [ 'right', 'left' ],
                ];
                push @distances, [
                    abs ( $bx - $dx ) + abs ( $by - $dy ),
                    [ $bx, $by, $dx, $dy ],
                    [ 'right', 'right' ],
                ];
                @distances   = sort { $a->[0] <=> $b->[0] } @distances;
                my $shortest = $distances[0];
                my ( $x1, $y1, $x2, $y2 ) = @{ $shortest->[1] };
                my ( $side1, $side2     ) = @{ $shortest->[2] };
                my ( $start, $end );
                my $offset     = 9;
                my $col1_right = $table_x{ $table1 };
                my $col2_right = $table_x{ $table2 };

                my $diff = 0;
                if ( $x1 == $x2 ) {
                    while ( $horz_taken{ $x1 + $diff } ) {
                        $diff = $side1 eq 'left' ? $diff - 2 : $diff + 2; 
                    }
                    $horz_taken{ $x1 + $diff } = 1;
                }

                if ( $side1 eq 'left' ) {
                    $start = $x1 - $offset + $diff;
                }
                else {
                    $start = $col1_right + $diff;
                }

                if ( $side2 eq 'left' ) {
                    $end = $x2 - $offset + $diff;
                } 
                else {
                    $end = $col2_right + $diff;
                } 

                push @shapes, [ 'line', $x1,    $y1, $start, $y1, 'lightblue' ];
                push @shapes, [ 'line', $start, $y1, $end,   $y2, 'lightblue' ];
                push @shapes, [ 'line', $end,   $y2, $x2,    $y2, 'lightblue' ];
                $done{ $fno1 }{ $fno2 } = 1;
                $done{ $fno2 }{ $fno1 } = 1;
            }
        }
    }
}

#
# Add the title and signature.
#
my $large_font = gdLargeFont;
my $title_len  = $large_font->width * length $title;
push @shapes, [ 
    'string', $large_font, $max_x/2 - $title_len/2, 10, $title, 'black' 
];

my $sig     = "auto-dia.pl $VERSION";
my $sig_len = $font->width * length $sig;
push @shapes, [ 
    'string', $font, $max_x - $sig_len, $max_y - $font->height - 4, 
    $sig, 'black'
];

#
# Render the image.
#
my $gd = GD::Image->new( $max_x + 10, $max_y );
unless ( $gd->can( $image_type ) ) {
    die "GD can't create images of type '$image_type'\n";
}
my %colors = map { $_->[0], $gd->colorAllocate( @{$_->[1]} ) } (
    [ white     => [ 255, 255, 255 ] ],
    [ black     => [   0,   0,   0 ] ],
    [ lightblue => [ 173, 216, 230 ] ],
);
$gd->interlaced( 'true' );
$gd->fill( 0, 0, $colors{ 'white' } );
for my $shape ( @shapes ) {
    my $method = shift @$shape;
    my $color  = pop   @$shape;
    $gd->$method( @$shape, $colors{ $color } );
}

#
# Print the image.
#
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
