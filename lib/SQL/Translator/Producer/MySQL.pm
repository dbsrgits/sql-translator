package SQL::Translator::Producer::MySQL;

# -------------------------------------------------------------------
# $Id: MySQL.pm,v 1.7 2003-02-26 05:17:49 kycl4rk Exp $
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

use strict;
use vars qw[ $VERSION $DEBUG ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 1 unless defined $DEBUG;

use Data::Dumper;

sub import {
    warn "loading " . __PACKAGE__ . "...\n";
}

sub produce {
    my ($translator, $data) = @_;
    $DEBUG                  = $translator->debug;
    my $no_comments         = $translator->no_comments;

    debug("Beginning production\n");

    my $create; 
    unless ( $no_comments ) {
        $create .= sprintf "--\n-- Created by %s\n-- Created on %s\n--\n\n",
            __PACKAGE__, scalar localtime;
    }

    for my $table (keys %{$data}) {
        debug("Looking at table '$table'\n");
        my $table_data = $data->{$table};
        my @fields = sort { 
            $table_data->{'fields'}->{$a}->{'order'} 
            <=>
            $table_data->{'fields'}->{$b}->{'order'}
        } keys %{$table_data->{'fields'}};

        #
        # Header.  Should this look like what mysqldump produces?
        #
        $create .= "--\n-- Table: $table\n--\n" unless $no_comments;
        $create .= "CREATE TABLE $table (";

        #
        # Fields
        #
        for (my $i = 0; $i <= $#fields; $i++) {
            my $field = $fields[$i];
            debug("Looking at field '$field'\n");
            my $field_data = $table_data->{'fields'}->{$field};
            my @fdata = ("", $field);
            $create .= "\n";

            # data type and size
            my $attr = uc $field_data->{'data_type'} eq 'SET' ? 'list' : 'size';
            my @values = @{ $field_data->{ $attr } || [] };
            push @fdata, sprintf "%s%s", 
                $field_data->{'data_type'},
                ( @values )
                    ? '('.join(', ', @values).')'
                    : '';

            # MySQL qualifiers
            for my $qual ( qw[ binary unsigned zerofill ] ) {
                push @fdata, $qual 
                    if $field_data->{ $qual } ||
                       $field_data->{ uc $qual };
            }

            # Null?
            push @fdata, "NOT NULL" unless $field_data->{'null'};

            # Default?  XXX Need better quoting!
            my $default = $field_data->{'default'};
            if ( defined $default ) {
                if ( uc $default eq 'NULL') {
                    push @fdata, "DEFAULT NULL";
                } else {
                    push @fdata, "DEFAULT '$default'";
                }
            }

            # auto_increment?
            push @fdata, "auto_increment" if $field_data->{'is_auto_inc'};

            # primary key?
            # This is taken care of in the indices, could be duplicated here
            # push @fdata, "PRIMARY KEY" if $field_data->{'is_primary_key'};


            $create .= (join " ", '', @fdata);
            $create .= "," unless ($i == $#fields);
        }

        #
        # Indices
        #
        my @index_creates;
        my @indices = @{ $table_data->{'indices'} || [] };
        for (my $i = 0; $i <= $#indices; $i++) {
            my $key  = $indices[$i];
            my ($name, $type, $fields) = @{ $key }{ qw[ name type fields ] };
            $name ||= '';
            my $index_type = 
                $type eq 'primary_key' ? 'PRIMARY KEY' :
                $type eq 'unique'      ? 'UNIQUE KEY'  : 'KEY';
            push @index_creates, 
                "  $index_type $name (" . join( ', ', @$fields ) . ')';
        }

        if ( @index_creates ) {
            $create .= join(",\n", '', @index_creates);
        }

        #
        # Constraints -- need to handle more than just FK. -ky
        #
        my @constraints;
        for my $constraint ( @{ $table_data->{'constraints'} } ) {
            my $name       = $constraint->{'name'} || '';
            my $type       = $constraint->{'type'};
            my $fields     = $constraint->{'fields'};
            my $ref_table  = $constraint->{'reference_table'};
            my $ref_fields = $constraint->{'reference_fields'};
            my $match_type = $constraint->{'match_type'} || '';
            my $on_delete  = $constraint->{'on_delete_do'};
            my $on_update  = $constraint->{'on_update_do'};

            if ( $type eq 'foreign_key' ) {
                my $def = join(' ', map { $_ || () } '  FOREIGN KEY', $name );
                if ( @$fields ) {
                    $def .= ' (' . join( ', ', @$fields ) . ')';
                }
                $def .= " REFERENCES $ref_table";

                if ( @$ref_fields ) {
                    $def .= ' (' . join( ', ', @$ref_fields ) . ')';
                }

                if ( $match_type ) {
                    $def .= ' MATCH ' . 
                        ( $match_type =~ /full/i ) ? 'FULL' : 'PARTIAL';
                }

                if ( @{ $on_delete || [] } ) {
                    $def .= ' ON DELETE '.join(' ', @$on_delete);
                }

                if ( @{ $on_update || [] } ) {
                    $def .= ' ON UPDATE '.join(' ', @$on_update);
                }

                push @constraints, $def;
            }
        }

        $create .= join(",\n", '', @constraints) if @constraints;

        #
        # Footer
        #
        $create .= "\n)";
        while ( my ( $key, $val ) = each %{ $table_data->{'table_options'} } ) {
            $create .= " $key=$val" 
        }
        $create .= ";\n\n";
    }

    return $create;
}

sub debug {
    if ($DEBUG) {
        map { warn "[" . __PACKAGE__ . "] $_" } @_;
    }
}

1;
__END__

=head1 NAME

SQL::Translator::Producer::MySQL - mysql-specific producer for SQL::Translator

=head1 AUTHOR

darren chamberlain E<lt>darren@cpan.orgE<gt>
