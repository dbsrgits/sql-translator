package SQL::Translator::Validator;

# ----------------------------------------------------------------------
# $Id: Validator.pm,v 1.5 2002-11-22 03:03:40 kycl4rk Exp $
# ----------------------------------------------------------------------
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
# ----------------------------------------------------------------------

use strict;
use vars qw($VERSION @EXPORT);
$VERSION = sprintf "%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/;

use Exporter;
use base qw(Exporter);
@EXPORT = qw(validate);

use Data::Dumper;

sub by_context($$$) { ($_[0]) ? ($_[1], $_[2]) : $_[1]; }

# XXX If called in scalar context, then validate should *not*
# genertate or return $log.  It's a lot of extra work if we know we
# are not going to use it.
sub validate {
    my $data = shift;
    my $wa = wantarray;
    my ($ok, $log);

    unless (ref $data) {
        return by_context $wa, 0, "Not a reference";
    }

    unless (UNIVERSAL::isa($data, "HASH")) {
        return by_context $wa, 0, "Not a HASH reference";
    } else {
        my $num = scalar keys %{$data};
        $log = sprintf "Contains %d table%s.", $num, ($num == 1 ? "" : "s");
    }

    my @tables = sort keys %{$data};
    for (my $i = 0; $i < @tables; $i++) {
        my $table = $tables[$i];
        my $table_num = $i + 1;

        $log .= "\nTable $table_num: $table";
        my $table_data = $data->{$table};

        # Table must be a hashref
        unless (UNIVERSAL::isa($table_data, "HASH")) {
            return by_context $wa, 0,
                "Table `$table' is not a HASH reference";
        }

        # Table must contain three elements: type, indices, and fields
        # XXX If there are other keys, is this an error?
        unless (exists $table_data->{"type"}) {
            return by_context $wa, 0, "Missing type for table `$table'";
        } else {
            $log .= sprintf "\n\tType: %s", $table_data->{"type"} ||
                "not defined";
        }

        # Indices: array of hashes
        unless (defined $table_data->{"indices"} &&
                UNIVERSAL::isa($table_data->{"indices"}, "ARRAY")) {
            return by_context $wa, 0, "Indices is missing or is not an ARRAY";
        } else {
            my @indices = @{$table_data->{"indices"}};
            $log .= "\n\tIndices:";
            if (@indices) {
                for my $index (@indices) {
                    $log .= "\n\t\t" . ($index->{"name"} || "(unnamed)")
                         .  " on "
                         .  join ", ", @{$index->{"fields"}};
                }
            } else {
                $log .= " none defined";
            }
        }

        # Fields
        unless (defined $table_data->{"fields"} &&
            UNIVERSAL::isa($table_data->{"fields"}, "HASH")) {
            return by_context $wa, 0, "Fields is missing or is not a HASH";
        } else {
            $log .= "\n\tFields:";
            my @fields = sort { $table_data->{$a}->{"order"} <=>
                                $table_data->{$b}->{"order"}
                              } keys %{$table_data->{"fields"}};
            for my $field (@fields) {
                my $field_data = $table_data->{"fields"}->{$field};
                $log .= qq|\n\t\t$field_data->{"name"}|
                     .  qq| $field_data->{"data_type"} ($field_data->{"size"})|;
                $log .= qq|\n\t\t\tDefault: $field_data->{"default"}|
                            if length $field_data->{"default"};
                $log .= sprintf qq|\n\t\t\tNull: %s|,
                            $field_data->{"null"} ? "yes" : "no";
            }
        }
    }

    $log .= "\n";

    return by_context $wa, 1, $log;
}


1;
__END__

=head1 NAME

SQL::Translator::Validate - Validate that a data structure is correct

=head1 SYNOPSIS

  print "1..1\n";

  use SQL::Translator;
  use SQL::Translator::Validator;

  my $tr = SQL::Translator->new(parser => "My::Swell::Parser");

  # Default producer passes the data structure through unchanged
  my $parsed = $tr->translate($datafile);

  print "not " unless validate($parsed);
  print "ok 1 # data structure looks OK\n";

=head1 DESCRIPTION

When writing a parser module for SQL::Translator, it is helpful to
have a tool to automatically check the return of your module, to make
sure that it is returning the Right Thing.  While only a full Producer
and the associated database can determine if you are producing valid
output, SQL::Translator::Validator can tell you if the basic format of
the data structure is correct.  While this will not catch many errors,
it will catch the basic ones.

SQL::Translator::Validator can be used as a development tool, a
testing tool (every SQL::Translator install will have this module),
or, potentially, even as a runtime assertion for producers you don't
trust:

  $tr->producer(\&paranoid_producer);
  sub paranoid_producer {
      my ($tr, $data) = @_;
      return unless validate($data);

      # continue...

SQL::Translator::Validator can also be used as a reporting tool.  When
B<validate> is called in a list context, the second value returned
(assuming the data structure is well-formed) is a summary of the
table's information.  For example, the following table definition
(MySQL format):

  CREATE TABLE random (
    id  int(11) not null default 1,
    seed char(32) not null default 1
  );

  CREATE TABLE session (
    foo char(255),
    id int(11) not null default 1 primary key
  ) TYPE=HEAP;

Produces the following summary:

    Contains 2 tables.
    Table 1: random
            Type: not defined
            Indices: none defined
            Fields:
                    id int (11)
                            Default: 1
                            Null: no
                    seed char (32)
                            Default: 1
                            Null: no
    Table 2: session
            Type: HEAP
            Indices:
                    (unnamed) on id
            Fields:
                    foo char (255)
                            Null: yes
                    id int (11)
                            Default: 1
                            Null: no


=head1 EXPORTED FUNCTIONS

SQL::Translator::Validator exports a single function, called
B<validate>, which expects a data structure as its only argument.
When called in scalar context, it returns a 1 (valid data structure)
or 0 (not a valid data structure).  In list context, B<validate>
returns a 2 element list: the first element is a 1 or 0, as in scalar
context, and the second value is a reason (for a malformed data
structure) or a summary of the data (for a well-formed data
structure).

=head1 TODO

=over 4

=item *

color, either via Term::ANSI, or something along those lines, or just
plain $RED = "\033[31m" type stuff.

=back

=head1 AUTHOR

darren chamberlain E<lt>darren@cpan.orgE<gt>
