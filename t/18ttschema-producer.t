#!/usr/bin/perl -w 
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use Test::More;
use Test::Exception;
use Test::SQL::Translator qw(maybe_plan);

use Data::Dumper;
use vars '%opt';
BEGIN { map { $opt{$_}=1 if s/^-// } @ARGV; }
use constant DEBUG => (exists $opt{d} ? 1 : 0);

use FindBin qw/$Bin/;

# Testing 1,2,3,4...
#=============================================================================

BEGIN {
    maybe_plan(3, 'Template', 'Test::Differences')
}
use Test::Differences;

use SQL::Translator;
use SQL::Translator::Producer::TTSchema;

# Parse the test XML schema
my $obj;
$obj = SQL::Translator->new(
    debug          => DEBUG, #$opt{d},
    show_warnings  => 1,
    add_drop_table => 1,
    from           => "XML-SQLFairy",
    filename       => "$Bin/data/xml/schema.xml",
    to             => "TTSchema",
     producer_args  => {
        ttfile => "$Bin/data/template/basic.tt",
    },
);
my $out;
lives_ok { $out = $obj->translate; }  "Translate ran";
ok $out ne ""                        ,"Produced something!";
local $/ = undef; # slurp
eq_or_diff $out, <DATA>              ,"Output looks right";

print $out if DEBUG;
#print "Debug:", Dumper($obj) if DEBUG;

__DATA__
Schema: 
Database: 

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
        size:                  255
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
    
