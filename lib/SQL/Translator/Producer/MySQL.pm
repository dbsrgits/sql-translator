package SQL::Translator::Producer::MySQL;

#-----------------------------------------------------
# $Id: MySQL.pm,v 1.2 2002-03-29 13:08:19 dlc Exp $
#-----------------------------------------------------
# Copyright (C) 2002 Ken Y. Clark <kycl4rk@users.sourceforge.net>,
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

sub import {
    warn "loading " . __PACKAGE__ . "...\n";
}

sub produce {
    my ($translator, $data) = @_;
    debug("Beginning");
    my $create = sprintf 
"# ----------------------------------------------------------------------
# Created by %s
# Created on %s
# ----------------------------------------------------------------------\n\n",
        __PACKAGE__, scalar localtime;

    for my $table (keys %{$data}) {
        debug("Looking a '$table'");
        my $table_data = $data->{$table};
        my @fields = sort { $table_data->{'fields'}->{$a}->{'order'} <=>
                            $table_data->{'fields'}->{$b}->{'order'}
                          } keys %{$table_data->{'fields'}};

        # --------------------------------------------------------------
        # Header.  Should this look like what mysqldump produces?
        # --------------------------------------------------------------
        $create .=
"# ----------------------------------------------------------------------
# Table: $table
# ----------------------------------------------------------------------\n";
        $create .= "CREATE TABLE $table (";

        # --------------------------------------------------------------
        # Fields
        # --------------------------------------------------------------
        for (my $i = 0; $i <= $#fields; $i++) {
            my $field = $fields[$i];
            debug("Looking at field: $field");
            my $field_data = $table_data->{'fields'}->{$field};
            my @fdata = ("", $field);
            $create .= "\n";

            # data type and size
            push @fdata, sprintf "%s%s", $field_data->{'data_type'},
                                         ($field_data->{'size'}) ?
                                        "($field_data->{'size'})" : "";

            # Null?
            push @fdata, "NOT NULL" unless $field_data->{'null'};

            # Default?  XXX Need better quoting!
            if (my $default = $field_data->{'default'}) {
                if (int $default eq "$default") {
                    push @fdata, "DEFAULT $default";
                } else {
                    push @fdata, "DEFAULT '$default'";
                }
            }

            # auto_increment?
            push @fdata, "auto_increment" if $field_data->{'is_auto_inc'};

            # primary key?
            push @fdata, "PRIMARY KEY" if $field_data->{'is_primary_key'};


            $create .= (join " ", @fdata);
            $create .= "," unless ($i == $#fields);
        }

        # --------------------------------------------------------------
        # Other keys
        # --------------------------------------------------------------
        my @indeces = @{$table_data->{'indeces'}};
        for (my $i = 0; $i <= $#indeces; $i++) {
            $create .= ",\n";
            my $key = $indeces[$i];
            my ($name, $type, $fields) = @{$key}{qw(name type fields)};
            if ($type eq "primary_key") {
                $create .= " PRIMARY KEY (@{$fields})"
            } else {
                local $" = ", ";
                $create .= " KEY $name (@{$fields})"
            }
        }

        # --------------------------------------------------------------
        # Footer
        # --------------------------------------------------------------
        $create .= "\n)";
        $create .= " TYPE=$table_data->{'type'}"
            if defined $table_data->{'type'};
        $create .= ";\n\n";
    }

    # Global footer (with a vim plug)
    $create .= "#
#
# vim: set ft=sql:
";

    return $create;
}

use Carp;
sub debug {
    if ($DEBUG) {
        map { carp "[" . __PACKAGE__ . "] $_" } @_;
    }
}

1;
__END__

=head1 NAME

SQL::Translator::Producer::MySQL - mysql-specific producer for SQL::Translator


=head1 AUTHOR

darren chamberlain E<lt>darren@cpan.orgE<gt>
