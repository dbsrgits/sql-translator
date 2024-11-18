package Test::SQL::Translator;

=pod

=head1 NAME

Test::SQL::Translator - Test::More test functions for the Schema objects.

=cut

use strict;
use warnings;
use Test::More;
use SQL::Translator::Schema::Constants;

use base qw(Exporter);
our @EXPORT_OK;
our $VERSION = '1.66';
our @EXPORT  = qw(
  schema_ok
  table_ok
  field_ok
  constraint_ok
  index_ok
  view_ok
  trigger_ok
  procedure_ok
  maybe_plan
);

# $ATTRIBUTES{ <schema_object_name> } = { <attribname> => <default>, ... }
my %ATTRIBUTES = (
  field => {
    name              => undef,
    data_type         => '',
    default_value     => undef,
    size              => '0',
    is_primary_key    => 0,
    is_unique         => 0,
    is_nullable       => 1,
    is_foreign_key    => 0,
    is_auto_increment => 0,
    comments          => '',
    extra             => {},

    # foreign_key_reference,
    is_valid => 1,

    # order
  },
  constraint => {
    name             => '',
    type             => '',
    deferrable       => 1,
    expression       => '',
    is_valid         => 1,
    fields           => [],
    match_type       => '',
    options          => [],
    on_delete        => '',
    on_update        => '',
    reference_fields => [],
    reference_table  => '',
    extra            => {},
  },
  index => {
    fields   => [],
    is_valid => 1,
    name     => "",
    options  => [],
    type     => NORMAL,
    extra    => {},
  },
  view => {
    name     => "",
    sql      => "",
    fields   => [],
    is_valid => 1,
    extra    => {},
  },
  trigger => {
    name                => '',
    perform_action_when => undef,
    database_events     => undef,
    on_table            => undef,
    action              => undef,
    is_valid            => 1,
    extra               => {},
  },
  procedure => {
    name       => '',
    sql        => '',
    parameters => [],
    owner      => '',
    comments   => '',
    extra      => {},
  },
  table => {
    comments => undef,
    name     => '',

    #primary_key => undef, # pkey constraint
    options => [],

    #order      => 0,
    fields      => undef,
    constraints => undef,
    indices     => undef,
    is_valid    => 1,
    extra       => {},
  },
  schema => {
    name       => '',
    database   => '',
    procedures => undef,    # [] when set
    tables     => undef,    # [] when set
    triggers   => undef,    # [] when set
    views      => undef,    # [] when set
    is_valid   => 1,
    extra      => {},
  }
);

# Given a test hash and schema object name set any attribute keys not present in
# the test hash to their default value for that schema object type.
# e.g. default_attribs( $test, "field" );
sub default_attribs {
  my ($hashref, $object_type) = @_;

  if (!exists $ATTRIBUTES{$object_type}) {
    die "Can't add default attribs for unknown Schema " . "object type '$object_type'.";
  }

  for my $attr (
    grep { !exists $hashref->{$_} }
    keys %{ $ATTRIBUTES{$object_type} }
  ) {
    $hashref->{$attr} = $ATTRIBUTES{$object_type}{$attr};
  }

  return $hashref;
}

# Format test name so it will prepend the test names used below.
sub t_name {
  my $name = shift;
  $name ||= "";
  $name = "$name - " if $name;
  return $name;
}

sub field_ok {
  my ($f1, $test, $name) = @_;
  my $t_name = t_name($name);
  default_attribs($test, "field");

  unless ($f1) {
    fail " Field '$test->{name}' doesn't exist!";

    # TODO Do a skip on the following tests. Currently the test counts wont
    # match at the end. So at least it fails.
    return;
  }

  my $full_name = $f1->table->name . "." . $test->{name};

  is($f1->name, $test->{name}, "${t_name}Field '$full_name'");

  is($f1->is_valid, $test->{is_valid}, "$t_name    is " . ($test->{is_valid} ? '' : 'not ') . 'valid');

  is($f1->data_type, $test->{data_type}, "$t_name    type is '$test->{data_type}'");

  is($f1->size, $test->{size}, "$t_name    size is '$test->{size}'");

  is(
    $f1->default_value,
    $test->{default_value},
    "$t_name    default value is "
        . (
          defined($test->{default_value})
          ? "'$test->{default_value}'"
          : "UNDEF"
        )
  );

  is($f1->is_nullable, $test->{is_nullable}, "$t_name    " . ($test->{is_nullable} ? 'can' : 'cannot') . ' be null');

  is($f1->is_unique, $test->{is_unique}, "$t_name    " . ($test->{is_unique} ? 'can' : 'cannot') . ' be unique');

  is(
    $f1->is_primary_key,
    $test->{is_primary_key},
    "$t_name    is " . ($test->{is_primary_key} ? '' : 'not ') . 'a primary_key'
  );

  is(
    $f1->is_foreign_key,
    $test->{is_foreign_key},
    "$t_name    is " . ($test->{is_foreign_key} ? '' : 'not') . ' a foreign_key'
  );

  is(
    $f1->is_auto_increment,
    $test->{is_auto_increment},
    "$t_name    is " . ($test->{is_auto_increment} ? '' : 'not ') . 'an auto_increment'
  );

  is($f1->comments, $test->{comments}, "$t_name    comments");

  is_deeply({ $f1->extra }, $test->{extra}, "$t_name    extra");
}

sub constraint_ok {
  my ($obj, $test, $name) = @_;
  my $t_name = t_name($name);
  default_attribs($test, "constraint");

  is($obj->name, $test->{name}, "${t_name}Constraint '$test->{name}'");

  is($obj->type, $test->{type}, "$t_name    type is '$test->{type}'");

  is($obj->deferrable, $test->{deferrable}, "$t_name    " . ($test->{deferrable} ? 'can' : 'cannot') . ' be deferred');

  is($obj->is_valid, $test->{is_valid}, "$t_name    is " . ($test->{is_valid} ? '' : 'not ') . 'valid');

  is($obj->table->name, $test->{table}, "$t_name    table is '$test->{table}'");

  is($obj->expression, $test->{expression}, "$t_name    expression is '$test->{expression}'");

  is_deeply([ $obj->fields ], $test->{fields}, "$t_name    fields are '" . join(",", @{ $test->{fields} }) . "'");

  is($obj->reference_table, $test->{reference_table}, "$t_name    reference_table is '$test->{reference_table}'");

  is_deeply(
    [ $obj->reference_fields ],
    $test->{reference_fields},
    "$t_name    reference_fields are '" . join(",", @{ $test->{reference_fields} }) . "'"
  );

  is($obj->match_type, $test->{match_type}, "$t_name    match_type is '$test->{match_type}'");

  is($obj->on_delete, $test->{on_delete}, "$t_name    on_delete is '$test->{on_delete}'");

  is($obj->on_update, $test->{on_update}, "$t_name    on_update is '$test->{on_update}'");

  is_deeply([ $obj->options ], $test->{options}, "$t_name    options are '" . join(",", @{ $test->{options} }) . "'");

  is_deeply({ $obj->extra }, $test->{extra}, "$t_name    extra");
}

sub index_ok {
  my ($obj, $test, $name) = @_;
  my $t_name = t_name($name);
  default_attribs($test, "index");

  is($obj->name, $test->{name}, "${t_name}Index '$test->{name}'");

  is($obj->is_valid, $test->{is_valid}, "$t_name    is " . ($test->{is_valid} ? '' : 'not ') . 'valid');

  is($obj->type, $test->{type}, "$t_name    type is '$test->{type}'");

  is_deeply([ $obj->fields ], $test->{fields}, "$t_name    fields are '" . join(",", @{ $test->{fields} }) . "'");

  is_deeply([ $obj->options ], $test->{options}, "$t_name    options are '" . join(",", @{ $test->{options} }) . "'");

  is_deeply({ $obj->extra }, $test->{extra}, "$t_name    extra");
}

sub trigger_ok {
  my ($obj, $test, $name) = @_;
  my $t_name = t_name($name);
  default_attribs($test, "index");

  is($obj->name, $test->{name}, "${t_name}Trigger '$test->{name}'");

  is($obj->is_valid, $test->{is_valid}, "$t_name    is " . ($test->{is_valid} ? '' : 'not ') . 'valid');

  is(
    $obj->perform_action_when,
    $test->{perform_action_when},
    "$t_name    perform_action_when is '$test->{perform_action_when}'"
  );

  is(
    join(',', $obj->database_events),
    $test->{database_events},
    sprintf("%s    database_events is '%s'", $t_name, $test->{'database_events'},)
  );

  is($obj->on_table, $test->{on_table}, "$t_name    on_table is '$test->{on_table}'");

  is($obj->scope, $test->{scope}, "$t_name    scope is '$test->{scope}'")
      if exists $test->{scope};

  is($obj->action, $test->{action}, "$t_name    action is '$test->{action}'");

  is_deeply({ $obj->extra }, $test->{extra}, "$t_name    extra");
}

sub view_ok {
  my ($obj, $test, $name) = @_;
  my $t_name = t_name($name);
  default_attribs($test, "index");

  #isa_ok( $v, 'SQL::Translator::Schema::View', 'View' );

  is($obj->name, $test->{name}, "${t_name}View '$test->{name}'");

  is($obj->is_valid, $test->{is_valid}, "$t_name    is " . ($test->{is_valid} ? '' : 'not ') . 'valid');

  is($obj->sql, $test->{sql}, "$t_name    sql is '$test->{sql}'");

  is_deeply([ $obj->fields ], $test->{fields}, "$t_name    fields are '" . join(",", @{ $test->{fields} }) . "'");

  is_deeply({ $obj->extra }, $test->{extra}, "$t_name    extra");
}

sub procedure_ok {
  my ($obj, $test, $name) = @_;
  my $t_name = t_name($name);
  default_attribs($test, "index");

  #isa_ok( $v, 'SQL::Translator::Schema::View', 'View' );

  is($obj->name, $test->{name}, "${t_name}Procedure '$test->{name}'");

  is($obj->sql, $test->{sql}, "$t_name    sql is '$test->{sql}'");

  is_deeply([ $obj->parameters ],
    $test->{parameters}, "$t_name    parameters are '" . join(",", @{ $test->{parameters} }) . "'");

  is($obj->comments, $test->{comments}, "$t_name    comments is '$test->{comments}'");

  is($obj->owner, $test->{owner}, "$t_name    owner is '$test->{owner}'");

  is_deeply({ $obj->extra }, $test->{extra}, "$t_name    extra");
}

sub table_ok {
  my ($obj, $test, $name) = @_;
  my $t_name = t_name($name);
  default_attribs($test, "table");
  my %arg = %$test;

  my $tbl_name = $arg{name} || die "Need a table name to test.";
  is($obj->{name}, $arg{name}, "${t_name}Table '$arg{name}'");

  is_deeply([ $obj->options ], $test->{options}, "$t_name    options are '" . join(",", @{ $test->{options} }) . "'");

  is_deeply({ $obj->extra }, $test->{extra}, "$t_name    extra");

  # Fields
  if ($arg{fields}) {
    my @fldnames = map { $_->{name} } @{ $arg{fields} };
    is_deeply([ map { $_->name } $obj->get_fields ],
      [@fldnames], "${t_name}    field names are " . join(", ", @fldnames));
    foreach (@{ $arg{fields} }) {
      my $f_name = $_->{name} || die "Need a field name to test.";
      next unless my $fld = $obj->get_field($f_name);
      field_ok($fld, $_, $name);
    }
  } else {
    is(scalar($obj->get_fields), undef, "${t_name}    has no fields.");
  }

  # Constraints and Indices
  _test_kids(
    $obj, $test, $name,
    {
      constraint => 'constraints',
      index      => 'indices',
    }
  );
}

sub _test_kids {
  my ($obj, $test, $name, $kids) = @_;
  my $t_name   = t_name($name);
  my $obj_name = ref $obj;
  ($obj_name) = $obj_name =~ m/^.*::(.*)$/;

  while (my ($object_type, $plural) = each %$kids) {
    next unless defined $test->{$plural};

    if (my @tests = @{ $test->{$plural} }) {
      my $meth    = "get_$plural";
      my @objects = $obj->$meth;
      is(scalar(@objects), scalar(@tests), "${t_name}$obj_name has " . scalar(@tests) . " $plural");

      for my $object (@objects) {
        my $ans = { lc($obj_name) => $obj->name, %{ shift @tests } };

        my $meth = "${object_type}_ok";
        {
          no strict 'refs';
          $meth->($object, $ans, $name);
        }
      }
    }
  }
}

sub schema_ok {
  my ($obj, $test, $name) = @_;
  my $t_name = t_name($name);
  default_attribs($test, "schema");

  is($obj->name, $test->{name}, "${t_name}Schema name is '$test->{name}'");

  is($obj->database, $test->{database}, "$t_name    database is '$test->{database}'");

  is_deeply({ $obj->extra }, $test->{extra}, "$t_name    extra");

  is($obj->is_valid, $test->{is_valid}, "$t_name    is " . ($test->{is_valid} ? '' : 'not ') . 'valid');

  # Tables
  if ($test->{tables}) {
    is_deeply(
      [ map { $_->name } $obj->get_tables ],
      [ map { $_->{name} } @{ $test->{tables} } ],
      "${t_name}    table names match"
    );
    foreach (@{ $test->{tables} }) {
      my $t_name = $_->{name} || die "Need a table name to test.";
      table_ok($obj->get_table($t_name), $_, $name);
    }
  } else {
    is(scalar($obj->get_tables), undef, "${t_name}    has no tables.");
  }

  # Procedures, Triggers, Views
  _test_kids(
    $obj, $test, $name,
    {
      procedure => 'procedures',
      trigger   => 'triggers',
      view      => 'views',
    }
  );
}

# maybe_plan($ntests, @modules)
#
# Calls plan $ntests if @modules can all be loaded; otherwise,
# calls skip_all with an explanation of why the tests were skipped.
sub maybe_plan {
  my ($ntests, @modules) = @_;
  my @errors;

  for my $module (@modules) {
    eval "use $module;";
    next if !$@;

    if ($@ =~ /Can't locate (\S+)/) {
      my $mod = $1;
      $mod =~ s/\.pm$//;
      $mod =~ s#/#::#g;
      push @errors, $mod;
    } elsif ($@ =~ /([\w\:]+ version [\d\.]+) required.+?this is only version/) {
      push @errors, $1;
    } elsif ($@ =~ /Can't load .+? for module .+?DynaLoader\.pm/i) {
      push @errors, $module;
    } else {
      (my $err = $@) =~ s/\n+/\\n/g;    # Can't have newlines in the skip message
      push @errors, "$module: $err";
    }
  }

  if (@errors) {
    my $msg = sprintf "Missing dependenc%s: %s", @errors == 1 ? 'y' : 'ies', join ", ", @errors;
    plan skip_all => $msg;
  }
  return unless defined $ntests;

  if ($ntests ne 'no_plan') {
    plan tests => $ntests;
  } else {
    plan 'no_plan';
  }
}

1;    # compile please ===========================================================
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

=head1 DESCRIPTION

Provides a set of Test::More tests for Schema objects. Testing a parsed
schema is then as easy as writing a perl data structure describing how you
expect the schema to look. Also provides C<maybe_plan> for conditionally running
tests based on their dependencies.

The data structures given to the test subs don't have to include all the
possible values, only the ones you expect to have changed. Any left out will be
tested to make sure they are still at their default value. This is a useful
check that you your parser hasn't accidentally set schema values you didn't
expect it to.

For an example of the output run the F<t/16xml-parser.t> test.

=head1 Tests

All the tests take a first arg of the schema object to test, followed by a
hash ref describing how you expect that object to look (you only need give the
attributes you expect to have changed from the default).
The 3rd arg is an optional test name to prepend to all the generated test
names.

=head2 table_ok

=head2 field_ok

=head2 constraint_ok

=head2 index_ok

=head2 view_ok

=head2 trigger_ok

=head2 procedure_ok

=head1 CONDITIONAL TESTS

The C<maybe_plan> function handles conditionally running an individual
test.  It is here to enable running the test suite even when dependencies
are missing; not having (for example) GraphViz installed should not keep
the test suite from passing.

C<maybe_plan> takes the number of tests to (maybe) run, and a list of
modules on which test execution depends:

    maybe_plan(180, 'SQL::Translator::Parser::MySQL');

If one of C<SQL::Translator::Parser::MySQL>'s dependencies does not exist,
then the test will be skipped.

Instead of a number of tests, you can pass C<undef> if you're using
C<done_testing()>, or C<'no_plan'> if you don't want a plan at all.

=head1 EXPORTS

table_ok, field_ok, constraint_ok, index_ok, view_ok, trigger_ok, procedure_ok,
maybe_plan

=head1 TODO

=over 4

=item Test the tests!

=item Test Count Constants

Constants to give the number of tests each C<*_ok> sub uses. e.g. How many tests
does C<field_ok> run? Can then use these to set up the test plan easily.

=item Test skipping

As the test subs wrap up lots of tests in one call you can't skip individual
tests only whole sets e.g. a whole table or field.
We could add C<skip_*> items to the test hashes to allow per test skips. e.g.

 skip_is_primary_key => "Need to fix primary key parsing.",

=item yaml test specs

Maybe have the test subs also accept yaml for the test hash ref as it is much
nicer for writing big data structures. We can then define tests as in input
schema file and test yaml file to compare it against.

=back

=head1 AUTHOR

Mark D. Addison E<lt>mark.addison@itn.co.ukE<gt>,
Darren Chamberlain <darren@cpan.org>.

Thanks to Ken Y. Clark for the original table and field test code taken from
his mysql test.

=head1 SEE ALSO

perl(1), SQL::Translator, SQL::Translator::Schema, Test::More.

=cut
