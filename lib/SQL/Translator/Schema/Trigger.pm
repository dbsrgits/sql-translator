package SQL::Translator::Schema::Trigger;

# ----------------------------------------------------------------------
# $Id: Trigger.pm,v 1.2 2003-10-08 17:33:47 kycl4rk Exp $
# ----------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>
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
use Class::Base;
use SQL::Translator::Utils 'parse_list_arg';

use base 'Class::Base';
use vars qw($VERSION $TABLE_COUNT $VIEW_COUNT);

$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;

# ----------------------------------------------------------------------
sub init {

=pod

=head2 new

Object constructor.

  my $schema = SQL::Translator::Schema::Trigger->new;

=cut

    my ( $self, $config ) = @_;

    for my $arg ( 
        qw[ 
            name perform_action_when database_event fields 
            on_table action schema
        ] 
    ) {
        next unless $config->{ $arg };
        $self->$arg( $config->{ $arg } );# or return;
    }

    return $self;
}

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
sub on_table {

=pod

=head2 on_table

Gets or set the table name on which the trigger works.

  $trigger->table('foo');

=cut

    my $self = shift;
    my $arg  = shift || '';
    $self->{'on_table'} = $arg if $arg;
    return $self->{'on_table'};
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
