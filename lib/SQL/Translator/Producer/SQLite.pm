package SQL::Translator::Producer::SQLite;

# -------------------------------------------------------------------
# $Id: SQLite.pm,v 1.3 2003-04-25 11:47:25 dlc Exp $
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
use Data::Dumper;
use SQL::Translator::Utils qw(debug header_comment);

use vars qw[ $VERSION $DEBUG $WARN ];

$VERSION = sprintf "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/;
$DEBUG = 0 unless defined $DEBUG;
$WARN = 0 unless defined $WARN;

my %used_identifiers = ();
my $max_id_length    = 30;
my %global_names;
my %truncated;

sub produce {
    my ($translator, $data) = @_;
    local $DEBUG            = $translator->debug;
    local $WARN             = $translator->show_warnings;
    my $no_comments         = $translator->no_comments;
    my $add_drop_table      = $translator->add_drop_table;

    debug("PKG: Beginning production\n");

    my $create = ''; 
    $create .= header_comment unless ($no_comments);

    for my $table ( keys %{ $data } ) {
        debug("PKG: Looking at table '$table'\n");
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
        $create .= qq[DROP TABLE $table;\n] if $add_drop_table;
        $create .= "CREATE TABLE $table (";

        #
        # Fields
        #
        for (my $i = 0; $i <= $#fields; $i++) {
            my $field = $fields[$i];
            debug("PKG: Looking at field '$field'\n");
            my $field_data = $table_data->{'fields'}->{$field};
            my @fdata = ("", $field);
            $create .= "\n";
            my $is_autoinc = 0;

            # data type and size
            my $data_type = lc $field_data->{'data_type'};
            my $list      = $field_data->{'list'} || [];
            my $commalist = join ",", @$list;
            my $size;

            if ( $data_type eq 'set' ) {
                $data_type = 'varchar';
                $size      = length $commalist;
            }
            else {
                $size = join( ', ', @{ $field_data->{'size'} || [] } );
            }

            # SQLite is generally typeless, but newer versions will
            # make a field autoincrement if it is declared as (and
            # *only* as) INTEGER PRIMARY KEY
            if ($field_data->{'is_auto_inc'}) {
                $data_type = 'INTEGER PRIMARY KEY';
                $is_autoinc = 1;
            }

            push @fdata, sprintf "%s%s", $data_type, (!$is_autoinc && $size) ? "($size)" : '';

            # MySQL qualifiers
#            for my $qual ( qw[ binary unsigned zerofill ] ) {
#                push @fdata, $qual 
#                    if $field_data->{ $qual } ||
#                       $field_data->{ uc $qual };
#            }

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


            $create .= (join " ", '', @fdata);
            $create .= "," unless ($i == $#fields);
        }
        #
        # Indices
        #
        my @index_creates;
        my $idx_name_default = 'A';
        for my $index ( @{ $table_data->{'indices'} || [] } ) {
            my ($name, $type, $fields) = @{ $index }{ qw[ name type fields ] };
            $name ||= '';
            my $index_type = $type eq 'unique' ? 'UNIQUE INDEX'  : 'INDEX';
            $name = mk_name($table, $name || ++$idx_name_default);
            push @index_creates, 
                "CREATE $index_type $name on $table ".
                '(' . join( ', ', @$fields ) . ')';
        }

        $create .= "\n);\n";

        for my $index_create ( @index_creates ) {
            $create .= "$index_create;\n";
        }

        $create .= "\n";
    }

    return $create;
}


# -------------------------------------------------------------------
sub mk_name {
    my ($basename, $type, $scope, $critical) = @_;
    my $basename_orig = $basename;
    my $max_name      = $type 
                        ? $max_id_length - (length($type) + 1) 
                        : $max_id_length;
    $basename         = substr( $basename, 0, $max_name ) 
                        if length( $basename ) > $max_name;
    my $name          = $type ? "${type}_$basename" : $basename;

    if ( $basename ne $basename_orig and $critical ) {
        my $show_type = $type ? "+'$type'" : "";
        warn "Truncating '$basename_orig'$show_type to $max_id_length ",
            "character limit to make '$name'\n" if $WARN;
        $truncated{ $basename_orig } = $name;
    }

    $scope ||= \%global_names;
    if ( my $prev = $scope->{ $name } ) {
        my $name_orig = $name;
        $name        .= sprintf( "%02d", ++$prev );
        substr($name, $max_id_length - 3) = "00" 
            if length( $name ) > $max_id_length;

        warn "The name '$name_orig' has been changed to ",
             "'$name' to make it unique.\n" if $WARN;

        $scope->{ $name_orig }++;
    }

    $scope->{ $name }++;
    return $name;
}

1;
__END__

=head1 NAME

SQL::Translator::Producer::SQLite - SQLite-specific producer for SQL::Translator

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>
