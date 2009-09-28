#!/usr/bin/perl -w
# vim:filetype=perl

#=============================================================================
# Test Package based filters that oks when called.
package SQL::Translator::Filter::Ok;
use strict;

sub filter { Test::More::pass(@_) }

# Hack to allow sqlt to see our module as it wasn't loaded from a .pm
$INC{'SQL/Translator/Filter/Ok.pm'} = 'lib/SQL/Translator/Filter/Ok.pm';

#=============================================================================
# SQL::Translator::Filter::HelloWorld - Test filter in a package
package   # hide from cpan
    SQL::Translator::Filter::HelloWorld;

use strict;

sub filter {
    my ($schema,%args) = (shift,@_);

    my $greeting = $args{greeting} || "Hello";
    my $newtable = "${greeting}World";
    $schema->add_table( name => $newtable );
}

# Hack to allow sqlt to see our module as it wasn't loaded from a .pm
$INC{'SQL/Translator/Filter/HelloWorld.pm'}
    = 'lib/SQL/Translator/Filter/HelloWorld.pm';

#=============================================================================

package main;

use strict;
use Test::More;
use Test::Exception;
use Test::SQL::Translator qw(maybe_plan);

use Data::Dumper;

BEGIN {
    maybe_plan(16, 'Template 2.20', 'Test::Differences',
               'SQL::Translator::Parser::YAML',
              'SQL::Translator::Producer::YAML')

}
use Test::Differences;
use SQL::Translator;

my $in_yaml = qq{--- #YAML:1.0
schema:
  tables:
    person:
      name: person
      fields:
        first_name:
          data_type: foovar
          name: First_Name
};

my $sqlt_version = $SQL::Translator::VERSION;
my $ans_yaml = qq{---
schema:
  procedures: {}
  tables:
    GdayWorld:
      constraints: []
      fields: {}
      indices: []
      name: GdayWorld
      options: []
      order: 3
    HelloWorld:
      constraints: []
      fields: {}
      indices: []
      name: HelloWorld
      options: []
      order: 2
    PERSON:
      constraints: []
      fields:
        first_name:
          data_type: foovar
          default_value: ~
          is_nullable: 1
          is_primary_key: 0
          is_unique: 0
          name: first_name
          order: 1
          size:
            - 0
      indices: []
      name: PERSON
      options: []
      order: 1
  triggers: {}
  views: {}
translator:
  add_drop_table: 0
  filename: ~
  no_comments: 0
  parser_args: {}
  parser_type: SQL::Translator::Parser::YAML
  producer_args: {}
  producer_type: SQL::Translator::Producer::YAML
  show_warnings: 1
  trace: 0
  version: $sqlt_version
};

# Parse the test XML schema
my $obj;
$obj = SQL::Translator->new(
    debug          => 0,
    show_warnings  => 1,
    parser         => "YAML",
    data           => $in_yaml,
    to             => "YAML",
    filters => [
        # Check they get called ok
        sub {
            pass("Filter 1 called");
            isa_ok($_[0],"SQL::Translator::Schema", "Filter 1, arg0 ");
            is( $#_, 0, "Filter 1, got no args");
        },
        sub {
            pass("Filter 2 called");
            isa_ok($_[0],"SQL::Translator::Schema", "Filter 2, arg0 ");
            is( $#_, 0, "Filter 2, got no args");
        },

        # Sub filter with args
        [ sub {
            pass("Filter 3 called");
            isa_ok($_[0],"SQL::Translator::Schema", "Filter 3, arg0 ");
            is( $#_, 2, "Filter 3, go 2 args");
            is( $_[1], "hello", "Filter 3, arg1=hello");
            is( $_[2], "world", "Filter 3, arg2=world");
        },
        hello => "world" ],

        # Uppercase all the table names.
        sub {
            my $schema = shift;
            foreach ($schema->get_tables) {
                $_->name(uc $_->name);
            }
        },

        # lowercase all the field names.
        sub {
            my $schema = shift;
            foreach ( map { $_->get_fields } $schema->get_tables ) {
                $_->name(lc $_->name);
            }
        },

        # Filter from SQL::Translator::Filter::*
        'Ok',
        [ 'HelloWorld' ],
        [ 'HelloWorld', greeting => 'Gday' ],
    ],

) or die "Failed to create translator object: ".SQL::Translator->error;

my $out;
lives_ok { $out = $obj->translate; }  "Translate ran";
is $obj->error, ''                   ,"No errors";
ok $out ne ""                        ,"Produced something!";
eq_or_diff $out, $ans_yaml           ,"Output looks right";
