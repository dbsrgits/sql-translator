#!/usr/local/bin/perl

use SQL::Translator::Validator;
my $data = {
    random => {
        type => undef,
        indices => [ ],
        fields => {
            id => {
                name => "id",
                data_type => "int",
                size => 11,
                order => 1,
                null => 0,
                default => 1
            },
            seed => {
                name => "seed",
                data_type => "char",
                size => 32,
                order => 2,
                null => 0,
                default => 1
            },

        }
    },
    session => {
        type => "HEAP",
        indices => [
            {
                name => undef,
                primary_key => 1,
                fields => [ "id" ],
            }
        ],
        fields => {
            id => {
                name => "id",
                data_type => "int",
                size => 11,
                order => 2,
                null => 0,
                default => 1
            },
            foo => {
                name => "foo",
                data_type => "char",
                size => 255,
                order => 1,
                null => 1
            },
        }
    }
};

my @r = validate($data);
printf "%s%s", $r[1], $r[0]? "" : "\n";
