#!/usr/bin/perl -w 
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;
use Test::More;
use Test::Exception;

use Data::Dumper;
use vars '%opt';
BEGIN { map { $opt{$_}=1 if s/^-// } @ARGV; }
use constant DEBUG => (exists $opt{d} ? 1 : 0);
local $SIG{__WARN__} = sub { diag "[warn] ", @_; };

use FindBin qw/$Bin/;

# Testing 1,2,3,4...
#=============================================================================

eval { require Template; };
if ($@ && $@ =~ m!locate Template.pm in!) {
    plan skip_all => "You need Template Toolkit to run this test.";
}
eval { require Test::Differences; };
if ($@ && $@ =~ m!locate Test/Differences.pm in!) {
    plan skip_all => "You need Test::Differences for this test.";
}
use Test::Differences;
plan tests => 3;
    
use SQL::Translator;
use SQL::Translator::Producer::TTSchema;

# Parse the test XML schema
my $obj;
$obj = SQL::Translator->new(
    debug          => DEBUG, #$opt{d},
    show_warnings  => 1,
    add_drop_table => 1,
    from           => "XML-SQLFairy",
    filename       => "$Bin/data/xml/schema-basic.xml",
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
# I'm not sure if this diff is the best test, it is probaly too sensitive. But 
# it at least it will blow up if anything changes!

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
        extra:                 
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
        extra:                 
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
        extra:                 
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
        extra:                 
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
        extra:                 
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
        extra:                 
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
        extra:                 
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
    
