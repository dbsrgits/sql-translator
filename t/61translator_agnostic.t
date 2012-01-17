#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use Test::SQL::Translator;
use FindBin qw/$Bin/;

BEGIN {
    maybe_plan(1, 'SQL::Translator::Parser::XML',
                  'SQL::Translator::Producer::XML');
}

use SQL::Translator;

# Producing a schema with a Translator different from the one the schema was
# generated should just work. After all the $schema object is just data.


my $base_file = "$Bin/data/xml/schema.xml";
my $base_t = SQL::Translator->new;
$base_t->$_ (1) for qw/add_drop_table no_comments/;

# create a base schema attached to $base_t
my $base_schema = $base_t->translate (
  parser => 'XML',
  file => $base_file,
) or die $base_t->error;

# now create a new translator and try to feed it the same schema
my $new_t = SQL::Translator->new;
$new_t->$_ (1) for qw/add_drop_table no_comments/;

my $sql = $new_t->translate (
  data => $base_schema,
  producer => 'SQLite'
);

TODO: {
  local $TODO = 'This will probably not work before the rewrite';

  like (
    $sql,
    qr/^\s*CREATE TABLE/m,  #assume there is at least one create table statement
    "Received some meaningful output from the producer",
  );
}
