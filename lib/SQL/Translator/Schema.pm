package SQL::Translator::Schema;

# ----------------------------------------------------------------------
# Copyright (C) 2002-2009 SQLFairy Authors
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

SQL::Translator::Schema - SQL::Translator schema object

=head1 SYNOPSIS

  use SQL::Translator::Schema;
  my $schema   =  SQL::Translator::Schema->new(
      name     => 'Foo',
      database => 'MySQL',
  );
  my $table    = $schema->add_table( name => 'foo' );
  my $view     = $schema->add_view( name => 'bar', sql => '...' );


=head1 DESCSIPTION

C<SQL::Translator::Schema> is the object that accepts, validates, and
returns the database structure.

=head1 METHODS

=cut

use strict;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Schema::Procedure;
use SQL::Translator::Schema::Table;
use SQL::Translator::Schema::Trigger;
use SQL::Translator::Schema::View;

use SQL::Translator::Utils 'parse_list_arg';

use base 'SQL::Translator::Schema::Object';
use vars qw[ $VERSION ];

$VERSION = '1.59';

__PACKAGE__->_attributes(qw/name database translator/);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new (@_)
    or return;

  $self->{_order} = { map { $_ => 0 } qw/
    table
    view
    trigger
    proc
  /};

  return $self;
}

# ----------------------------------------------------------------------
sub as_graph {

=pod

=head2 as_graph

Returns the schema as an L<SQL::Translator::Schema::Graph> object.

=cut
    require  SQL::Translator::Schema::Graph;

    my $self = shift;

    return SQL::Translator::Schema::Graph->new(
        translator => $self->translator );
}

# ----------------------------------------------------------------------
sub as_graph_pm {

=pod

=head2 as_graph_pm

Returns a Graph::Directed object with the table names for nodes.

=cut

    require Graph::Directed;

    my $self = shift;
    my $g    = Graph::Directed->new;
    
    for my $table ( $self->get_tables ) { 
        my $tname  = $table->name;
        $g->add_vertex( $tname );
    
        for my $field ( $table->get_fields ) {
            if ( $field->is_foreign_key ) {
                my $fktable = $field->foreign_key_reference->reference_table;

                $g->add_edge( $fktable, $tname );
            }
        }
    }

    return $g;
}

# ----------------------------------------------------------------------
sub add_table {

=pod

=head2 add_table

Add a table object.  Returns the new SQL::Translator::Schema::Table object.
The "name" parameter is required.  If you try to create a table with the
same name as an existing table, you will get an error and the table will 
not be created.

  my $t1 = $schema->add_table( name => 'foo' ) or die $schema->error;
  my $t2 = SQL::Translator::Schema::Table->new( name => 'bar' );
  $t2    = $schema->add_table( $table_bar ) or die $schema->error;

=cut

    my $self        = shift;
    my $table_class = 'SQL::Translator::Schema::Table';
    my $table;

    if ( UNIVERSAL::isa( $_[0], $table_class ) ) {
        $table = shift;
        $table->schema($self);
    }
    else {
        my %args = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;
        $args{'schema'} = $self;
        $table = $table_class->new( \%args )
          or return $self->error( $table_class->error );
    }

    $table->order( ++$self->{_order}{table} );

    # We know we have a name as the Table->new above errors if none given.
    my $table_name = $table->name;

    if ( defined $self->{'tables'}{$table_name} ) {
        return $self->error(qq[Can't create table: "$table_name" exists]);
    }
    else {
        $self->{'tables'}{$table_name} = $table;
    }

    return $table;
}

# ----------------------------------------------------------------------
sub drop_table {

=pod

=head2 drop_table

Remove a table from the schema. Returns the table object if the table was found
and removed, an error otherwise. The single parameter can be either a table
name or an C<SQL::Translator::Schema::Table> object. The "cascade" parameter
can be set to 1 to also drop all triggers on the table, default is 0.

  $schema->drop_table('mytable');
  $schema->drop_table('mytable', cascade => 1);

=cut

    my $self        = shift;
    my $table_class = 'SQL::Translator::Schema::Table';
    my $table_name;

    if ( UNIVERSAL::isa( $_[0], $table_class ) ) {
        $table_name = shift->name;
    }
    else {
        $table_name = shift;
    }
    my %args    = @_;
    my $cascade = $args{'cascade'};

    if ( !exists $self->{'tables'}{$table_name} ) {
        return $self->error(qq[Can't drop table: $table_name" doesn't exist]);
    }

    my $table = delete $self->{'tables'}{$table_name};

    if ($cascade) {

        # Drop all triggers on this table
        $self->drop_trigger()
          for ( grep { $_->on_table eq $table_name } @{ $self->{'triggers'} } );
    }
    return $table;
}

# ----------------------------------------------------------------------
sub add_procedure {

=pod

=head2 add_procedure

Add a procedure object.  Returns the new SQL::Translator::Schema::Procedure
object.  The "name" parameter is required.  If you try to create a procedure
with the same name as an existing procedure, you will get an error and the
procedure will not be created.

  my $p1 = $schema->add_procedure( name => 'foo' );
  my $p2 = SQL::Translator::Schema::Procedure->new( name => 'bar' );
  $p2    = $schema->add_procedure( $procedure_bar ) or die $schema->error;

=cut

    my $self            = shift;
    my $procedure_class = 'SQL::Translator::Schema::Procedure';
    my $procedure;

    if ( UNIVERSAL::isa( $_[0], $procedure_class ) ) {
        $procedure = shift;
        $procedure->schema($self);
    }
    else {
        my %args = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;
        $args{'schema'} = $self;
        return $self->error('No procedure name') unless $args{'name'};
        $procedure = $procedure_class->new( \%args )
          or return $self->error( $procedure_class->error );
    }

    $procedure->order( ++$self->{_order}{proc} );
    my $procedure_name = $procedure->name
      or return $self->error('No procedure name');

    if ( defined $self->{'procedures'}{$procedure_name} ) {
        return $self->error(
            qq[Can't create procedure: "$procedure_name" exists] );
    }
    else {
        $self->{'procedures'}{$procedure_name} = $procedure;
    }

    return $procedure;
}

# ----------------------------------------------------------------------
sub drop_procedure {

=pod

=head2 drop_procedure

Remove a procedure from the schema. Returns the procedure object if the
procedure was found and removed, an error otherwise. The single parameter
can be either a procedure name or an C<SQL::Translator::Schema::Procedure>
object.

  $schema->drop_procedure('myprocedure');

=cut

    my $self       = shift;
    my $proc_class = 'SQL::Translator::Schema::Procedure';
    my $proc_name;

    if ( UNIVERSAL::isa( $_[0], $proc_class ) ) {
        $proc_name = shift->name;
    }
    else {
        $proc_name = shift;
    }

    if ( !exists $self->{'procedures'}{$proc_name} ) {
        return $self->error(
            qq[Can't drop procedure: $proc_name" doesn't exist]);
    }

    my $proc = delete $self->{'procedures'}{$proc_name};

    return $proc;
}

# ----------------------------------------------------------------------
sub add_trigger {

=pod

=head2 add_trigger

Add a trigger object.  Returns the new SQL::Translator::Schema::Trigger object.
The "name" parameter is required.  If you try to create a trigger with the
same name as an existing trigger, you will get an error and the trigger will 
not be created.

  my $t1 = $schema->add_trigger( name => 'foo' );
  my $t2 = SQL::Translator::Schema::Trigger->new( name => 'bar' );
  $t2    = $schema->add_trigger( $trigger_bar ) or die $schema->error;

=cut

    my $self          = shift;
    my $trigger_class = 'SQL::Translator::Schema::Trigger';
    my $trigger;

    if ( UNIVERSAL::isa( $_[0], $trigger_class ) ) {
        $trigger = shift;
        $trigger->schema($self);
    }
    else {
        my %args = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;
        $args{'schema'} = $self;
        return $self->error('No trigger name') unless $args{'name'};
        $trigger = $trigger_class->new( \%args )
          or return $self->error( $trigger_class->error );
    }

    $trigger->order( ++$self->{_order}{trigger} );

    my $trigger_name = $trigger->name or return $self->error('No trigger name');
    if ( defined $self->{'triggers'}{$trigger_name} ) {
        return $self->error(qq[Can't create trigger: "$trigger_name" exists]);
    }
    else {
        $self->{'triggers'}{$trigger_name} = $trigger;
    }

    return $trigger;
}

# ----------------------------------------------------------------------
sub drop_trigger {

=pod

=head2 drop_trigger

Remove a trigger from the schema. Returns the trigger object if the trigger was
found and removed, an error otherwise. The single parameter can be either a
trigger name or an C<SQL::Translator::Schema::Trigger> object.

  $schema->drop_trigger('mytrigger');

=cut

    my $self          = shift;
    my $trigger_class = 'SQL::Translator::Schema::Trigger';
    my $trigger_name;

    if ( UNIVERSAL::isa( $_[0], $trigger_class ) ) {
        $trigger_name = shift->name;
    }
    else {
        $trigger_name = shift;
    }

    if ( !exists $self->{'triggers'}{$trigger_name} ) {
        return $self->error(
            qq[Can't drop trigger: $trigger_name" doesn't exist]);
    }

    my $trigger = delete $self->{'triggers'}{$trigger_name};

    return $trigger;
}

# ----------------------------------------------------------------------
sub add_view {

=pod

=head2 add_view

Add a view object.  Returns the new SQL::Translator::Schema::View object.
The "name" parameter is required.  If you try to create a view with the
same name as an existing view, you will get an error and the view will 
not be created.

  my $v1 = $schema->add_view( name => 'foo' );
  my $v2 = SQL::Translator::Schema::View->new( name => 'bar' );
  $v2    = $schema->add_view( $view_bar ) or die $schema->error;

=cut

    my $self       = shift;
    my $view_class = 'SQL::Translator::Schema::View';
    my $view;

    if ( UNIVERSAL::isa( $_[0], $view_class ) ) {
        $view = shift;
        $view->schema($self);
    }
    else {
        my %args = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;
        $args{'schema'} = $self;
        return $self->error('No view name') unless $args{'name'};
        $view = $view_class->new( \%args ) or return $view_class->error;
    }

    $view->order( ++$self->{_order}{view} );
    my $view_name = $view->name or return $self->error('No view name');

    if ( defined $self->{'views'}{$view_name} ) {
        return $self->error(qq[Can't create view: "$view_name" exists]);
    }
    else {
        $self->{'views'}{$view_name} = $view;
    }

    return $view;
}

# ----------------------------------------------------------------------
sub drop_view {

=pod

=head2 drop_view

Remove a view from the schema. Returns the view object if the view was found
and removed, an error otherwise. The single parameter can be either a view
name or an C<SQL::Translator::Schema::View> object.

  $schema->drop_view('myview');

=cut

    my $self       = shift;
    my $view_class = 'SQL::Translator::Schema::View';
    my $view_name;

    if ( UNIVERSAL::isa( $_[0], $view_class ) ) {
        $view_name = shift->name;
    }
    else {
        $view_name = shift;
    }

    if ( !exists $self->{'views'}{$view_name} ) {
        return $self->error(qq[Can't drop view: $view_name" doesn't exist]);
    }

    my $view = delete $self->{'views'}{$view_name};

    return $view;
}

# ----------------------------------------------------------------------
sub database {

=pod

=head2 database

Get or set the schema's database.  (optional)

  my $database = $schema->database('PostgreSQL');

=cut

    my $self = shift;
    $self->{'database'} = shift if @_;
    return $self->{'database'} || '';
}

# ----------------------------------------------------------------------
sub is_valid {

=pod

=head2 is_valid

Returns true if all the tables and views are valid.

  my $ok = $schema->is_valid or die $schema->error;

=cut

    my $self = shift;

    return $self->error('No tables') unless $self->get_tables;

    for my $object ( $self->get_tables, $self->get_views ) {
        return $object->error unless $object->is_valid;
    }

    return 1;
}

# ----------------------------------------------------------------------
sub get_procedure {

=pod

=head2 get_procedure

Returns a procedure by the name provided.

  my $procedure = $schema->get_procedure('foo');

=cut

    my $self = shift;
    my $procedure_name = shift or return $self->error('No procedure name');
    return $self->error(qq[Table "$procedure_name" does not exist])
      unless exists $self->{'procedures'}{$procedure_name};
    return $self->{'procedures'}{$procedure_name};
}

# ----------------------------------------------------------------------
sub get_procedures {

=pod

=head2 get_procedures

Returns all the procedures as an array or array reference.

  my @procedures = $schema->get_procedures;

=cut

    my $self       = shift;
    my @procedures =
      map  { $_->[1] }
      sort { $a->[0] <=> $b->[0] }
      map  { [ $_->order, $_ ] } values %{ $self->{'procedures'} };

    if (@procedures) {
        return wantarray ? @procedures : \@procedures;
    }
    else {
        $self->error('No procedures');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub get_table {

=pod

=head2 get_table

Returns a table by the name provided.

  my $table = $schema->get_table('foo');

=cut

    my $self = shift;
    my $table_name = shift or return $self->error('No table name');
    my $case_insensitive = shift;
    if ( $case_insensitive ) {
    	$table_name = uc($table_name);
    	foreach my $table ( keys %{$self->{tables}} ) {
    		return $self->{tables}{$table} if $table_name eq uc($table);
    	}
    	return $self->error(qq[Table "$table_name" does not exist]);
    }
    return $self->error(qq[Table "$table_name" does not exist])
      unless exists $self->{'tables'}{$table_name};
    return $self->{'tables'}{$table_name};
}

# ----------------------------------------------------------------------
sub get_tables {

=pod

=head2 get_tables

Returns all the tables as an array or array reference.

  my @tables = $schema->get_tables;

=cut

    my $self   = shift;
    my @tables =
      map  { $_->[1] }
      sort { $a->[0] <=> $b->[0] }
      map  { [ $_->order, $_ ] } values %{ $self->{'tables'} };

    if (@tables) {
        return wantarray ? @tables : \@tables;
    }
    else {
        $self->error('No tables');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub get_trigger {

=pod

=head2 get_trigger

Returns a trigger by the name provided.

  my $trigger = $schema->get_trigger('foo');

=cut

    my $self = shift;
    my $trigger_name = shift or return $self->error('No trigger name');
    return $self->error(qq[Table "$trigger_name" does not exist])
      unless exists $self->{'triggers'}{$trigger_name};
    return $self->{'triggers'}{$trigger_name};
}

# ----------------------------------------------------------------------
sub get_triggers {

=pod

=head2 get_triggers

Returns all the triggers as an array or array reference.

  my @triggers = $schema->get_triggers;

=cut

    my $self     = shift;
    my @triggers =
      map  { $_->[1] }
      sort { $a->[0] <=> $b->[0] }
      map  { [ $_->order, $_ ] } values %{ $self->{'triggers'} };

    if (@triggers) {
        return wantarray ? @triggers : \@triggers;
    }
    else {
        $self->error('No triggers');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub get_view {

=pod

=head2 get_view

Returns a view by the name provided.

  my $view = $schema->get_view('foo');

=cut

    my $self = shift;
    my $view_name = shift or return $self->error('No view name');
    return $self->error('View "$view_name" does not exist')
      unless exists $self->{'views'}{$view_name};
    return $self->{'views'}{$view_name};
}

# ----------------------------------------------------------------------
sub get_views {

=pod

=head2 get_views

Returns all the views as an array or array reference.

  my @views = $schema->get_views;

=cut

    my $self  = shift;
    my @views =
      map  { $_->[1] }
      sort { $a->[0] <=> $b->[0] }
      map  { [ $_->order, $_ ] } values %{ $self->{'views'} };

    if (@views) {
        return wantarray ? @views : \@views;
    }
    else {
        $self->error('No views');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub make_natural_joins {

=pod

=head2 make_natural_joins

Creates foriegn key relationships among like-named fields in different
tables.  Accepts the following arguments:

=over 4

=item * join_pk_only

A True or False argument which determins whether or not to perform 
the joins from primary keys to fields of the same name in other tables

=item * skip_fields

A list of fields to skip in the joins

=back

  $schema->make_natural_joins(
      join_pk_only => 1,
      skip_fields  => 'name,department_id',
  );

=cut

    my $self         = shift;
    my %args         = @_;
    my $join_pk_only = $args{'join_pk_only'} || 0;
    my %skip_fields  =
      map { s/^\s+|\s+$//g; $_, 1 } @{ parse_list_arg( $args{'skip_fields'} ) };

    my ( %common_keys, %pk );
    for my $table ( $self->get_tables ) {
        for my $field ( $table->get_fields ) {
            my $field_name = $field->name or next;
            next if $skip_fields{$field_name};
            $pk{$field_name} = 1 if $field->is_primary_key;
            push @{ $common_keys{$field_name} }, $table->name;
        }
    }

    for my $field ( keys %common_keys ) {
        next if $join_pk_only and !defined $pk{$field};

        my @table_names = @{ $common_keys{$field} };
        next unless scalar @table_names > 1;

        for my $i ( 0 .. $#table_names ) {
            my $table1 = $self->get_table( $table_names[$i] ) or next;

            for my $j ( 1 .. $#table_names ) {
                my $table2 = $self->get_table( $table_names[$j] ) or next;
                next if $table1->name eq $table2->name;

                $table1->add_constraint(
                    type             => FOREIGN_KEY,
                    fields           => $field,
                    reference_table  => $table2->name,
                    reference_fields => $field,
                );
            }
        }
    }

    return 1;
}

# ----------------------------------------------------------------------
sub name {

=pod

=head2 name

Get or set the schema's name.  (optional)

  my $schema_name = $schema->name('Foo Database');

=cut

    my $self = shift;
    $self->{'name'} = shift if @_;
    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub translator {

=pod

=head2 translator

Get the SQL::Translator instance that instantiated the parser.

=cut

    my $self = shift;
    $self->{'translator'} = shift if @_;
    return $self->{'translator'};
}

# ----------------------------------------------------------------------
sub DESTROY {
    my $self = shift;
    undef $_ for values %{ $self->{'tables'} };
    undef $_ for values %{ $self->{'views'} };
}

1;

# ----------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut

