#!/usr/bin/perl -w 
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#
# basic.t
# -------
# Tests that;
#

use strict;
use Test::More;
use Test::Exception;

use strict;
use Data::Dumper;
my %opt;
BEGIN { map { $opt{$_}=1 if s/^-// } @ARGV; }
use constant DEBUG => (exists $opt{d} ? 1 : 0);
local $SIG{__WARN__} = sub { diag "[warn] ", @_; };

use FindBin qw/$Bin/;

# Usefull test subs for the schema objs
#=============================================================================

my %ATTRIBUTES;
$ATTRIBUTES{field} = [qw/
name
data_type
default_value
size
is_primary_key
is_unique
is_nullable
is_foreign_key
is_auto_increment
/];

sub test_field {
    my ($fld,$test) = @_;
    die "test_field needs a least a name!" unless $test->{name};
    my $name = $test->{name};
    is $fld->name, $name, "$name - Name right";

    foreach my $attr ( @{$ATTRIBUTES{field}} ) {
        if ( exists $test->{$attr} ) {
            my $ans = $test->{$attr};
            if ( $attr =~ m/^is_/ ) {
                if ($ans) { ok $fld->$attr,  "$name - $attr true"; }
                else      { ok !$fld->$attr, "$name - $attr false"; }
            }
            else {
                is $fld->$attr, $ans, "$name - $attr = '"
                                     .(defined $ans ? $ans : "NULL" )."'";
            }
        }
        else {
            ok !$fld->$attr, "$name - $attr not set";
        }
    }
}

# TODO test_constraint, test_index

# Testing 1,2,3,4...
#=============================================================================

plan tests => 198;

use SQL::Translator;
use SQL::Translator::Schema::Constants;

foreach (
    "$Bin/data/xml/schema-basic.xml",
    "$Bin/data/xml/schema-basic-attribs.xml"
) {
    do_file($_);
}

sub do_file {
    my $testschema = shift;
    # Parse the test XML schema
    my $obj;
    $obj = SQL::Translator->new(
        debug          => DEBUG,
        show_warnings  => 1,
        add_drop_table => 1,
    );
    die "Can't find test schema $testschema" unless -e $testschema;
    my $sql = $obj->translate(
        from     => 'XML-SQLFairy',
        to       => 'MySQL',
        filename => $testschema,
    );
    print $sql if DEBUG;
    #print "Debug:", Dumper($obj) if DEBUG;

    # Test the schema objs generted from the XML
    #
    my $scma = $obj->schema;
    my @tblnames = map {$_->name} $scma->get_tables;
    is_deeply( \@tblnames, [qw/Basic/], "tables");

    # Basic
    my $tbl = $scma->get_table("Basic");
    is_deeply( [map {$_->name} $tbl->get_fields], [qw/
        id title description email explicitnulldef explicitemptystring emptytagdef
    /] , "Table Basic's fields");
    test_field($tbl->get_field("id"),{
        name => "id",
        data_type => "int",
        default_value => undef,
        is_nullable => 0,
        size => 10,
        is_primary_key => 1,
        is_auto_increment => 1,
    });
    test_field($tbl->get_field("title"),{
        name => "title",
        data_type => "varchar",
        is_nullable => 0,
        default_value => "hello",
        size => 100,
    });
    test_field($tbl->get_field("description"),{
        name => "description",
        data_type => "text",
        is_nullable => 1,
        default_value => "",
    });
    test_field($tbl->get_field("email"),{
        name => "email",
        data_type => "varchar",
        size => 255,
        is_unique => 1,
        default_value => undef,
        is_nullable => 1,
    });
    test_field($tbl->get_field("explicitnulldef"),{
        name => "explicitnulldef",
        data_type => "varchar",
        default_value => undef,
        is_nullable => 1,
    });
    test_field($tbl->get_field("explicitemptystring"),{
        name => "explicitemptystring",
        data_type => "varchar",
        default_value => "",
        is_nullable => 1,
    });
    test_field($tbl->get_field("emptytagdef"),{
        name => "emptytagdef",
        data_type => "varchar",
        default_value => "",
        is_nullable => 1,
    });

    my @indices = $tbl->get_indices;
    is scalar(@indices), 1, "Table basic has 1 index";

    my @constraints = $tbl->get_constraints;
    is scalar(@constraints), 2, "Table basic has 2 constraints";
    my $con = shift @constraints;
    is $con->table, $tbl, "Constaints table right";
    is $con->name, "", "Constaints table right";
    is $con->type, PRIMARY_KEY, "Constaint is primary key";
    is_deeply [$con->fields], ["id"], "Constaint fields";
    $con = shift @constraints;
    is $con->table, $tbl, "Constaints table right";
    is $con->type, UNIQUE, "Constaint UNIQUE";
    is_deeply [$con->fields], ["email"], "Constaint fields";

    #
    # View
    # 
    my @views = $scma->get_views;
    is( scalar @views, 1, 'Number of views is 1' );
    my $v = $views[0];
    isa_ok( $v, 'SQL::Translator::Schema::View', 'View' );
    is( $v->name, 'email_list', "View's Name is 'email_list'" );
    is( $v->sql, "SELECT email FROM Basic WHERE email IS NOT NULL",
    "View's sql" );
    is( join(",",$v->fields), 'email', "View's Fields" );

    #
    # Trigger
    #
    {
        my $name                = 'foo_trigger';
        my $perform_action_when = 'after';
        my $database_event      = 'insert';
        my $on_table            = 'foo';
        my $action              = 'update modified=timestamp();';
        my @triggs = $scma->get_triggers;
        is( scalar @triggs, 1, 'Number of triggers is 1' );
        my $t = $triggs[0];
        isa_ok( $t, 'SQL::Translator::Schema::Trigger', 'Trigger' );
        is( $t->name, $name, qq[Name is "$name"] );
        is( $t->perform_action_when, $perform_action_when, 
            qq[Perform action when is "$perform_action_when"] );
        is( $t->database_event, $database_event, 
            qq[Database event is "$database_event"] );
        is( $t->on_table, $on_table, qq[Table is "$on_table"] );
        is( $t->action, $action, qq[Action is "$action"] );
    }
    
    #
    # Procedure
    #
    {
        my $name       = 'foo_proc';
        my $sql        = 'select foo from bar';
        my $parameters = 'foo, bar';
        my $owner      = 'Nomar';
        my $comments   = 'Go Sox!';
        my @procs = $scma->get_procedures;
        is( scalar @procs, 1, 'Number of procedures is 1' );
        my $p = $procs[0];
        isa_ok( $p, 'SQL::Translator::Schema::Procedure', 'Procedure' );
        is( $p->name, $name, qq[Name is "$name"] );
        is( $p->sql, $sql, qq[SQL is "$sql"] );
        is( join(',', $p->parameters), 'foo,bar', qq[Params = 'foo,bar'] );
        is( $p->comments, $comments, qq[Comments = "$comments"] );
    }

} # /Test of schema
