package SQL::Translator::Utils;

# ----------------------------------------------------------------------
# $Id: Utils.pm,v 1.1 2003-03-12 14:17:11 dlc Exp $
# ----------------------------------------------------------------------
# Copyright (C) 2003 darren chamberlain <darren@cpan.org>
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
use base qw(Exporter);
use vars qw($VERSION @EXPORT_OK);

use Exporter;

$VERSION = 1.00;
@EXPORT_OK = ('debug');

# ----------------------------------------------------------------------
# debug(@msg)
#
# Will send debugging messages to STDERR, if the caller's $DEBUG global
# is set.
#
# This debug() function has a neat feature: Occurances of the strings
# PKG, LINE, and SUB in each message will be replaced with elements
# from caller():
#
#   debug("PKG: Bad things happened on line LINE!");
#
# Will be warned as:
#
#   [SQL::Translator: Bad things happened on line 643]
#
# If called from Translator.pm, on line 643.
# ----------------------------------------------------------------------
sub debug {
    my ($pkg, $file, $line, $sub) = caller(1);
    {
        no strict qw(refs);
        return unless ${"$pkg\::DEBUG"};
    }

    $sub =~ s/^$pkg\:://;

    while (@_) {
        my $x = shift;
        chomp $x;
        $x =~ s/\bPKG\b/$pkg/g;
        $x =~ s/\bLINE\b/$line/g;
        $x =~ s/\bSUB\b/$sub/g;
        #warn '[' . $x . "]\n";
        print STDERR '[' . $x . "]\n";
    }
}

1;

__END__

=head1 NAME

SQL::Translator::Utils - SQL::Translator Utility functions

=head1 SYNOPSIS

  use SQL::Translator::Utils qw(debug);
  debug("PKG: Bad things happened");

=head1 DESCSIPTION

C<SQL::Translator::Utils> contains utility functions designed to be
used from the other modules within the C<SQL::Translator> modules.

No functions are exported by default.

=head1 EXPORTED FUNCTIONS

=head2 debug

C<debug> takes 0 or more messages, which will be sent to STDERR using
C<warn>.  Occurances of the strings I<PKG>, I<SUB>, and I<LINE>
will be replaced by the calling package, subroutine, and line number,
respectively, as reported by C<caller(1)>.  

For example, from within C<foo> in F<SQL/Translator.pm>, at line 666:

  debug("PKG: Error reading file at SUB/LINE");

Will warn

  [SQL::Translator: Error reading file at foo/666]

The entire message is enclosed within C<[> and C<]> for visual clarity
when STDERR is intermixed with STDOUT.
