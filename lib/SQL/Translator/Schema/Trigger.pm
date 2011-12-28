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

use strict;
use warnings;
use SQL::Translator::Utils 'parse_list_arg';

use base 'SQL::Translator::Schema::Object';

use Carp;

our ( $TABLE_COUNT, $VIEW_COUNT );

our $VERSION = '1.59';

__PACKAGE__->_attributes( qw/
    name schema perform_action_when database_events database_event
    fields table on_table action order scope
/);

=pod

=head2 new

Object constructor.

  my $schema = SQL::Translator::Schema::Trigger->new;

=cut

sub perform_action_when {

=pod

=head2 perform_action_when

Gets or sets whether the event happens "before" or "after" the
C<database_event>.

  $trigger->perform_action_when('after');

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        $arg =  lc $arg;
        $arg =~ s/\s+/ /g;
        if ( $arg =~ m/^(before|after)$/i ) {
            $self->{'perform_action_when'} = $arg;
        }
        else {
            return
                $self->error("Invalid argument '$arg' to perform_action_when");
        }
    }

    return $self->{'perform_action_when'};
}

sub database_event {

=pod

=head2 database_event

Obsolete please use database_events!

=cut

    my $self = shift;

    return $self->database_events( @_ );
}

sub database_events {

=pod

=head2 database_events

Gets or sets the events that triggers the trigger.

  my $ok = $trigger->database_events('insert');

=cut

    my $self = shift;
    my @args = ref $_[0] eq 'ARRAY' ? @{ $_[0] } : @_;

    if ( @args ) {
        @args       = map { s/\s+/ /g; lc $_ } @args;
        my %valid   = map { $_, 1 } qw[ insert update update_on delete ];
        my @invalid = grep { !defined $valid{ $_ } } @args;

        if ( @invalid ) {
            return $self->error(
                sprintf("Invalid events '%s' in database_events",
                    join(', ', @invalid)
                )
            );
        }

        $self->{'database_events'} = [ @args ];
    }

    return wantarray
        ? @{ $self->{'database_events'} || [] }
        : $self->{'database_events'};
}

sub fields {

=pod

=head2 fields

Gets and set which fields to monitor for C<database_event>.

  $view->fields('id');
  $view->fields('id', 'name');
  $view->fields( 'id, name' );
  $view->fields( [ 'id', 'name' ] );
  $view->fields( qw[ id name ] );

  my @fields = $view->fields;

=cut

    my $self = shift;
    my $fields = parse_list_arg( @_ );

    if ( @$fields ) {
        my ( %unique, @unique );
        for my $f ( @$fields ) {
            next if $unique{ $f };
            $unique{ $f } = 1;
            push @unique, $f;
        }

        $self->{'fields'} = \@unique;
    }

    return wantarray ? @{ $self->{'fields'} || [] } : $self->{'fields'};
}

sub table {

=pod

=head2 table

Gets or set the table on which the trigger works, as a L<SQL::Translator::Schema::Table> object.
  $trigger->table($triggered_table);

=cut

    my ($self, $arg) = @_;
    if ( @_ == 2 ) {
        $self->error("Table attribute of a ".__PACKAGE__.
                     " must be a SQL::Translator::Schema::Table")
            unless ref $arg and $arg->isa('SQL::Translator::Schema::Table');
        $self->{table} = $arg;
    }
    return $self->{table};
}

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

sub action {

=pod

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

    my $self = shift;
    my $arg  = shift || '';
    $self->{'action'} = $arg if $arg;
    return $self->{'action'};
}

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

sub name {

=pod

=head2 name

Get or set the trigger's name.

  my $name = $trigger->name('foo');

=cut

    my $self        = shift;
    $self->{'name'} = shift if @_;
    return $self->{'name'} || '';
}

sub order {

=pod

=head2 order

Get or set the trigger's order.

  my $order = $trigger->order(3);

=cut

    my ( $self, $arg ) = @_;

    if ( defined $arg && $arg =~ /^\d+$/ ) {
        $self->{'order'} = $arg;
    }

    return $self->{'order'} || 0;
}


sub scope {

=pod

=head2 scope

Get or set the trigger's scope (row or statement).

    my $scope = $trigger->scope('statement');

=cut

    my ( $self, $arg ) = @_;

    if ( defined $arg ) {
        return $self->error( "Invalid scope '$arg'" )
            unless $arg =~ /^(row|statement)$/i;

        $self->{scope} = $arg;
    }

    return $self->{scope} || '';
}

sub schema {

=pod

=head2 schema

Get or set the trigger's schema object.

  $trigger->schema( $schema );
  my $schema = $trigger->schema;

=cut

    my $self = shift;
    if ( my $arg = shift ) {
        return $self->error('Not a schema object') unless
            UNIVERSAL::isa( $arg, 'SQL::Translator::Schema' );
        $self->{'schema'} = $arg;
    }

    return $self->{'schema'};
}

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

sub equals {

=pod

=head2 equals

Determines if this trigger is the same as another

  my $is_identical = $trigger1->equals( $trigger2 );

=cut

    my $self             = shift;
    my $other            = shift;
    my $case_insensitive = shift;

    return 0 unless $self->SUPER::equals($other);

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
}

sub DESTROY {
    my $self = shift;
    undef $self->{'schema'}; # destroy cyclical reference
}

1;

=pod

=head1 AUTHORS

Anonymous,
Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut
