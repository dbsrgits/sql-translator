#!/usr/bin/perl
# vim: set ft=perl:
#
#

use strict;

use SQL::Translator;
use Test::More tests => 9;

sub silly_parser {
    my ($tr, $data) = @_;
    my $pargs = $tr->parser_args;

    my @fields = split /$pargs->{'delimiter'}/, $data;

    my $schema = $tr->schema;
    my $table  = $schema->add_table( name => 'foo') or die $schema->error;
    for my $value ( @fields ) {
        my $field = $table->add_field( name => $value ) or die $table->error;
    }

    return 1;
}

# The "data" to be parsed
my $data = q(Id|Name|Phone Number|Favorite Flavor|);

my $tr = SQL::Translator->new;

# Pass parser_args as an explicit method call
$tr->parser(\&silly_parser);
$tr->parser_args(delimiter => '\|');

my $pargs  = $tr->parser_args;
$tr->translate(\$data);
my $schema = $tr->schema;

is($pargs->{'delimiter'}, '\|', "parser_args works when called directly");
my @tables = $schema->get_tables;
is(scalar @tables, 1, "right number of tables");
my $table = shift @tables;
my @fields = $table->get_fields;
is(scalar @fields, 4, "right number of fields");

#
# Blow away the existing schema object.
#
$tr->schema (undef);

# Now, pass parser_args indirectly...
$tr->parser(\&silly_parser, { delimiter => "\t" });
$data =~ s/\|/\t/g;

$pargs = $tr->parser_args;
$tr->translate(\$data);

is($pargs->{'delimiter'}, "\t",
    "parser_args works when called indirectly");

@tables = $schema->get_tables;
is(scalar @tables, 1, "right number of tables");
$table = shift @tables;
@fields = $table->get_fields;
is(scalar @fields, 4, "right number of fields");

undef $tr;
$tr = SQL::Translator->new(parser => \&silly_parser,
                           parser_args => { delimiter => ":" });
$data =~ s/\t/:/g;
$pargs = $tr->parser_args;
$tr->translate(\$data);

is($pargs->{'delimiter'}, ":",
    "parser_args works when called as constructor arg");

@tables = $schema->get_tables;
is(scalar @tables, 1, "right number of tables");
$table = shift @tables;
@fields = $table->get_fields;
is(scalar @fields, 4, "right number of fields with new delimiter");
