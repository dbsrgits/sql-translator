package SQL::Translator::Schema::Trigger;

=pod

=head1 NAME

SQL::Translator::Schema::Trigger - SQL::Translator trigger object

=head1 SYNOPSIS

  use SQL::Translator::Schema::Trigger;
  my $trigger = SQL::Translator::Schema::Trigger->new(
    name                => 'foo',
    perform_action_when => 'before', # or after
    database_events     => [qw/update insert/], # also update, update_on, delete
    fields              => [],       # if event is "update"
    on_table            => 'foo',    # table name
    action              => '...',    # text of trigger
    schema              => $schema,  # Schema object
    scope               => 'row',    # or statement
  );

=head1 DESCRIPTION

C<SQL::Translator::Schema::Trigger> is the trigger object.

=head1 METHODS

=cut

use Moo;
use SQL::Translator::Utils qw(parse_list_arg ex2err throw);
use SQL::Translator::Types qw(schema_obj enum);
use List::MoreUtils qw(uniq);
use Sub::Quote qw(quote_sub);

extends 'SQL::Translator::Schema::Object';

our $VERSION = '1.59';

=head2 new

Object constructor.

  my $schema = SQL::Translator::Schema::Trigger->new;

=cut

around BUILDARGS => sub {
    my ($orig, $self, @args) = @_;
    my $args = $self->$orig(@args);
    if (exists $args->{on_table}) {
        my $arg = delete $args->{on_table};
        my $table = $args->{schema}->get_table($arg)
            or die "Table named $arg doesn't exist";
        $args->{table} = $table;
    }
    if (exists $args->{database_event}) {
        $args->{database_events} = delete $args->{database_event};
    }
    return $args;
};

=head2 perform_action_when

Gets or sets whether the event happens "before" or "after" the
C<database_event>.

  $trigger->perform_action_when('after');

=cut

has perform_action_when => (
    is => 'rw',
    coerce => quote_sub(q{ defined $_[0] ? lc $_[0] : $_[0] }),
    isa => enum([qw(before after)], {
        msg => "Invalid argument '%s' to perform_action_when",
        allow_undef => 1,
    }),
);

around perform_action_when => \&ex2err;

sub database_event {

=pod

=head2 database_event

Obsolete please use database_events!

=cut

    my $self = shift;

    return $self->database_events( @_ );
}

=head2 database_events

Gets or sets the events that triggers the trigger.

  my $ok = $trigger->database_events('insert');

=cut

has database_events => (
    is => 'rw',
    coerce => quote_sub(q{ [ map { lc } ref $_[0] eq 'ARRAY' ? @{$_[0]} : ($_[0]) ] }),
    isa => sub {
        my @args    = @{$_[0]};
        my %valid   = map { $_, 1 } qw[ insert update update_on delete ];
        my @invalid = grep { !defined $valid{ $_ } } @args;

        if ( @invalid ) {
            throw(
                sprintf("Invalid events '%s' in database_events",
                    join(', ', @invalid)
                )
            );
        }
    },
);

around database_events => sub {
    my ($orig,$self) = (shift, shift);

    if (@_) {
        ex2err($orig, $self, ref $_[0] eq 'ARRAY' ? $_[0] : \@_)
            or return;
    }

    return wantarray
        ? @{ $self->$orig || [] }
        : $self->$orig;
};

=head2 fields

Gets and set which fields to monitor for C<database_event>.

  $view->fields('id');
  $view->fields('id', 'name');
  $view->fields( 'id, name' );
  $view->fields( [ 'id', 'name' ] );
  $view->fields( qw[ id name ] );

  my @fields = $view->fields;

=cut

has fields => (
    is => 'rw',
    coerce => sub {
        my @fields = uniq @{parse_list_arg($_[0])};
        @fields ? \@fields : undef;
    },
);

around fields => sub {
    my $orig   = shift;
    my $self   = shift;
    my $fields = parse_list_arg( @_ );
    $self->$orig($fields) if @$fields;

    return wantarray ? @{ $self->$orig || [] } : $self->$orig;
};

=head2 table

Gets or set the table on which the trigger works, as a L<SQL::Translator::Schema::Table> object.
  $trigger->table($triggered_table);

=cut

has table => ( is => 'rw', isa => schema_obj('Table'), weak_ref => 1 );

around table => \&ex2err;

sub on_table {

=pod

=head2 on_table

Gets or set the table name on which the trigger works, as a string.
  $trigger->on_table('foo');

=cut

    my ($self, $arg) = @_;
    if ( @_ == 2 ) {
        my $table = $self->schema->get_table($arg);
        die "Table named $arg doesn't exist"
            if !$table;
        $self->table($table);
    }
    return $self->table->name;
}

=head2 action

Gets or set the action of the trigger.

  $trigger->action(
      q[
        BEGIN
          select ...;
          update ...;
        END
      ]
  );

=cut

has action => ( is => 'rw', default => quote_sub(q{ '' }) );

sub is_valid {

=pod

=head2 is_valid

Determine whether the trigger is valid or not.

  my $ok = $trigger->is_valid;

=cut

    my $self = shift;

    for my $attr (
        qw[ name perform_action_when database_events on_table action ]
    ) {
        return $self->error("Invalid: missing '$attr'") unless $self->$attr();
    }

    return $self->error("Missing fields for UPDATE ON") if
        $self->database_event eq 'update_on' && !$self->fields;

    return 1;
}

=head2 name

Get or set the trigger's name.

  my $name = $trigger->name('foo');

=cut

has name => ( is => 'rw', default => quote_sub(q{ '' }) );

=head2 order

Get or set the trigger's order.

  my $order = $trigger->order(3);

=cut

has order => ( is => 'rw', default => quote_sub(q{ 0 }) );

around order => sub {
    my ( $orig, $self, $arg ) = @_;

    if ( defined $arg && $arg =~ /^\d+$/ ) {
        return $self->$orig($arg);
    }

    return $self->$orig;
};

=head2 scope

Get or set the trigger's scope (row or statement).

    my $scope = $trigger->scope('statement');

=cut

has scope => (
    is => 'rw',
    isa => enum([qw(row statement)], {
        msg => "Invalid scope '%s'", icase => 1, allow_undef => 1,
    }),
);

around scope => \&ex2err;


=head2 schema

Get or set the trigger's schema object.

  $trigger->schema( $schema );
  my $schema = $trigger->schema;

=cut

has schema => (is => 'rw', isa => schema_obj('Schema'), weak_ref => 1 );

around schema => \&ex2err;

sub compare_arrays {

=pod

=head2 compare_arrays

Compare two arrays.

=cut

    my ($first, $second) = @_;
    no warnings;  # silence spurious -w undef complaints

    return 0 unless (ref $first eq 'ARRAY' and ref $second eq 'ARRAY' ) ;

    return 0 unless @$first == @$second;

    my @first = sort @$first;

    my @second = sort @$second;

    for (my $i = 0; $i < scalar @first; $i++) {
        return 0 if @first[$i] ne @second[$i];
    }

    return 1;
}

=head2 equals

Determines if this trigger is the same as another

  my $is_identical = $trigger1->equals( $trigger2 );

=cut

around equals => sub {
    my $orig             = shift;
    my $self             = shift;
    my $other            = shift;
    my $case_insensitive = shift;

    return 0 unless $self->$orig($other);

    my %names;
    for my $name ( $self->name, $other->name ) {
        $name = lc $name if $case_insensitive;
        $names{ $name }++;
    }

    if ( keys %names > 1 ) {
        return $self->error('Names not equal');
    }

    if ( !$self->perform_action_when eq $other->perform_action_when ) {
        return $self->error('perform_action_when differs');
    }

    if (
        !compare_arrays( [$self->database_events], [$other->database_events] )
    ) {
        return $self->error('database_events differ');
    }

    if ( $self->on_table ne $other->on_table ) {
        return $self->error('on_table differs');
    }

    if ( $self->action ne $other->action ) {
        return $self->error('action differs');
    }

    if (
        !$self->_compare_objects( scalar $self->extra, scalar $other->extra )
    ) {
        return $self->error('extras differ');
    }

    return 1;
};

# Must come after all 'has' declarations
around new => \&ex2err;

1;

=pod

=head1 AUTHORS

Anonymous,
Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut
