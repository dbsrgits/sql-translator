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

local $SIG{__WARN__} = sub {
    CORE::warn(@_)
        unless $_[0] =~ m#XML/Writer#;
};

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
  <sqlt:name></sqlt:name>
  <sqlt:database></sqlt:database>
  <sqlt:table>
    <sqlt:name>Basic</sqlt:name>
    <sqlt:order>1</sqlt:order>
    <sqlt:fields>
      <sqlt:field>
        <sqlt:name>id</sqlt:name>
        <sqlt:data_type>integer</sqlt:data_type>
        <sqlt:size>10</sqlt:size>
        <sqlt:is_nullable>0</sqlt:is_nullable>
        <sqlt:is_auto_increment>1</sqlt:is_auto_increment>
        <sqlt:is_primary_key>1</sqlt:is_primary_key>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:comments>comment on id field</sqlt:comments>
        <sqlt:order>1</sqlt:order>
      </sqlt:field>
      <sqlt:field>
        <sqlt:name>title</sqlt:name>
        <sqlt:data_type>varchar</sqlt:data_type>
        <sqlt:size>100</sqlt:size>
        <sqlt:is_nullable>0</sqlt:is_nullable>
        <sqlt:default_value>hello</sqlt:default_value>
        <sqlt:is_auto_increment>0</sqlt:is_auto_increment>
        <sqlt:is_primary_key>0</sqlt:is_primary_key>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:comments></sqlt:comments>
        <sqlt:order>2</sqlt:order>
      </sqlt:field>
      <sqlt:field>
        <sqlt:name>description</sqlt:name>
        <sqlt:data_type>text</sqlt:data_type>
        <sqlt:size>65535</sqlt:size>
        <sqlt:is_nullable>1</sqlt:is_nullable>
        <sqlt:default_value></sqlt:default_value>
        <sqlt:is_auto_increment>0</sqlt:is_auto_increment>
        <sqlt:is_primary_key>0</sqlt:is_primary_key>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:comments></sqlt:comments>
        <sqlt:order>3</sqlt:order>
      </sqlt:field>
      <sqlt:field>
        <sqlt:name>email</sqlt:name>
        <sqlt:data_type>varchar</sqlt:data_type>
        <sqlt:size>255</sqlt:size>
        <sqlt:is_nullable>1</sqlt:is_nullable>
        <sqlt:is_auto_increment>0</sqlt:is_auto_increment>
        <sqlt:is_primary_key>0</sqlt:is_primary_key>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:comments></sqlt:comments>
        <sqlt:order>4</sqlt:order>
      </sqlt:field>
    </sqlt:fields>
    <sqlt:indices>
      <sqlt:index>
        <sqlt:name>titleindex</sqlt:name>
        <sqlt:type>NORMAL</sqlt:type>
        <sqlt:fields>title</sqlt:fields>
        <sqlt:options></sqlt:options>
      </sqlt:index>
    </sqlt:indices>
    <sqlt:constraints>
      <sqlt:constraint>
        <sqlt:name></sqlt:name>
        <sqlt:type>PRIMARY KEY</sqlt:type>
        <sqlt:fields>id</sqlt:fields>
        <sqlt:reference_table></sqlt:reference_table>
        <sqlt:on_delete></sqlt:on_delete>
        <sqlt:on_update></sqlt:on_update>
        <sqlt:match_type></sqlt:match_type>
        <sqlt:expression></sqlt:expression>
        <sqlt:options></sqlt:options>
        <sqlt:deferrable>1</sqlt:deferrable>
      </sqlt:constraint>
      <sqlt:constraint>
        <sqlt:name></sqlt:name>
        <sqlt:type>UNIQUE</sqlt:type>
        <sqlt:fields>email</sqlt:fields>
        <sqlt:reference_table></sqlt:reference_table>
        <sqlt:on_delete></sqlt:on_delete>
        <sqlt:on_update></sqlt:on_update>
        <sqlt:match_type></sqlt:match_type>
        <sqlt:expression></sqlt:expression>
        <sqlt:options></sqlt:options>
        <sqlt:deferrable>1</sqlt:deferrable>
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
  <sqlt:name></sqlt:name>
  <sqlt:database></sqlt:database>
  <sqlt:table>
    <sqlt:name>Basic</sqlt:name>
    <sqlt:order>2</sqlt:order>
    <sqlt:fields>
      <sqlt:field>
        <sqlt:name>id</sqlt:name>
        <sqlt:data_type>integer</sqlt:data_type>
        <sqlt:size>10</sqlt:size>
        <sqlt:is_nullable>0</sqlt:is_nullable>
        <sqlt:default_value></sqlt:default_value>
        <sqlt:is_auto_increment>1</sqlt:is_auto_increment>
        <sqlt:is_primary_key>1</sqlt:is_primary_key>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:comments>comment on id field</sqlt:comments>
        <sqlt:order>5</sqlt:order>
      </sqlt:field>
      <sqlt:field>
        <sqlt:name>title</sqlt:name>
        <sqlt:data_type>varchar</sqlt:data_type>
        <sqlt:size>100</sqlt:size>
        <sqlt:is_nullable>0</sqlt:is_nullable>
        <sqlt:default_value>hello</sqlt:default_value>
        <sqlt:is_auto_increment>0</sqlt:is_auto_increment>
        <sqlt:is_primary_key>0</sqlt:is_primary_key>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:comments></sqlt:comments>
        <sqlt:order>6</sqlt:order>
      </sqlt:field>
      <sqlt:field>
        <sqlt:name>description</sqlt:name>
        <sqlt:data_type>text</sqlt:data_type>
        <sqlt:size>65535</sqlt:size>
        <sqlt:is_nullable>1</sqlt:is_nullable>
        <sqlt:default_value></sqlt:default_value>
        <sqlt:is_auto_increment>0</sqlt:is_auto_increment>
        <sqlt:is_primary_key>0</sqlt:is_primary_key>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:comments></sqlt:comments>
        <sqlt:order>7</sqlt:order>
      </sqlt:field>
      <sqlt:field>
        <sqlt:name>email</sqlt:name>
        <sqlt:data_type>varchar</sqlt:data_type>
        <sqlt:size>255</sqlt:size>
        <sqlt:is_nullable>1</sqlt:is_nullable>
        <sqlt:default_value></sqlt:default_value>
        <sqlt:is_auto_increment>0</sqlt:is_auto_increment>
        <sqlt:is_primary_key>0</sqlt:is_primary_key>
        <sqlt:is_foreign_key>0</sqlt:is_foreign_key>
        <sqlt:comments></sqlt:comments>
        <sqlt:order>8</sqlt:order>
      </sqlt:field>
    </sqlt:fields>
    <sqlt:indices>
      <sqlt:index>
        <sqlt:name>titleindex</sqlt:name>
        <sqlt:type>NORMAL</sqlt:type>
        <sqlt:fields>title</sqlt:fields>
        <sqlt:options></sqlt:options>
      </sqlt:index>
    </sqlt:indices>
    <sqlt:constraints>
      <sqlt:constraint>
        <sqlt:name></sqlt:name>
        <sqlt:type>PRIMARY KEY</sqlt:type>
        <sqlt:fields>id</sqlt:fields>
        <sqlt:reference_table></sqlt:reference_table>
        <sqlt:reference_fields></sqlt:reference_fields>
        <sqlt:on_delete></sqlt:on_delete>
        <sqlt:on_update></sqlt:on_update>
        <sqlt:match_type></sqlt:match_type>
        <sqlt:expression></sqlt:expression>
        <sqlt:options></sqlt:options>
        <sqlt:deferrable>1</sqlt:deferrable>
      </sqlt:constraint>
      <sqlt:constraint>
        <sqlt:name></sqlt:name>
        <sqlt:type>UNIQUE</sqlt:type>
        <sqlt:fields>email</sqlt:fields>
        <sqlt:reference_table></sqlt:reference_table>
        <sqlt:reference_fields></sqlt:reference_fields>
        <sqlt:on_delete></sqlt:on_delete>
        <sqlt:on_update></sqlt:on_update>
        <sqlt:match_type></sqlt:match_type>
        <sqlt:expression></sqlt:expression>
        <sqlt:options></sqlt:options>
        <sqlt:deferrable>1</sqlt:deferrable>
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
<sqlt:schema name="" database="" xmlns:sqlt="http://sqlfairy.sourceforge.net/sqlfairy.xml">
  <sqlt:table name="Basic" order="3">
    <sqlt:fields>
      <sqlt:field name="id" data_type="integer" size="10" is_nullable="0" is_auto_increment="1" is_primary_key="1" is_foreign_key="0" comments="comment on id field" order="9" />
      <sqlt:field name="title" data_type="varchar" size="100" is_nullable="0" default_value="hello" is_auto_increment="0" is_primary_key="0" is_foreign_key="0" comments="" order="10" />
      <sqlt:field name="description" data_type="text" size="65535" is_nullable="1" default_value="" is_auto_increment="0" is_primary_key="0" is_foreign_key="0" comments="" order="11" />
      <sqlt:field name="email" data_type="varchar" size="255" is_nullable="1" is_auto_increment="0" is_primary_key="0" is_foreign_key="0" comments="" order="12" />
    </sqlt:fields>
    <sqlt:indices>
      <sqlt:index name="titleindex" type="NORMAL" fields="title" options="" />
    </sqlt:indices>
    <sqlt:constraints>
      <sqlt:constraint name="" type="PRIMARY KEY" fields="id" reference_table="" on_delete="" on_update="" match_type="" expression="" options="" deferrable="1" />
      <sqlt:constraint name="" type="UNIQUE" fields="email" reference_table="" on_delete="" on_update="" match_type="" expression="" options="" deferrable="1" />
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
  <sqlt:name></sqlt:name>
  <sqlt:database></sqlt:database>
  <sqlt:view>
    <sqlt:name>foo_view</sqlt:name>
    <sqlt:sql>select name, age from person</sqlt:sql>
    <sqlt:fields>name,age</sqlt:fields>
    <sqlt:order>1</sqlt:order>
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
  <sqlt:name></sqlt:name>
  <sqlt:database></sqlt:database>
  <sqlt:trigger>
    <sqlt:name>foo_trigger</sqlt:name>
    <sqlt:database_event>insert</sqlt:database_event>
    <sqlt:action>update modified=timestamp();</sqlt:action>
    <sqlt:on_table>foo</sqlt:on_table>
    <sqlt:perform_action_when>after</sqlt:perform_action_when>
    <sqlt:order>1</sqlt:order>
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
  <sqlt:name></sqlt:name>
  <sqlt:database></sqlt:database>
  <sqlt:procedure>
    <sqlt:name>foo_proc</sqlt:name>
    <sqlt:sql>select foo from bar</sqlt:sql>
    <sqlt:parameters>foo,bar</sqlt:parameters>
    <sqlt:owner>Nomar</sqlt:owner>
    <sqlt:comments>Go Sox!</sqlt:comments>
    <sqlt:order>1</sqlt:order>
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
