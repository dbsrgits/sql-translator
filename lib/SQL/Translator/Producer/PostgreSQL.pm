package SQL::Translator::Producer::PostgreSQL;

# -------------------------------------------------------------------
# $Id: PostgreSQL.pm,v 1.2 2002-11-22 03:03:40 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2002 Ken Y. Clark <kclark@cpan.org>,
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

use strict;
use vars qw($VERSION $DEBUG);
$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;
$DEBUG = 1 unless defined $DEBUG;

use Data::Dumper;

my %translate  = (
    #
    # MySQL types
    #
    bigint     => 'bigint',
    double     => 'double precision',
    decimal    => 'decimal',
    float      => 'double precision',
    int        => 'integer',
    mediumint  => 'integer',
    smallint   => 'smallint',
    tinyint    => 'smallint',
    char       => 'char',
    varchar    => 'varchar',
    longtext   => 'text',
    mediumtext => 'text',
    text       => 'text',
    tinytext   => 'text',
    tinyblob   => 'bytea',
    blob       => 'bytea',
    mediumblob => 'bytea',
    longblob   => 'bytea',
    enum       => 'varchar',
    set        => 'varchar',
    date       => 'date',
    datetime   => 'timestamp',
    time       => 'date',
    timestamp  => 'timestamp',
    year       => 'date',

    #
    # Oracle types
    #
);


sub import {
    warn "loading " . __PACKAGE__ . "...\n";
}

sub produce {
    my ( $translator, $data ) = @_;
    debug("Beginning production\n");
    my $create = sprintf "--\n-- Created by %s\n-- Created on %s\n-- \n\n",
        __PACKAGE__, scalar localtime;

    for my $table ( keys %{ $data } ) {
        debug( "Looking at table '$table'\n" );
        my $table_data = $data->{$table};
        my @fields     = sort { 
            $table_data->{'fields'}->{$a}->{'order'} 
            <=>
            $table_data->{'fields'}->{$b}->{'order'}
        } keys %{ $table_data->{'fields'} };

        $create .= "--\n-- Table: $table\n--\n";
        $create .= "CREATE TABLE $table (\n";

        #
        # Fields
        #
        my @field_statements;
        for my $field ( @fields ) {
            debug("Looking at field '$field'\n");
            my $field_data = $table_data->{'fields'}->{ $field };
            my @fdata      = ("", $field);

            # data type and size
            push @fdata, sprintf "%s%s", 
                $field_data->{'data_type'},
                ( defined $field_data->{'size'} ) 
                    ? "($field_data->{'size'})" : '';

            # Null?
            push @fdata, "NOT NULL" unless $field_data->{'null'};

            # Default?  XXX Need better quoting!
            my $default = $field_data->{'default'};
            if ( defined $default ) {
                push @fdata, "DEFAULT '$default'";
#                if (int $default eq "$default") {
#                    push @fdata, "DEFAULT $default";
#                } else {
#                    push @fdata, "DEFAULT '$default'";
#                }
            }

            # auto_increment?
            push @fdata, "auto_increment" if $field_data->{'is_auto_inc'};

            # primary key?
            push @fdata, "PRIMARY KEY" if $field_data->{'is_primary_key'};

            push @field_statements, join( " ", @fdata );

        }
        $create .= join( ",\n", @field_statements );

        #
        # Other keys
        #
        my @indices = @{ $table_data->{'indices'} || [] };
        for ( my $i = 0; $i <= $#indices; $i++ ) {
            $create .= ",\n";
            my $key = $indices[$i];
            my ( $name, $type, $fields ) = @{ $key }{ qw( name type fields ) };
            if ( $type eq 'primary_key' ) {
                $create .= " PRIMARY KEY (@{$fields})"
            } 
            else {
                local $" = ", ";
                $create .= " KEY $name (@{$fields})"
            }
        }

        #
        # Footer
        #
        $create .= "\n);\n\n";
    }

    return $create;
}

use Carp;
sub debug {
    if ( $DEBUG ) {
        map { carp "[" . __PACKAGE__ . "] $_" } @_;
    }
}

1;
__END__

=head1 NAME

SQL::Translator::Producer::PostgreSQL - PostgreSQL-specific producer for SQL::Translator

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=cut
