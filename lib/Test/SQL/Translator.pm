package Test::SQL::Translator;

# ----------------------------------------------------------------------
# $Id: Translator.pm,v 1.1 2004-02-29 18:26:53 grommit Exp $
# ----------------------------------------------------------------------
# Copyright (C) 2003 The SQLFairy Authors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
# 02111-1307  USA
# -------------------------------------------------------------------

=pod

=head1 NAME

Test::SQL::Translator - Test::More test functions for the Schema objects.

=cut

use strict;
use warnings;

use base qw(Exporter);

use vars qw($VERSION @EXPORT @EXPORT_OK);
$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;
@EXPORT = qw( 
    table_ok
    field_ok
    constraint_ok
    index_ok
    view_ok
    trigger_ok
    procedure_ok
);
# TODO schema_ok

use Test::More;
use Test::Exception;
use SQL::Translator::Schema::Constants;

# $ATTRIBUTES{ <schema_object_name> } = { <attribname> => <default>, ... }
my %ATTRIBUTES;
$ATTRIBUTES{field} = {
    name => undef,
    data_type => '',
    default_value => undef,
    size => '0',
    is_primary_key => 0,
    is_unique => 0,
    is_nullable => 1,
    is_foreign_key => 0,
    is_auto_increment => 0,
    comments => '',
    extra => {},
    # foreign_key_reference,
    is_valid => 1,
    # order
};
$ATTRIBUTES{constraint} = {
    name => '',
    type => '',
    deferrable => 1,
    expression => '',
    is_valid => 1,
    fields => [],
    match_type => '',
    options => [],
    on_delete => '',
    on_update => '',
    reference_fields => [],
    reference_table => '',
};
$ATTRIBUTES{'index'} = {
    fields => [],
    is_valid => 1,
    name => "",
    options => [],
    type => NORMAL,
};
$ATTRIBUTES{'view'} = {
    name => "",
    sql => "",
    fields => [],
};
$ATTRIBUTES{'trigger'} = {
    name                => '',
    perform_action_when => undef,
    database_event      => undef,
    on_table            => undef,
    action              => undef,
};
$ATTRIBUTES{'procedure'} = {
    name       => '',
    sql        => '',
    parameters => [],
    owner      => '',
    comments   => '',
};
$ATTRIBUTES{table} = {
    comments   => undef,
    name       => '',
    #primary_key => undef, # pkey constraint
    options    => [],
    #order      => 0,
    fields      => undef,
    constraints => undef,
    indices     => undef,
};



# Given a test hash and schema object name set any attribute keys not present in
# the test hash to their default value for that schema object type.
# e.g. default_attribs( $test, "field" );
sub default_attribs {
    my ($foo, $what) = @_;
    die "Can't add default attibs - unkown Scheam object type '$what'."
    unless exists $ATTRIBUTES{$what};
    $foo->{$_} = $ATTRIBUTES{$what}{$_}
    foreach grep !exists($foo->{$_}), keys %{$ATTRIBUTES{$what}};
    return $foo;
}

# Format test name so it will prepend the test names used below.
sub t_name {
    my $name = shift;
    $name ||= "";
    $name = "$name - " if $name;
    return $name;
}

sub field_ok {
    my ($f1,$test,$name) = @_;
    my $t_name = t_name($name);
    default_attribs($test,"field");

    unless ($f1) {
        fail " Field '$test->{name}' doesn't exist!";
        return;
    }

    is( $f1->name, $test->{name}, "${t_name}Field name '$test->{name}'" );

    is( $f1->is_valid, $test->{is_valid},
    "$t_name    is".($test->{is_valid} ? '' : 'not ').'valid' );

    is( $f1->data_type, $test->{data_type},
        "$t_name    type is '$test->{data_type}'" );

    is( $f1->size, $test->{size}, "$t_name    size is '$test->{size}'" );

    is( $f1->default_value, $test->{default_value},
    "$t_name    default value is "
    .(defined($test->{default_value}) ? "'$test->{default_value}'" : "UNDEF" )
    );

    is( $f1->is_nullable, $test->{is_nullable},
    "$t_name    ".($test->{is_nullable} ? 'can' : 'cannot').' be null' );

    is( $f1->is_unique, $test->{is_unique},
    "$t_name    ".($test->{is_unique} ? 'can' : 'cannot').' be unique' );

    is( $f1->is_primary_key, $test->{is_primary_key},
    "$t_name    is ".($test->{is_primary_key} ? '' : 'not ').'a primary_key' );

    is( $f1->is_foreign_key, $test->{is_foreign_key},
    "$t_name    is ".($test->{is_foreign_key} ? '' : 'not').' a foreign_key' );

    is( $f1->is_auto_increment, $test->{is_auto_increment},
    "$t_name    is "
    .($test->{is_auto_increment} ?  '' : 'not ').'an auto_increment' );

    is( $f1->comments, $test->{comments}, "$t_name    comments" );

    is_deeply( { $f1->extra }, $test->{extra}, "$t_name    extra" );
}

sub constraint_ok {
    my ($obj,$test,$name) = @_;
    my $t_name = t_name($name);
    default_attribs($test,"constraint");

    is( $obj->name, $test->{name}, "${t_name}Constraint '$test->{name}'" );

    is( $obj->type, $test->{type}, "$t_name    type is '$test->{type}'" );

    is( $obj->deferrable, $test->{deferrable},
    "$t_name    ".($test->{deferrable} ? 'can' : 'cannot').' be deferred' );

    is( $obj->is_valid, $test->{is_valid},
    "$t_name    is ".($test->{is_valid} ? '' : 'not ').'valid' );

    is($obj->table->name,$test->{table},"$t_name    table is '$test->{table}'" );

    is( $obj->expression, $test->{expression},
    "$t_name    expression is '$test->{expression}'" );

    is_deeply( [$obj->fields], $test->{fields},
    "$t_name    fields are '".join(",",@{$test->{fields}})."'" );

    is( $obj->reference_table, $test->{reference_table},
    "$t_name    reference_table is '$test->{reference_table}'" );

    is_deeply( [$obj->reference_fields], $test->{reference_fields},
    "$t_name    reference_fields are '".join(",",@{$test->{reference_fields}})."'" );

    is( $obj->match_type, $test->{match_type},
    "$t_name    match_type is '$test->{match_type}'" );

    is( $obj->on_delete, $test->{on_delete},
    "$t_name    on_delete is '$test->{on_delete}'" );

    is( $obj->on_update, $test->{on_update},
    "$t_name    on_update is '$test->{on_update}'" );

    is_deeply( [$obj->options], $test->{options},
    "$t_name    options are '".join(",",@{$test->{options}})."'" );
}

sub index_ok {
    my ($obj,$test,$name) = @_;
    my $t_name = t_name($name);
    default_attribs($test,"index");

    is( $obj->name, $test->{name}, "${t_name}Index '$test->{name}'" );

    is( $obj->is_valid, $test->{is_valid},
    "$t_name    is ".($test->{is_valid} ? '' : 'not ').'valid' );

    is( $obj->type, $test->{type}, "$t_name    type is '$test->{type}'" );

    is_deeply( [$obj->fields], $test->{fields},
    "$t_name    fields are '".join(",",@{$test->{fields}})."'" );

    is_deeply( [$obj->options], $test->{options},
    "$t_name    options are '".join(",",@{$test->{options}})."'" );
}

sub trigger_ok {
    my ($obj,$test,$name) = @_;
    my $t_name = t_name($name);
    default_attribs($test,"index");

    is( $obj->name, $test->{name}, "${t_name}Constraint '$test->{name}'" );

    is( $obj->is_valid, $test->{is_valid},
        "$t_name    is ".($test->{is_valid} ? '' : 'not ').'valid' );

    is( $obj->perform_action_when, $test->{perform_action_when},
        "$t_name    perform_action_when is '$test->{perform_action_when}'" );

    is( $obj->database_event, $test->{database_event},
        "$t_name    database_event is '$test->{database_event}'" );

    is( $obj->on_table, $test->{on_table},
        "$t_name    on_table is '$test->{on_table}'" );

    is( $obj->action, $test->{action}, "$t_name    action is '$test->{action}'" );
}

sub view_ok {
    my ($obj,$test,$name) = @_;
    my $t_name = t_name($name);
    default_attribs($test,"index");

    #isa_ok( $v, 'SQL::Translator::Schema::View', 'View' );

    is( $obj->name, $test->{name}, "${t_name}View '$test->{name}'" );

    is( $obj->is_valid, $test->{is_valid},
    "$t_name    is ".($test->{is_valid} ? '' : 'not ').'valid' );

    is( $obj->sql, $test->{sql}, "$t_name    sql is '$test->{sql}'" );

    is_deeply( [$obj->fields], $test->{fields},
    "$t_name    fields are '".join(",",@{$test->{fields}})."'" );
}

sub procedure_ok {
    my ($obj,$test,$name) = @_;
    my $t_name = t_name($name);
    default_attribs($test,"index");

    #isa_ok( $v, 'SQL::Translator::Schema::View', 'View' );

    is( $obj->name, $test->{name}, "${t_name}Procedure '$test->{name}'" );

    is( $obj->sql, $test->{sql}, "$t_name    sql is '$test->{sql}'" );

    is_deeply( [$obj->parameters], $test->{parameters},
    "$t_name    parameters are '".join(",",@{$test->{parameters}})."'" );

    is( $obj->comments, $test->{comments}, 
        "$t_name    comments is '$test->{comments}'" );

    is( $obj->owner, $test->{owner}, "$t_name    owner is '$test->{owner}'" );
}

sub table_ok {
    my ($obj,$test,$name) = @_;
    my $t_name = t_name($name);
    default_attribs($test,"table");
    my %arg = %$test;

    my $tbl_name = $arg{name} || die "Need a table name to test.";
    is( $obj->{name}, $arg{name}, "${t_name}Table name '$arg{name}'" );

    is_deeply( [$obj->options], $test->{options},
    "$t_name    options are '".join(",",@{$test->{options}})."'" );

    # Fields
    if ( $arg{fields} ) {
        my @fldnames = map { $_->{name} } @{$arg{fields}};
        is_deeply( [ map {$_->name}   $obj->get_fields ],
                   [ map {$_->{name}} @{$arg{fields}} ],
                   "${t_name}Table $tbl_name fields match" );
        foreach ( @{$arg{fields}} ) {
            my $f_name = $_->{name} || die "Need a field name to test.";
            field_ok( $obj->get_field($f_name), $_, $name );
        }
    }
    else {
        is(scalar($obj->get_fields), undef,
            "${t_name}Table $tbl_name has no fields.");
    }

    # Constraints and indices
    my %bits = (
        constraint => "constraints",
        'index'    => "indices",
    );
    while ( my($foo,$plural) = each %bits ) {
        next unless defined $arg{$plural};
        if ( my @tfoo = @{$arg{$plural}} ) {
            my $meth = "get_$plural";
            my @foo = $obj->$meth;
            is(scalar(@foo), scalar(@tfoo),
            "${t_name}Table $tbl_name has ".scalar(@tfoo)." $plural");
            foreach ( @foo ) {
                my $ans = { table => $obj->name, %{shift @tfoo}};
                my $meth = "${foo}_ok";
                { no strict 'refs';
                    $meth->( $_, $ans, $name  );
                }
            }
        }
    }
}

sub schema_ok {
    my ($obj,$test,$name) = @_;
    my $t_name = t_name($name);
    default_attribs($test,"schema");
}

1; # compile please ===========================================================
__END__

=pod

=head1 SYNOPSIS

 # t/magic.t

 use FindBin '$Bin';
 use Test::More;
 use Test::SQL::Translator;

 # Run parse
 my $sqlt = SQL::Translator->new(
     parser => "Magic",
     filename => "$Bin/data/magic/test.magic",
     ... 
 );
 ...
 my $schema = $sqlt->schema;
 
 # Test the table it produced.
 table_ok( $schema->get_table("Customer"), {
     name => "Customer",
     fields => [
         {
             name => "CustomerID",
             data_type => "INT",
             size => 12,
             default_value => undef,
             is_nullable => 0,
             is_primary_key => 1,
         },
         {
             name => "bar",
             data_type => "VARCHAR",
             size => 255,
             is_nullable => 0,
         },
     ],
     constraints => [
         {
             type => "PRIMARY KEY",
             fields => "CustomerID",
         },
     ],
     indices => [
         {
             name => "barindex",
             fields => ["bar"],
         },
     ],
 });

=head1 DESCSIPTION

Provides a set of Test::More tests for Schema objects. Tesing a parsed
schema is then as easy as writing a perl data structure describing how you
expect the schema to look.

The data structures given to the test subs don't have to include all the 
possible values, only the ones you expect to have changed. Any left out will be
tested to make sure they are still at their default value. This is a usefull
check that you your parser hasn't accidentally set schema values you didn't
expect it to. (And makes tests look nice and long ;-)

For an example of the output run the t/16xml-parser.t test.

=head1 Tests

All the tests take a first arg of the schema object to test, followed by a 
hash ref describing how you expect that object to look (you only need give the
attributes you expect to have changed from the default).
The 3rd arg is an optional test name to pre-pend to all the generated test 
names.

=head2 table_ok

=head2 field_ok

=head2 constraint_ok

=head2 index_ok

=head2 view_ok

=head2 trigger_ok

=head2 procedure_ok

=head1 EXPORTS

table_ok, field_ok, constraint_ok, index_ok, view_ok, trigger_ok, procedure_ok

=head1 TODO

=over 4

=item Test the tests!

=item schema_ok()

Test whole schema.

=item Test skipping

As the test subs wrap up lots of tests in one call you can't skip idividual
tests only whole sets e.g. a whole table or field.
We could add skip_* items to the test hashes to allow per test skips. e.g.

 skip_is_primary_key => "Need to fix primary key parsing.",

=item yaml test specs

Maybe have the test subs also accept yaml for the test hash ref as its a much
nicer for writing big data structures. We can then define tests as in input
schema file and test yaml file to compare it against.

=back

=head1 BUGS

=head1 AUTHOR

Mark D. Addison E<lt>mark.addison@itn.co.ukE<gt>.

Thanks to Ken Y. Clark for the original table and field test code taken from
his mysql test.

=head1 SEE ALSO

perl(1), SQL::Translator, SQL::Translator::Schema, Test::More.

=cut
