#!/usr/bin/perl -w 
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

local $^W = 0;

use strict;
use Test::More;
use Test::Exception;

use Data::Dumper;
my %opt;
BEGIN { map { $opt{$_}=1 if s/^-// } @ARGV; }
use constant DEBUG => (exists $opt{d} ? 1 : 0);
use constant TRACE => (exists $opt{t} ? 1 : 0);

use FindBin qw/$Bin/;

my $file = "$Bin/data/mysql/sqlfxml-producer-basic.sql";


# Testing 1,2,3,4...
#=============================================================================

eval { require XML::Writer; };
if ($@ && $@ =~ m!locate XML::Writer.pm in!) {
    plan skip_all => "You need XML::Writer to use XML::SQLFairy.";
}
eval { require Test::Differences; };
if ($@ && $@ =~ m!locate Test/Differences.pm in!) {
    plan skip_all => "You need Test::Differences for this test.";
}
use Test::Differences;
plan tests => 9;
    
use SQL::Translator;
use SQL::Translator::Producer::XML::SQLFairy;

my ($obj,$ans,$xml);

#
# emit_empty_tags => 0
#

$ans = <<EOXML;
<sqlt:schema xmlns:sqlt="http://sqlfairy.sourceforge.net/sqlfairy.xml">
  <sqlt:database></sqlt:database>
  <sqlt:name></sqlt:name>
  <sqlt:table>
    <sqlt:name>Basic</sqlt:name>
    <sqlt:order>1</sqlt:order>
    <sqlt:fields>
      <sqlt:field>
        <sqlt:comments>comment on id field</sqlt:comments>
        <sqlt:data_type>integer</sqlt:data_type>
        <sqlt:is_auto_increment>1</sqlt:is_auto_increment>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:is_nullable>0</sqlt:is_nullable>
        <sqlt:is_primary_key>1</sqlt:is_primary_key>
        <sqlt:name>id</sqlt:name>
        <sqlt:order>1</sqlt:order>
        <sqlt:size>10</sqlt:size>
      </sqlt:field>
      <sqlt:field>
        <sqlt:comments></sqlt:comments>
        <sqlt:data_type>varchar</sqlt:data_type>
        <sqlt:default_value>hello</sqlt:default_value>
        <sqlt:is_auto_increment>0</sqlt:is_auto_increment>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:is_nullable>0</sqlt:is_nullable>
        <sqlt:is_primary_key>0</sqlt:is_primary_key>
        <sqlt:name>title</sqlt:name>
        <sqlt:order>2</sqlt:order>
        <sqlt:size>100</sqlt:size>
      </sqlt:field>
      <sqlt:field>
        <sqlt:comments></sqlt:comments>
        <sqlt:data_type>text</sqlt:data_type>
        <sqlt:default_value></sqlt:default_value>
        <sqlt:is_auto_increment>0</sqlt:is_auto_increment>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:is_nullable>1</sqlt:is_nullable>
        <sqlt:is_primary_key>0</sqlt:is_primary_key>
        <sqlt:name>description</sqlt:name>
        <sqlt:order>3</sqlt:order>
        <sqlt:size>65535</sqlt:size>
      </sqlt:field>
      <sqlt:field>
        <sqlt:comments></sqlt:comments>
        <sqlt:data_type>varchar</sqlt:data_type>
        <sqlt:is_auto_increment>0</sqlt:is_auto_increment>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:is_nullable>1</sqlt:is_nullable>
        <sqlt:is_primary_key>0</sqlt:is_primary_key>
        <sqlt:name>email</sqlt:name>
        <sqlt:order>4</sqlt:order>
        <sqlt:size>255</sqlt:size>
      </sqlt:field>
    </sqlt:fields>
    <sqlt:indices>
      <sqlt:index>
        <sqlt:fields>title</sqlt:fields>
        <sqlt:name>titleindex</sqlt:name>
        <sqlt:options></sqlt:options>
        <sqlt:type>NORMAL</sqlt:type>
      </sqlt:index>
    </sqlt:indices>
    <sqlt:constraints>
      <sqlt:constraint>
        <sqlt:deferrable>1</sqlt:deferrable>
        <sqlt:expression></sqlt:expression>
        <sqlt:fields>id</sqlt:fields>
        <sqlt:match_type></sqlt:match_type>
        <sqlt:name></sqlt:name>
        <sqlt:on_delete></sqlt:on_delete>
        <sqlt:on_update></sqlt:on_update>
        <sqlt:options></sqlt:options>
        <sqlt:reference_table></sqlt:reference_table>
        <sqlt:type>PRIMARY KEY</sqlt:type>
      </sqlt:constraint>
      <sqlt:constraint>
        <sqlt:deferrable>1</sqlt:deferrable>
        <sqlt:expression></sqlt:expression>
        <sqlt:fields>email</sqlt:fields>
        <sqlt:match_type></sqlt:match_type>
        <sqlt:name></sqlt:name>
        <sqlt:on_delete></sqlt:on_delete>
        <sqlt:on_update></sqlt:on_update>
        <sqlt:options></sqlt:options>
        <sqlt:reference_table></sqlt:reference_table>
        <sqlt:type>UNIQUE</sqlt:type>
      </sqlt:constraint>
    </sqlt:constraints>
  </sqlt:table>
</sqlt:schema>
EOXML

$obj = SQL::Translator->new(
    debug          => DEBUG,
    trace          => TRACE,
    show_warnings  => 1,
    add_drop_table => 1,
    from           => 'MySQL',
    to             => 'XML-SQLFairy',
);
lives_ok {$xml = $obj->translate($file);} "Translate (emit_empty_tags=>0) ran";
ok("$xml" ne ""                             ,"Produced something!");
print "XML:\n$xml" if DEBUG;
# Strip sqlf header with its variable date so we diff safely
$xml =~ s/^([^\n]*\n){7}//m; 
eq_or_diff $xml, $ans                       ,"XML looks right";

#
# emit_empty_tags => 1
#

$ans = <<EOXML;
<sqlt:schema xmlns:sqlt="http://sqlfairy.sourceforge.net/sqlfairy.xml">
  <sqlt:database></sqlt:database>
  <sqlt:name></sqlt:name>
  <sqlt:table>
    <sqlt:name>Basic</sqlt:name>
    <sqlt:order>2</sqlt:order>
    <sqlt:fields>
      <sqlt:field>
        <sqlt:comments>comment on id field</sqlt:comments>
        <sqlt:data_type>integer</sqlt:data_type>
        <sqlt:default_value></sqlt:default_value>
        <sqlt:is_auto_increment>1</sqlt:is_auto_increment>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:is_nullable>0</sqlt:is_nullable>
        <sqlt:is_primary_key>1</sqlt:is_primary_key>
        <sqlt:name>id</sqlt:name>
        <sqlt:order>5</sqlt:order>
        <sqlt:size>10</sqlt:size>
      </sqlt:field>
      <sqlt:field>
        <sqlt:comments></sqlt:comments>
        <sqlt:data_type>varchar</sqlt:data_type>
        <sqlt:default_value>hello</sqlt:default_value>
        <sqlt:is_auto_increment>0</sqlt:is_auto_increment>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:is_nullable>0</sqlt:is_nullable>
        <sqlt:is_primary_key>0</sqlt:is_primary_key>
        <sqlt:name>title</sqlt:name>
        <sqlt:order>6</sqlt:order>
        <sqlt:size>100</sqlt:size>
      </sqlt:field>
      <sqlt:field>
        <sqlt:comments></sqlt:comments>
        <sqlt:data_type>text</sqlt:data_type>
        <sqlt:default_value></sqlt:default_value>
        <sqlt:is_auto_increment>0</sqlt:is_auto_increment>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:is_nullable>1</sqlt:is_nullable>
        <sqlt:is_primary_key>0</sqlt:is_primary_key>
        <sqlt:name>description</sqlt:name>
        <sqlt:order>7</sqlt:order>
        <sqlt:size>65535</sqlt:size>
      </sqlt:field>
      <sqlt:field>
        <sqlt:comments></sqlt:comments>
        <sqlt:data_type>varchar</sqlt:data_type>
        <sqlt:default_value></sqlt:default_value>
        <sqlt:is_auto_increment>0</sqlt:is_auto_increment>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:is_nullable>1</sqlt:is_nullable>
        <sqlt:is_primary_key>0</sqlt:is_primary_key>
        <sqlt:name>email</sqlt:name>
        <sqlt:order>8</sqlt:order>
        <sqlt:size>255</sqlt:size>
      </sqlt:field>
    </sqlt:fields>
    <sqlt:indices>
      <sqlt:index>
        <sqlt:fields>title</sqlt:fields>
        <sqlt:name>titleindex</sqlt:name>
        <sqlt:options></sqlt:options>
        <sqlt:type>NORMAL</sqlt:type>
      </sqlt:index>
    </sqlt:indices>
    <sqlt:constraints>
      <sqlt:constraint>
        <sqlt:deferrable>1</sqlt:deferrable>
        <sqlt:expression></sqlt:expression>
        <sqlt:fields>id</sqlt:fields>
        <sqlt:match_type></sqlt:match_type>
        <sqlt:name></sqlt:name>
        <sqlt:on_delete></sqlt:on_delete>
        <sqlt:on_update></sqlt:on_update>
        <sqlt:options></sqlt:options>
        <sqlt:reference_fields></sqlt:reference_fields>
        <sqlt:reference_table></sqlt:reference_table>
        <sqlt:type>PRIMARY KEY</sqlt:type>
      </sqlt:constraint>
      <sqlt:constraint>
        <sqlt:deferrable>1</sqlt:deferrable>
        <sqlt:expression></sqlt:expression>
        <sqlt:fields>email</sqlt:fields>
        <sqlt:match_type></sqlt:match_type>
        <sqlt:name></sqlt:name>
        <sqlt:on_delete></sqlt:on_delete>
        <sqlt:on_update></sqlt:on_update>
        <sqlt:options></sqlt:options>
        <sqlt:reference_fields></sqlt:reference_fields>
        <sqlt:reference_table></sqlt:reference_table>
        <sqlt:type>UNIQUE</sqlt:type>
      </sqlt:constraint>
    </sqlt:constraints>
  </sqlt:table>
</sqlt:schema>
EOXML

undef $obj;
$obj = SQL::Translator->new(
    debug          => DEBUG,
    trace          => TRACE,
    show_warnings  => 1,
    add_drop_table => 1,
    from           => 'MySQL',
    to             => 'XML-SQLFairy',
    producer_args  => { emit_empty_tags => 1 },
);
lives_ok { $xml=$obj->translate($file); } "Translate (emit_empty_tags=>1) ran";
ok("$xml" ne ""                             ,"Produced something!");
print "XML emit_empty_tags=>1:\n$xml" if DEBUG;
# Strip sqlf header with its variable date so we diff safely
$xml =~ s/^([^\n]*\n){7}//m; 
eq_or_diff $xml, $ans                       ,"XML looks right";



#
# attrib_values => 1
#

$ans = <<EOXML;
<sqlt:schema database="" name="" xmlns:sqlt="http://sqlfairy.sourceforge.net/sqlfairy.xml">
  <sqlt:table order="3" name="Basic">
    <sqlt:fields>
      <sqlt:field comments="comment on id field" is_primary_key="1" data_type="integer" name="id" is_foreign_key="0" is_auto_increment="1" is_nullable="0" order="9" size="10" />
      <sqlt:field comments="" is_primary_key="0" data_type="varchar" name="title" is_foreign_key="0" is_nullable="0" is_auto_increment="0" order="10" size="100" default_value="hello" />
      <sqlt:field comments="" is_primary_key="0" data_type="text" name="description" is_foreign_key="0" is_nullable="1" is_auto_increment="0" order="11" size="65535" default_value="" />
      <sqlt:field comments="" is_primary_key="0" data_type="varchar" name="email" is_foreign_key="0" is_nullable="1" is_auto_increment="0" order="12" size="255" />
    </sqlt:fields>
    <sqlt:indices>
      <sqlt:index options="" name="titleindex" fields="title" type="NORMAL" />
    </sqlt:indices>
    <sqlt:constraints>
      <sqlt:constraint reference_table="" options="" deferrable="1" name="" fields="id" on_delete="" expression="" on_update="" match_type="" type="PRIMARY KEY" />
      <sqlt:constraint reference_table="" options="" deferrable="1" name="" fields="email" on_delete="" expression="" on_update="" match_type="" type="UNIQUE" />
    </sqlt:constraints>
  </sqlt:table>
</sqlt:schema>
EOXML

$obj = SQL::Translator->new(
    debug          => DEBUG,
    trace          => TRACE,
    show_warnings  => 1,
    add_drop_table => 1,
    from           => "MySQL",
    to             => "XML-SQLFairy",
    producer_args  => { attrib_values => 1 },
);
lives_ok {$xml = $obj->translate($file);} "Translate (attrib_values=>1) ran";
ok("$xml" ne ""                             ,"Produced something!");
print "XML attrib_values=>1:\n$xml" if DEBUG;
# Strip sqlf header with its variable date so we diff safely
$xml =~ s/^([^\n]*\n){7}//m; 
eq_or_diff $xml, $ans                       ,"XML looks right";

