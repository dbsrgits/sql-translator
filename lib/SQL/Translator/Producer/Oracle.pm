package SQL::Translator::Producer::Oracle;

#-----------------------------------------------------
# $Id: Oracle.pm,v 1.1.1.1 2002-03-01 02:26:25 kycl4rk Exp $
#
# File       : SQL/Translator/Producer/Oracle.pm
# Programmer : Ken Y. Clark, kclark@logsoft.com
# Created    : 2002/02/27
# Purpose    : Oracle SQL producer
#-----------------------------------------------------

use strict;
use SQL::Translator::Producer;
use vars qw( $VERSION );
$VERSION = (qw$Revision: 1.1.1.1 $)[-1];

use base qw[ SQL::Translator::Producer ];

my $max_identifier_length = 30;
my %used_identifiers = ();

my %translate  = (
    bigint     => 'number',
    double     => 'number',
    decimal    => 'number',
    float      => 'number',
    int        => 'number',
    mediumint  => 'number',
    smallint   => 'number',
    tinyint    => 'number',

    char       => 'char',

    varchar    => 'varchar2',

    tinyblob   => 'CLOB',
    blob       => 'CLOB',
    mediumblob => 'CLOB',
    longblob   => 'CLOB',

    longtext   => 'long',
    mediumtext => 'long',
    text       => 'long',
    tinytext   => 'long',

    enum       => 'varchar2',
    set        => 'varchar2',

    date       => 'date',
    datetime   => 'date',
    time       => 'date',
    timestamp  => 'date',
    year       => 'date',
);

sub to { 'Oracle' }

sub translate {
    my ( $self, $data ) = @_;

    #print "got ", scalar keys %$data, " tables:\n";
    #print join(', ', keys %$data), "\n";
    #print Dumper( $data );

    #
    # Output
    #
    my $output = $self->header;

    #
    # Print create for each table
    #
    my ( $index_i, $trigger_i ) = ( 1, 1 );
    for my $table_name ( sort keys %$data ) { 
        check_identifier( $table_name );

        my ( @comments, @field_decs, @trigger_decs );

        my $table = $data->{ $table_name };
        push @comments, "#\n# Table: $table_name\n#";

        for my $field ( 
            map  { $_->[1] }
            sort { $a->[0] <=> $b->[0] }
            map  { [ $_->{'order'}, $_ ] }
            values %{ $table->{'fields'} }
        ) {
            #
            # Field name
            #
            my $field_str  = check_identifier( $field->{'name'} );

            #
            # Datatype
            #
            my $data_type  = $field->{'data_type'};
               $data_type  = defined $translate{ $data_type } ?
                             $translate{ $data_type } :
                             die "Unknown datatype: $data_type\n";
               $field_str .= ' '.$data_type;
               $field_str .= '('.$field->{'size'}.')' if defined $field->{'size'};

            #
            # Default value
            #
            if ( $field->{'default'} ) {
    #            next if $field->{'default'} eq 'NULL';
                $field_str .= sprintf(
                    ' DEFAULT %s',
                    $field->{'default'} =~ m/null/i ? 'NULL' : 
                    "'".$field->{'default'}."'"
                );
            }

            #
            # Not null constraint
            #
            unless ( $field->{'null'} ) {
                my $constraint_name = make_identifier($field->{'name'}, '_nn');
                $field_str .= ' CONSTRAINT ' . $constraint_name . ' NOT NULL';
            }

            #
            # Auto_increment
            #
            if ( $field->{'is_auto_inc'} ) {
                my $trigger_no       = $trigger_i++;
                my $trigger_sequence = 
                    join( '_', 'seq'    , $field->{'name'}, $trigger_no );
                my $trigger_name     = 
                    join( '_', 'autoinc', $field->{'name'}, $trigger_no );

                push @trigger_decs, 
                    'CREATE SEQUENCE ' . $trigger_sequence . ";" .
                    'CREATE OR REPLACE TRIGGER ' . $trigger_name .
                    ' BEFORE INSERT ON ' . $table_name .
                    ' FOR EACH ROW WHEN (new.' . $field->{'name'} . ' is null) ' .
                    ' BEGIN ' .
                        ' SELECT ' . $trigger_sequence . '.nextval ' .
                        ' INTO :new.' . $field->{'name'} .
                        " FROM dual;\n" .
                    ' END ' . $trigger_name . ";/"
                ;
            }

            push @field_decs, $field_str;
        }

        #
        # Index Declarations
        #
        my @index_decs = ();
        for my $index ( @{ $table->{'indeces'} } ) {
            my $index_name = $index->{'name'} || '';
            my $index_type = $index->{'type'} || 'normal';
            my @fields     = @{ $index->{'fields'} } or next;

            if ( $index_type eq 'primary_key' ) {
                if ( !$index_name ) {
                    $index_name = make_identifier( $table_name, 'i_', '_pk' );
                }
                elsif ( $index_name !~ m/^i_/ ) {
                    $index_name = make_identifier( $table_name, 'i_' );
                }
                elsif ( $index_name !~ m/_pk$/ ) {
                    $index_name = make_identifier( $table_name, '_pk' );
                }
                else {
                    $index_name = make_identifier( $index_name );
                }

                push @field_decs, 'CONSTRAINT ' . $index_name . ' PRIMARY KEY ' .
                    '(' . join( ', ', @fields ) . ')';
            }

            elsif ( $index_type eq 'unique' ) {
                if ( !$index_name ) {
                    $index_name = make_identifier( join( '_', @fields ), 'u_' );
                }
                elsif ( $index_name !~ m/^u_/ ) {
                    $index_name = make_identifier( $index_name, 'u_' );
                }
                else {
                    $index_name = make_identifier( $index_name );
                }

                push @field_decs, 'CONSTRAINT ' . $index_name . ' UNIQUE ' .
                    '(' . join( ', ', @fields ) . ')';
            }

            elsif ( $index_type eq 'normal' ) {
                if ( !$index_name ) {
                    $index_name = 
                        make_identifier($table_name, 'i_', '_'.$index_i++ );
                }
                elsif ( $index_name !~ m/^i_/ ) {
                    $index_name = make_identifier( $index_name, 'i_' );
                }
                else {
                    $index_name = make_identifier( $index_name );
                }

                push @index_decs, "CREATE INDEX $index_name on $table_name (".
                    join( ', ', @{ $index->{'fields'} } ).
                    ");"
                ; 
            }

            else {
                warn "On table $table_name, unknown index type: $index_type\n";
            }
        }

        my $create_statement = "CREATE TABLE $table_name (\n".
            join( ",\n", map { "  $_" } @field_decs ).
             "\n);"
        ;

        $output .= join( "\n\n", 
            @comments,
            $create_statement, 
            @trigger_decs, 
            @index_decs, 
            '' 
        );
    }

    $output .= "#\n# End\n#\n";
}

#
# Used to make index names
#
sub make_identifier {
    my ( $identifier, @mutations ) = @_;
    my $length_of_mutations;
    for my $mutation ( @mutations ) {
        $length_of_mutations += length( $mutation );
    }

    if ( 
        length( $identifier ) + $length_of_mutations >
        $max_identifier_length
    ) {
        $identifier = substr( 
            $identifier, 
            0, 
            $max_identifier_length - $length_of_mutations
        );
    }

    for my $mutation ( @mutations ) {
        if ( $mutation =~ m/.+_$/ ) {
            $identifier = $mutation.$identifier;
        }
        elsif ( $mutation =~ m/^_.+/ ) {
            $identifier = $identifier.$mutation;
        }
    }

    if ( $used_identifiers{ $identifier } ) {
        my $index = 1;
        if ( $identifier =~ m/_(\d+)$/ ) {
            $index = $1;
            $identifier = substr( 
                $identifier, 
                0, 
                length( $identifier ) - ( length( $index ) + 1 )
            );
        }
        $index++;
        return make_identifier( $identifier, '_'.$index );
    }

    $used_identifiers{ $identifier } = 1;

    return $identifier;
}

#
# Checks to see if an identifier is not too long
#
sub check_identifier {
    my $identifier = shift;
    die "Identifier '$identifier' is too long, unrecoverable error.\n"
        if length( $identifier ) > $max_identifier_length;
    return $identifier;
}

1;

#-----------------------------------------------------
# All bad art is the result of good intentions.
# Oscar Wilde
#-----------------------------------------------------

=head1 NAME

SQL::Translator::Producer::Oracle - Oracle SQL producer

=head1 SYNOPSIS

  use SQL::Translator::Producer::Oracle;

=head1 DESCRIPTION

Blah blah blah.

=head1 AUTHOR

Ken Y. Clark, kclark@logsoft.com

=head1 SEE ALSO

perl(1).

=cut
