package SQL::Translator::Parser::YAML;

# -------------------------------------------------------------------
# $Id: YAML.pm,v 1.1 2003-10-08 16:33:13 dlc Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 darren chamberlain <darren@cpan.org>,
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
$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;

use SQL::Translator::Schema;
use SQL::Translator::Utils qw(header_comment);
use YAML;

sub parse {
    my ($translator, $data) = @_;
    my $schema = $translator->schema;
    my $data = Load($data);

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

Darren Chamberlain E<lt>darren@cpan.orgE<gt>
