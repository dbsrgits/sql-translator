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
plan tests => 18;
    
use SQL::Translator;
use SQL::Translator::Producer::XML::SQLFairy;


#
# emit_empty_tags => 0
#
{
my ($obj,$ans,$xml);

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

} # end emit_empty_tags=>0

#
# emit_empty_tags => 1
#
{
my ($obj,$ans,$xml);

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

} # end emit_empty_tags => 1

#
# attrib_values => 1
#
{
my ($obj,$ans,$xml);

$ans = <<EOXML;
<sqlt:schema database="" name="" xmlns:sqlt="http://sqlfairy.sourceforge.net/sqlfairy.xml">
  <sqlt:table name="Basic" order="3">
    <sqlt:fields>
      <sqlt:field comments="comment on id field" data_type="integer" is_auto_increment="1" is_foreign_key="0" is_nullable="0" is_primary_key="1" name="id" order="9" size="10" />
      <sqlt:field comments="" data_type="varchar" default_value="hello" is_auto_increment="0" is_foreign_key="0" is_nullable="0" is_primary_key="0" name="title" order="10" size="100" />
      <sqlt:field comments="" data_type="text" default_value="" is_auto_increment="0" is_foreign_key="0" is_nullable="1" is_primary_key="0" name="description" order="11" size="65535" />
      <sqlt:field comments="" data_type="varchar" is_auto_increment="0" is_foreign_key="0" is_nullable="1" is_primary_key="0" name="email" order="12" size="255" />
    </sqlt:fields>
    <sqlt:indices>
      <sqlt:index fields="title" name="titleindex" options="" type="NORMAL" />
    </sqlt:indices>
    <sqlt:constraints>
      <sqlt:constraint deferrable="1" expression="" fields="id" match_type="" name="" on_delete="" on_update="" options="" reference_table="" type="PRIMARY KEY" />
      <sqlt:constraint deferrable="1" expression="" fields="email" match_type="" name="" on_delete="" on_update="" options="" reference_table="" type="UNIQUE" />
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

} # end attrib_values => 1

#
# View
#
# Thanks to Ken for the schema setup lifted from 13schema.t
{
my ($obj,$ans,$xml);

$ans = <<EOXML;
<sqlt:schema xmlns:sqlt="http://sqlfairy.sourceforge.net/sqlfairy.xml">
  <sqlt:database></sqlt:database>
  <sqlt:name></sqlt:name>
  <sqlt:view>
    <sqlt:fields>name,age</sqlt:fields>
    <sqlt:name>foo_view</sqlt:name>
    <sqlt:order>1</sqlt:order>
    <sqlt:sql>select name, age from person</sqlt:sql>
  </sqlt:view>
</sqlt:schema>
EOXML

    $obj = SQL::Translator->new(
        debug          => DEBUG,
        trace          => TRACE,
        show_warnings  => 1,
        add_drop_table => 1,
        from           => "MySQL",
        to             => "XML-SQLFairy",
    );
    my $s      = $obj->schema;
    my $name   = 'foo_view';
    my $sql    = 'select name, age from person';
    my $fields = 'name, age';
    my $v      = $s->add_view(
        name   => $name,
        sql    => $sql,
        fields => $fields,
        schema => $s,
    ) or die $s->error;
    
    # As we have created a Schema we give translate a dummy string so that
    # it will run the produce.
    lives_ok {$xml =$obj->translate("FOO");} "Translate (View) ran";
    ok("$xml" ne ""                             ,"Produced something!");
    print "XML attrib_values=>1:\n$xml" if DEBUG;
    # Strip sqlf header with its variable date so we diff safely
    $xml =~ s/^([^\n]*\n){7}//m; 
    eq_or_diff $xml, $ans                       ,"XML looks right";
} # end View

#
# Trigger
#
# Thanks to Ken for the schema setup lifted from 13schema.t
{
my ($obj,$ans,$xml);

$ans = <<EOXML;
<sqlt:schema xmlns:sqlt="http://sqlfairy.sourceforge.net/sqlfairy.xml">
  <sqlt:database></sqlt:database>
  <sqlt:name></sqlt:name>
  <sqlt:trigger>
    <sqlt:action>update modified=timestamp();</sqlt:action>
    <sqlt:database_event>insert</sqlt:database_event>
    <sqlt:name>foo_trigger</sqlt:name>
    <sqlt:on_table>foo</sqlt:on_table>
    <sqlt:order>1</sqlt:order>
    <sqlt:perform_action_when>after</sqlt:perform_action_when>
  </sqlt:trigger>
</sqlt:schema>
EOXML

    $obj = SQL::Translator->new(
        debug          => DEBUG,
        trace          => TRACE,
        show_warnings  => 1,
        add_drop_table => 1,
        from           => "MySQL",
        to             => "XML-SQLFairy",
    );
    my $s                   = $obj->schema;
    my $name                = 'foo_trigger';
    my $perform_action_when = 'after';
    my $database_event      = 'insert';
    my $on_table            = 'foo';
    my $action              = 'update modified=timestamp();';
    my $t                   = $s->add_trigger(
        name                => $name,
        perform_action_when => $perform_action_when,
        database_event      => $database_event,
        on_table            => $on_table,
        action              => $action,
    ) or die $s->error;
    
    # As we have created a Schema we give translate a dummy string so that
    # it will run the produce.
    lives_ok {$xml =$obj->translate("FOO");} "Translate (Trigger) ran";
    ok("$xml" ne ""                             ,"Produced something!");
    print "XML attrib_values=>1:\n$xml" if DEBUG;
    # Strip sqlf header with its variable date so we diff safely
    $xml =~ s/^([^\n]*\n){7}//m; 
    eq_or_diff $xml, $ans                       ,"XML looks right";
} # end Trigger

#
# Procedure
#
# Thanks to Ken for the schema setup lifted from 13schema.t
{
my ($obj,$ans,$xml);

$ans = <<EOXML;
<sqlt:schema xmlns:sqlt="http://sqlfairy.sourceforge.net/sqlfairy.xml">
  <sqlt:database></sqlt:database>
  <sqlt:name></sqlt:name>
  <sqlt:procedure>
    <sqlt:comments>Go Sox!</sqlt:comments>
    <sqlt:name>foo_proc</sqlt:name>
    <sqlt:order>1</sqlt:order>
    <sqlt:owner>Nomar</sqlt:owner>
    <sqlt:parameters>foo,bar</sqlt:parameters>
    <sqlt:sql>select foo from bar</sqlt:sql>
  </sqlt:procedure>
</sqlt:schema>
EOXML

    $obj = SQL::Translator->new(
        debug          => DEBUG,
        trace          => TRACE,
        show_warnings  => 1,
        add_drop_table => 1,
        from           => "MySQL",
        to             => "XML-SQLFairy",
    );
    my $s          = $obj->schema;
    my $name       = 'foo_proc';
    my $sql        = 'select foo from bar';
    my $parameters = 'foo, bar';
    my $owner      = 'Nomar';
    my $comments   = 'Go Sox!';
    my $p          = $s->add_procedure(
        name       => $name,
        sql        => $sql,
        parameters => $parameters,
        owner      => $owner,
        comments   => $comments,
    ) or die $s->error;
    
    # As we have created a Schema we give translate a dummy string so that
    # it will run the produce.
    lives_ok {$xml =$obj->translate("FOO");} "Translate (Procedure) ran";
    ok("$xml" ne ""                             ,"Produced something!");
    print "XML attrib_values=>1:\n$xml" if DEBUG;
    # Strip sqlf header with its variable date so we diff safely
    $xml =~ s/^([^\n]*\n){7}//m; 
    eq_or_diff $xml, $ans                       ,"XML looks right";
} # end Procedure
