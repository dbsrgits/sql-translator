package SQL::Translator::Schema::Trigger;

# ----------------------------------------------------------------------
# $Id: Trigger.pm,v 1.9 2006-06-07 16:37:33 schiffbruechige Exp $
# ----------------------------------------------------------------------
# Copyright (C) 2002-4 SQLFairy Authors
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

SQL::Translator::Schema::Trigger - SQL::Translator trigger object

=head1 SYNOPSIS

  use SQL::Translator::Schema::Trigger;
  my $trigger = SQL::Translator::Schema::Trigger->new(
      name                => 'foo',
      perform_action_when => 'before', # or after
      database_event      => 'insert', # or update, update_on, delete
      fields              => [],       # fields if event is "update"
      on_table            => 'foo',    # table name
      action              => '...',    # text of trigger
      schema              => $schema,  # Schema object
  );

=head1 DESCRIPTION

C<SQL::Translator::Schema::Trigger> is the trigger object.

=head1 METHODS

=cut

use strict;
use SQL::Translator::Utils 'parse_list_arg';

use base 'SQL::Translator::Schema::Object';

use vars qw($VERSION $TABLE_COUNT $VIEW_COUNT);

$VERSION = sprintf "%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/;

# ----------------------------------------------------------------------

__PACKAGE__->_attributes( qw/
    name schema perform_action_when database_event fields table on_table action
    order
/);

=pod

=head2 new

Object constructor.

  my $schema = SQL::Translator::Schema::Trigger->new;

=cut

# ----------------------------------------------------------------------
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

# ----------------------------------------------------------------------
sub database_event {

=pod

=head2 database_event

Gets or sets the event that triggers the trigger.

  my $ok = $trigger->database_event('insert');

=cut

    my $self = shift;

    if ( my $arg = shift ) {
        $arg =  lc $arg;
        $arg =~ s/\s+/ /g;
        if ( $arg =~ /^(insert|update|update_on|delete)$/ ) {
            $self->{'database_event'} = $arg;
        }
        else {
            return 
                $self->error("Invalid argument '$arg' to database_event");
        }
    }

    return $self->{'database_event'};
}

# ----------------------------------------------------------------------
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

# ----------------------------------------------------------------------
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

# ----------------------------------------------------------------------
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

# ----------------------------------------------------------------------
sub action {

=pod

=head2 action

Gets or set the actions of the trigger.

  $trigger->actions(
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

# ----------------------------------------------------------------------
sub is_valid {

=pod

=head2 is_valid

Determine whether the trigger is valid or not.

  my $ok = $trigger->is_valid;

=cut

    my $self = shift;

    for my $attr ( 
        qw[ name perform_action_when database_event on_table action ] 
    ) {
        return $self->error("No $attr") unless $self->$attr();
    }
    
    return $self->error("Missing fields for UPDATE ON") if 
        $self->database_event eq 'update_on' && !$self->fields;

    return 1;
}

# ----------------------------------------------------------------------
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

# ----------------------------------------------------------------------
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

# ----------------------------------------------------------------------
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

# ----------------------------------------------------------------------
sub equals {

=pod

=head2 equals

Determines if this trigger is the same as another

  my $isIdentical = $trigger1->equals( $trigger2 );

=cut

    my $self = shift;
    my $other = shift;
    my $case_insensitive = shift;
    
    return 0 unless $self->SUPER::equals($other);
    return 0 unless $case_insensitive ? uc($self->name) eq uc($other->name) : $self->name eq $other->name;
    #return 0 unless $self->is_valid eq $other->is_valid;
    return 0 unless $self->perform_action_when eq $other->perform_action_when;
    return 0 unless $self->database_event eq $other->database_event;
    return 0 unless $self->on_table eq $other->on_table;
    return 0 unless $self->action eq $other->action;
    return 0 unless $self->_compare_objects(scalar $self->extra, scalar $other->extra);
    return 1;
}

# ----------------------------------------------------------------------
sub DESTROY {
    my $self = shift;
    undef $self->{'schema'}; # destroy cyclical reference
}

1;

# ----------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=cut
