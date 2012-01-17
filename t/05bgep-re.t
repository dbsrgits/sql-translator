#!/usr/bin/perl
# vim: set ft=perl:
#

use strict;

use File::Spec::Functions qw(catfile tmpdir);
use File::Temp qw(tempfile);
use FindBin qw($Bin);
use SQL::Translator;
use Test::More;
use Test::SQL::Translator qw(maybe_plan);

# This aggravates me; XML::Writer produces tons of warnings.
local $SIG{__WARN__} = sub {
    CORE::warn(@_)
        unless $_[0] =~ m#XML/Writer#;
};

BEGIN {
    maybe_plan(2,
        'SQL::Translator::Parser::MySQL',
        'SQL::Translator::Producer::XML::SQLFairy');
}

my @data = qw(data mysql BGEP-RE-create.sql);
my $test_data = (-d "t")
    ? catfile($Bin, @data)
    : catfile($Bin, "t", @data);

my $tr       =  SQL::Translator->new(
    parser   => 'MySQL',
    producer => 'XML-SQLFairy',
    filename => $test_data
);
my $data = $tr->translate;

ok($data, "MySQL->XML-SQLFairy");

SKIP: {
    eval {
        require XML::Parser;
    };
    if ($@) {
        skip "Can't load XML::Parser" => 1;
    }

    # Can't get XML::Parser::parsestring to do Useful Things
    my ($fh, $fname) = tempfile('sqlfXXXX',
                                UNLINK => 1,
                                SUFFIX => '.xml',
                                DIR => tmpdir);
    print $fh $data;
    $fh->close;

    ok(XML::Parser->new->parsefile($fname),
        "Successfully parsed output");
}
