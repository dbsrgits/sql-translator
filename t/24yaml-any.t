#!/usr/bin/perl
## no critic (BuiltinFunctions::ProhibitStringyEval)

use warnings;
use strict;

# This test will test all YAML libraries available in the system.
# It will read in a YAML file, parse it into a Schema object,
# then use the same Producer to create a YAML file.
# Then compare the start and end files.
# It will do this with all YAML libraries available
# and compare the end results in a matrix to verify all
# YAML libraries produce the same YAML file.

use Test::More;
use utf8;
use Encode;
use English;
use Test::SQL::Translator;

my @yaml_libs = qw(
    YAML::PP
    YAML::XS
    YAML
);


maybe_plan( undef, @yaml_libs );
my $yaml_perl = join q{}, <DATA>;
my $yaml_utf8 = Encode::encode('UTF-8', $yaml_perl, Encode::FB_CROAK);

my %results;

for my $package (@yaml_libs) {
    my $r_val = eval "require $package; 1";
    if(! $r_val ) {
        diag $EVAL_ERROR;
    }
    my %result;
    $result{package} = $package;
    my $cmd = "$package" . "::Load(\$yaml_utf8)";
    my $doc = eval "$cmd";
    $result{doc} = $doc;
    $cmd = "$package" . "::Dump(\$doc)";
    my $yaml = eval "$cmd";
    $result{yaml} = $yaml;
    $results{$package} = \%result;
}

my @packages = keys %results;
for my $i (0..@packages-1) {
    my $result1_package = $packages[$i];
    my $result1_doc = $results{ $result1_package }->{doc};
    my $result1_yaml = $results{ $result1_package }->{yaml};
    my $result2_package = $packages[ $i > @packages ? 0 : $i ];
    my $result2_doc = $results{ $result2_package }->{doc};
    my $result2_yaml = $results{ $result2_package }->{yaml};
    is_deeply($result1_doc, $result2_doc, "Doc loaded by $result1_package is equal to doc loaded by $result2_package");
    is_deeply($result1_yaml, $result2_yaml, "YAML dumped by $result1_package is equal to YAML dumped by $result2_package");
}

done_testing;

__DATA__
---
schema:
  procedures: {}
  tables:
    person:
      constraints:
        - deferrable: 1
          expression: ''
          fields:
            - person_id
          match_type: ''
          name: ''
          on_delete: ''
          on_update: ''
          options: []
          reference_fields: []
          reference_table: ''
          type: PRIMARY KEY
        - deferrable: 1
          expression: ''
          fields:
            - name
          match_type: ''
          name: u_name
          on_delete: ''
          on_update: ''
          options: []
          reference_fields: []
          reference_table: ''
          type: UNIQUE
      fields:
        age:
          data_type: integer
          default_value: ~
          is_nullable: 1
          is_primary_key: 0
          is_unique: 0
          name: age
          order: 3
          size:
            - 0
        description:
          data_type: text
          default_value: ~
          is_nullable: 1
          is_primary_key: 0
          is_unique: 0
          name: ääkkösåt
          order: 6
          size:
            - 0
        iq:
          data_type: tinyint
          default_value: 0
          is_nullable: 1
          is_primary_key: 0
          is_unique: 0
          name: iq
          order: 5
          size:
            - 0
        name:
          data_type: varchar
          default_value: ~
          is_nullable: 0
          is_primary_key: 0
          is_unique: 1
          name: name
          order: 2
          size:
            - 20
        person_id:
          comments:
            - field comment 1
            - field comment 2
          data_type: INTEGER
          default_value: ~
          is_auto_increment: 1
          is_nullable: 0
          is_primary_key: 1
          is_unique: 0
          name: person_id
          order: 1
          size:
            - 0
          extra:
            auto_increment_type: monotonic
        weight:
          data_type: double
          default_value: ~
          is_nullable: 1
          is_primary_key: 0
          is_unique: 0
          name: weight
          order: 4
          size:
            - 11
            - 2
      indices: []
      name: person
      options: []
      order: 1
      comments :
        - table comment 1
        - table comment 2
        - table comment 3
    pet:
      constraints:
        - deferrable: 1
          expression: ''
          fields: []
          match_type: ''
          name: ''
          on_delete: ''
          on_update: ''
          options: []
          reference_fields: []
          reference_table: ''
          type: CHECK
        - deferrable: 1
          expression: ''
          fields:
            - pet_id
            - person_id
          match_type: ''
          name: ''
          on_delete: ''
          on_update: ''
          options: []
          reference_fields: []
          reference_table: ''
          type: PRIMARY KEY
        - deferrable: 1
          expression: ''
          fields:
            - person_id
          match_type: ''
          name: ''
          on_delete: ''
          on_update: ''
          options: []
          reference_fields:
            - person_id
          reference_table: person
          type: FOREIGN KEY
      fields:
        age:
          data_type: int
          default_value: ~
          is_nullable: 1
          is_primary_key: 0
          is_unique: 0
          name: age
          order: 4
          size:
            - 0
        name:
          data_type: varchar
          default_value: ~
          is_nullable: 1
          is_primary_key: 0
          is_unique: 0
          name: name
          order: 3
          size:
            - 30
        person_id:
          data_type: int
          default_value: ~
          is_nullable: 0
          is_primary_key: 1
          is_unique: 0
          name: person_id
          order: 2
          size:
            - 0
        pet_id:
          data_type: int
          default_value: ~
          is_nullable: 0
          is_primary_key: 1
          is_unique: 0
          name: pet_id
          order: 1
          size:
            - 0
      indices: []
      name: pet
      options: []
      order: 2
  triggers:
    pet_trig:
      action:
        for_each: ~
        steps:
          - update pet set name=name
        when: ~
      database_events:
        - insert
      fields: ~
      name: pet_trig
      on_table: pet
      order: 1
      perform_action_when: after
      scope: row
  views:
    person_pet:
      fields: []
      name: person_pet
      order: 1
      sql: |
        select pr.person_id, pr.name as person_name, pt.name as pet_name
          from   person pr, pet pt
          where  person.person_id=pet.pet_id
