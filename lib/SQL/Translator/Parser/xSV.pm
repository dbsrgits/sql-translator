package SQL::Translator::Parser::xSV;

# -------------------------------------------------------------------
# $Id: xSV.pm,v 1.2 2002-11-20 04:03:04 kycl4rk Exp $
# -------------------------------------------------------------------
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
use vars qw($VERSION @EXPORT);
$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;

use Exporter;
use Text::ParseWords qw(quotewords);

use base qw(Exporter);
@EXPORT = qw(parse);

# Passed a SQL::Translator instance and a string containing the data
sub parse {
    my ($tr, $data) = @_;

    # Skeleton structure, mostly empty
    my $parsed = {
        table1 => {
            "type" => undef,
            "indices" => [ { } ],
            "fields" => { },
        },
    };

    # Discard all but the first line
    $data = (split m,$/,, $data)[0];

    my @parsed = quotewords(',\s*', 0, $data);

    for (my $i = 0; $i < @parsed; $i++) {
        $parsed->{"table1"}->{"fields"}->{$parsed[$i]} = {
            type           => "field",
            order          => $i,
            name           => $parsed[$i],

            # Default datatype is "char"
            data_type      => "char",

            # default size is 8bits; something more reasonable?
            size           => 255,
            null           => 1,
            default        => "",
            is_auto_inc    => undef,

            # field field is the primary key
            is_primary_key => ($i == 0) ? 1 : undef,
        }
    }

    # Field 0 is primary key, by default, so add an index
    for ($parsed->{"table1"}->{"indices"}->[0]) {
        $_->{"type"} = "primary_key";
        $_->{"name"} = undef;
        $_->{"fields"} = [ $parsed[0] ];
    }

    return $parsed;
}

1;
__END__
