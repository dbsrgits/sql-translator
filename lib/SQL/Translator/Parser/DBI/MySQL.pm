package SQL::Translator::Parser::DBI::MySQL;

# -------------------------------------------------------------------
# $Id: MySQL.pm,v 1.3 2003-10-15 16:36:28 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>.
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

SQL::Translator::Parser::DBI::MySQL - parser for DBD::mysql

=head1 SYNOPSIS

This module will be invoked automatically by SQL::Translator::Parser::DBI,
so there is no need to use it directly.

=head1 DESCRIPTION

Uses SQL calls to query database directly for schema rather than parsing
a create file.  Should be much faster for larger schemas.

=cut

use strict;
use DBI;
use Data::Dumper;
use SQL::Translator::Schema::Constants;

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

# -------------------------------------------------------------------
sub parse {
    my ( $tr, $dbh ) = @_;
    my $schema       = $tr->schema;
    my @table_names  = @{ $dbh->selectcol_arrayref( 'show tables') };

    for my $table_name ( @table_names ) {
        my $table =  $schema->add_table( 
            name  => $table_name,
        ) or die $schema->error;

        my $cols = $dbh->selectall_arrayref(
            "desc $table_name", 
            { Columns => {} }
        );

        for my $col ( @$cols ) {
            my $fname       = $col->{'field'} or next;
            my $type        = $col->{'type'}  or next;
            my $collation   = $col->{'collation'} || '';
            my $is_nullable = uc $col->{'null'} eq 'YES' ? 1 : 0;
            my $key         = $col->{'key'};
            my $default     = $col->{'default'};
            my $extra       = $col->{'extra'};

            my ( $data_type, $size, $char_set );

            #
            # Normal datatype = "int(11)" 
            # or "varchar(20) character set latin1"
            #
            if ( $type =~ m{ 
                (\w+)       # data type
                \(          # open paren
                (\d+)       # first number
                (?:,(\d+))? # optional comma and number
                \)          # close paren
                (.*)?       # anything else (character set)
                }x  
            ) {
                $data_type = $1;
                $size      = $2;
                $size     .= ",$3" if $3;
                $char_set  = $4 || '';
            }
            #
            # Some data type just say "double" or "text"
            #
            elsif ( $type =~ m{ 
                (\w+)       # data type
                (.*)?       # anything else (character set)
                }x  
            ) {
                $data_type = $1;
                $size      = undef;
                $char_set  = $2 || '';
            }

            my $field             =  $table->add_field(
                name              => $fname,
                data_type         => $data_type,
                size              => $size,
                default_value     => $default,
                is_auto_increment => $extra eq 'auto_increment',
                is_nullable       => $is_nullable,
                comments          => $extra,
            ) or die $table->error;

            $table->primary_key( $field->name ) if $key eq 'PRI';
        }

        my $indices = $dbh->selectall_arrayref(
            "show index from $table_name",
            { Columns => {} },
        );

        my ( %keys, %constraints, $order );
        for my $index ( @$indices ) {
            my $table        = $index->{'table'};
            my $non_unique   = $index->{'non_unique'};
            my $key_name     = $index->{'key_name'} || '';
            my $seq_in_index = $index->{'seq_in_index'};
            my $column_name  = $index->{'column_name'};
            my $collation    = $index->{'collation'};
            my $cardinality  = $index->{'cardinality'};
            my $sub_part     = $index->{'sub_part'};
            my $packed       = $index->{'packed'};
            my $null         = $index->{'null'};
            my $index_type   = $index->{'index_type'};
            my $comment      = $index->{'comment'};

            my $is_constraint = $key_name eq 'PRIMARY' || $non_unique == 0;

            if ( $is_constraint ) {
                $constraints{ $key_name }{'order'} = ++$order;
                push @{ $constraints{ $key_name }{'fields'} }, $column_name;

                if ( $key_name eq 'PRIMARY' ) {
                    $constraints{ $key_name }{'type'} = PRIMARY_KEY;
                }
                elsif ( $non_unique == 0 ) {
                    $constraints{ $key_name }{'type'} = UNIQUE;
                }
            }
            else {
                $keys{ $key_name }{'order'} = ++$order;
                push @{ $keys{ $key_name }{'fields'} }, $column_name;
            }
        }

        for my $key_name (
            sort { $keys{ $a }{'order'} <=> $keys{ $b }{'order'} }
            keys %keys
        ) {
            my $key    = $keys{ $key_name };
            my $index  =  $table->add_index(
                name   => $key_name,
                type   => NORMAL,
                fields => $key->{'fields'},
            ) or die $table->error;
        }
    
        for my $constraint_name (
            sort { $constraints{ $a }{'order'} <=> $constraints{ $b }{'order'} }
            keys %constraints
        ) {
            my $def        =  $constraints{ $constraint_name };
            my $constraint =  $table->add_constraint(
                name       => $constraint_name,
                type       => $def->{'type'},
                fields     => $def->{'fields'},
            ) or die $table->error;
        }
    }

    return 1;
}

1;

# -------------------------------------------------------------------
# Where man is not nature is barren.
# William Blake
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

SQL::Translator.

=cut
