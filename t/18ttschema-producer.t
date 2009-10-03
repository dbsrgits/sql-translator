#!/usr/bin/perl -w 
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use Test::More;
use Test::Exception;
use Test::SQL::Translator qw(maybe_plan);

use Data::Dumper;
use FindBin qw/$Bin/;

# Testing 1,2,3,4...
#=============================================================================

BEGIN {
    maybe_plan(6,
        'SQL::Translator::Parser::XML::SQLFairy',
        'Template 2.20',
        'Test::Differences'
    );
}
use Test::Differences;

use SQL::Translator;
use SQL::Translator::Producer::TTSchema;

# Main test. Template whole schema and test tt_vars
{
    my $obj;
    $obj = SQL::Translator->new(
        show_warnings  => 0,
        from           => "XML-SQLFairy",
        filename       => "$Bin/data/xml/schema.xml",
        to             => "TTSchema",
        producer_args  => {
            ttfile  => "$Bin/data/template/basic.tt",
            tt_vars => {
                foo   => 'bar',
                hello => 'world',
            },
        },
    );
    my $out;
    lives_ok { $out = $obj->translate; }  "Translate ran";
    ok $out ne ""                        ,"Produced something!";
    local $/ = undef; # slurp
    eq_or_diff $out, <DATA>              ,"Output looks right";
}

# Test passing of Template config
{
    my $tmpl = q{
    [%- FOREACH table = schema.get_tables %]
    Table: $table
    [%- END %]};
    my $obj;
    $obj = SQL::Translator->new(
        show_warnings  => 0,
        from           => "XML-SQLFairy",
        filename       => "$Bin/data/xml/schema.xml",
        to             => "TTSchema",
        producer_args  => {
            ttfile  => \$tmpl,
            tt_conf => {
                INTERPOLATE => 1,
            },
            tt_vars => {
                foo   => 'bar',
                hello => 'world',
            },
        },
    );
    my $out;
    lives_ok { $out = $obj->translate; }  "Translate ran";
    ok $out ne ""                        ,"Produced something!";
    local $/ = undef; # slurp
    eq_or_diff $out, q{
    Table: Basic
    Table: Another}
    ,"Output looks right";
}


__DATA__
Schema: 
Database: 

Foo: bar
Hello: world

Table: Basic
==========================================================================

Fields
    id
        data_type:             int
        size:                  10
        is_nullable:           0
        default_value:         
        is_primary_key:        1
        is_unique:             0
        is_auto_increment:     1
        is_foreign_key:        0
        foreign_key_reference: 
        is_valid:              1
        order:                 1
        table:                 Basic
    
    title
        data_type:             varchar
        size:                  100
        is_nullable:           0
        default_value:         hello
        is_primary_key:        0
        is_unique:             0
        is_auto_increment:     0
        is_foreign_key:        0
        foreign_key_reference: 
        is_valid:              1
        order:                 2
        table:                 Basic
    
    description
        data_type:             text
        size:                  0
        is_nullable:           1
        default_value:         
        is_primary_key:        0
        is_unique:             0
        is_auto_increment:     0
        is_foreign_key:        0
        foreign_key_reference: 
        is_valid:              1
        order:                 3
        table:                 Basic
    
    email
        data_type:             varchar
        size:                  500
        is_nullable:           1
        default_value:         
        is_primary_key:        0
        is_unique:             1
        is_auto_increment:     0
        is_foreign_key:        0
        foreign_key_reference: 
        is_valid:              1
        order:                 4
        table:                 Basic
    
    explicitnulldef
        data_type:             varchar
        size:                  0
        is_nullable:           1
        default_value:         
        is_primary_key:        0
        is_unique:             0
        is_auto_increment:     0
        is_foreign_key:        0
        foreign_key_reference: 
        is_valid:              1
        order:                 5
        table:                 Basic
    
    explicitemptystring
        data_type:             varchar
        size:                  0
        is_nullable:           1
        default_value:         
        is_primary_key:        0
        is_unique:             0
        is_auto_increment:     0
        is_foreign_key:        0
        foreign_key_reference: 
        is_valid:              1
        order:                 6
        table:                 Basic
    
    emptytagdef
        data_type:             varchar
        size:                  0
        is_nullable:           1
        default_value:         
        is_primary_key:        0
        is_unique:             0
        is_auto_increment:     0
        is_foreign_key:        0
        foreign_key_reference: 
        is_valid:              1
        order:                 7
        table:                 Basic
    
    another_id
        data_type:             int
        size:                  10
        is_nullable:           1
        default_value:         2
        is_primary_key:        0
        is_unique:             0
        is_auto_increment:     0
        is_foreign_key:        1
        foreign_key_reference: Another
        is_valid:              1
        order:                 8
        table:                 Basic
    
    timest
        data_type:             timestamp
        size:                  0
        is_nullable:           1
        default_value:         
        is_primary_key:        0
        is_unique:             0
        is_auto_increment:     0
        is_foreign_key:        0
        foreign_key_reference: 
        is_valid:              1
        order:                 9
        table:                 Basic
    

Indices
    titleindex
        table:    Basic
        fields:   title
        type:     NORMAL
        options:  
        is_valid: 1
    
    
Constraints
    ?
        type:             PRIMARY KEY
        fields:           id
        expression:       
        match_type:       
        reference_fields: 
        reference_table:  
        deferrable:       1
        on_delete:        
        on_update:        
        options:          
        is_valid:         1
    
    emailuniqueindex
        type:             UNIQUE
        fields:           email
        expression:       
        match_type:       
        reference_fields: 
        reference_table:  
        deferrable:       1
        on_delete:        
        on_update:        
        options:          
        is_valid:         1
    
    ?
        type:             FOREIGN KEY
        fields:           another_id
        expression:       
        match_type:       
        reference_fields: id
        reference_table:  Another
        deferrable:       1
        on_delete:        
        on_update:        
        options:          
        is_valid:         1
    
Table: Another
==========================================================================

Fields
    id
        data_type:             int
        size:                  10
        is_nullable:           0
        default_value:         
        is_primary_key:        1
        is_unique:             0
        is_auto_increment:     1
        is_foreign_key:        0
        foreign_key_reference: 
        is_valid:              1
        order:                 1
        table:                 Another
    
    num
        data_type:             numeric
        size:                  10,2
        is_nullable:           1
        default_value:         
        is_primary_key:        0
        is_unique:             0
        is_auto_increment:     0
        is_foreign_key:        0
        foreign_key_reference: 
        is_valid:              1
        order:                 2
        table:                 Another
    

Indices
    
Constraints
    ?
        type:             PRIMARY KEY
        fields:           id
        expression:       
        match_type:       
        reference_fields: 
        reference_table:  
        deferrable:       1
        on_delete:        
        on_update:        
        options:          
        is_valid:         1
    
