#!/usr/bin/perl
# vim: set ft=perl:
#
#

use strict;

use SQL::Translator;
use Test::More tests => 6;

sub silly_parser {
    my ($tr, $data) = @_;
    my $pargs = $tr->parser_args;

    my @fields = split /$pargs->{'delimiter'}/, $data;

    return \@fields;
}

# The "data" to be parsed
my $data = q(Id|Name|Phone Number|Favorite Flavor|);

my $tr = SQL::Translator->new;

# Pass parser_args as an explicit method call
$tr->parser(\&silly_parser);
$tr->parser_args(delimiter => '\|');

my $pargs = $tr->parser_args;
my $parsed = $tr->translate(\$data);

is($pargs->{'delimiter'}, '\|',
    "parser_args works when called directly");
is(scalar @{$parsed}, 4,
    "right number of fields");

# Now, pass parser_args indirectly...
$tr->parser(\&silly_parser, { delimiter => "\t" });
$data =~ s/\|/\t/g;

$pargs = $tr->parser_args;
$parsed = $tr->translate(\$data);

is($pargs->{'delimiter'}, "\t",
    "parser_args works when called indirectly");

is(scalar @{$parsed}, 4,
    "right number of fields with new delimiter");

undef $tr;
$tr = SQL::Translator->new(parser => \&silly_parser,
                           parser_args => { delimiter => ":" });
$data =~ s/\t/:/g;
$pargs = $tr->parser_args;
$parsed = $tr->translate(\$data);

is($pargs->{'delimiter'}, ":",
    "parser_args works when called as constructor arg");

is(scalar @{$parsed}, 4,
    "right number of fields with new delimiter");

