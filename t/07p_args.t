#!/usr/bin/perl
# vim: set ft=perl:
#
#

BEGIN { print "1..6\n"; }

use strict;

use SQL::Translator;
$SQL::Translator::DEBUG = 0;

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

print "not " unless ($pargs->{'delimiter'} eq '\|');
print "ok 1 # parser_args works when called directly\n";

print "not " unless (scalar @{$parsed} == 4);
print "ok 2 # right number of fields\n";

# Now, pass parser_args indirectly...
$tr->parser(\&silly_parser, { delimiter => "\t" });
$data =~ s/\|/\t/g;

$pargs = $tr->parser_args;
$parsed = $tr->translate(\$data);

print "not " unless ($pargs->{'delimiter'} eq "\t");
print "ok 3 # parser_args works when called indirectly\n";

print "not " unless (scalar @{$parsed} == 4);
print "ok 4 # right number of fields with new delimiter\n";

undef $tr;
$tr = SQL::Translator->new(parser => \&silly_parser,
                           parser_args => { delimiter => ":" });
$data =~ s/\t/:/g;
$pargs = $tr->parser_args;
$parsed = $tr->translate(\$data);

print "not " unless ($pargs->{'delimiter'} eq ":");
print "ok 5 # parser_args works when called as constructor arg\n";

print "not " unless (scalar @{$parsed} == 4);
print "ok 6 # right number of fields with new delimiter\n";

