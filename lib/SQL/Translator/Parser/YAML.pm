package SQL::Translator::Parser::YAML;

# -------------------------------------------------------------------
# $Id: YAML.pm,v 1.3 2003-10-09 21:48:55 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 darren chamberlain <darren@cpan.org>,
#   Ken Y. Clark <kclark@cpan.org>.
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
use vars qw($VERSION);
$VERSION = sprintf "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/;

use SQL::Translator::Schema;
use SQL::Translator::Utils qw(header_comment);
use Data::Dumper;
use YAML qw(Load);

sub parse {
    my ($translator, $data) = @_;
    $data = Load($data);
    $data = $data->{'schema'};

    warn Dumper( $data ) if $translator->debug;

    my $schema = $translator->schema;

    #
    # Tables
    #
    my @tables = 
        map   { $data->{'tables'}{ $_->[1] } }
        sort  { $a->[0] <=> $b->[0] }
        map   { [ $data->{'tables'}{ $_ }{'order'}, $_ ] }
        keys %{ $data->{'tables'} }
    ;

    for my $tdata ( @tables ) {
        my $table = $schema->add_table(
            name  => $tdata->{'name'},
        ) or die $schema->error;

        my @fields = 
            map   { $tdata->{'fields'}{ $_->[1] } }
            sort  { $a->[0] <=> $b->[0] }
            map   { [ $tdata->{'fields'}{ $_ }{'order'}, $_ ] }
            keys %{ $tdata->{'fields'} }
        ;

        for my $fdata ( @fields ) {
            $table->add_field( %$fdata ) or die $table->error;
            $table->primary_key( $fdata->{'name'} ) 
                if $fdata->{'is_primary_key'};
        }
    }

    #
    # Views
    #
    my @views = 
        map   { $data->{'views'}{ $_->[1] } }
        sort  { $a->[0] <=> $b->[0] }
        map   { [ $data->{'views'}{ $_ }{'order'}, $_ ] }
        keys %{ $data->{'views'} }
    ;

    for my $vdata ( @views ) {
        $schema->add_view( %$vdata ) or die $schema->error;
    }

    #
    # Triggers
    #
    my @triggers = 
        map   { $data->{'triggers'}{ $_->[1] } }
        sort  { $a->[0] <=> $b->[0] }
        map   { [ $data->{'triggers'}{ $_ }{'order'}, $_ ] }
        keys %{ $data->{'triggers'} }
    ;

    for my $tdata ( @triggers ) {
        $schema->add_trigger( %$tdata ) or die $schema->error;
    }

    #
    # Procedures
    #
    my @procedures = 
        map   { $data->{'procedures'}{ $_->[1] } }
        sort  { $a->[0] <=> $b->[0] }
        map   { [ $data->{'procedures'}{ $_ }{'order'}, $_ ] }
        keys %{ $data->{'procedures'} }
    ;

    for my $tdata ( @procedures ) {
        $schema->add_procedure( %$tdata ) or die $schema->error;
    }

    return 1;
}

1;

__END__

=head1 NAME

SQL::Translator::Parser::YAML - Parse a YAML representation of a schema

=head1 SYNOPSIS

    use SQL::Translator;

    my $translator = SQL::Translator->new(parser => "YAML");

=head1 DESCRIPTION

C<SQL::Translator::Parser::YAML> parses a schema serialized with YAML.

=head1 AUTHOR

Darren Chamberlain E<lt>darren@cpan.orgE<gt>,
Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.
