package SQL::Translator::Producer::JSON;

=head1 NAME

SQL::Translator::Producer::JSON - A JSON producer for SQL::Translator

=head1 SYNOPSIS

  use SQL::Translator;

  my $translator = SQL::Translator->new(producer => 'JSON');

=head1 DESCRIPTION

This module serializes a schema to a JSON string.

=cut

use strict;
use warnings;
our $VERSION = '1.66';

use JSON::MaybeXS 'to_json';

sub produce {
  my $translator = shift;
  my $schema     = $translator->schema;

  return to_json(
    {
      schema => {
        tables     => { map { ($_->name => view_table($_)) } $schema->get_tables, },
        views      => { map { ($_->name => view_view($_)) } $schema->get_views, },
        triggers   => { map { ($_->name => view_trigger($_)) } $schema->get_triggers, },
        procedures => { map { ($_->name => view_procedure($_)) } $schema->get_procedures, },
      },
      translator => {
        add_drop_table => $translator->add_drop_table,
        filename       => $translator->filename,
        no_comments    => $translator->no_comments,
        parser_args    => $translator->parser_args,
        producer_args  => $translator->producer_args,
        parser_type    => $translator->parser_type,
        producer_type  => $translator->producer_type,
        show_warnings  => $translator->show_warnings,
        trace          => $translator->trace,
        version        => $translator->version,
      },
      keys %{ $schema->extra } ? ('extra' => { $schema->extra }) : (),
    },
    {
      allow_blessed => 1,
      allow_unknown => 1,
      (
        map  { $_ => $translator->producer_args->{$_} }
        grep { defined $translator->producer_args->{$_} } qw[ pretty indent canonical ]
      ),
    }
  );
}

sub view_table {
  my $table = shift;

  return {
    'name'    => $table->name,
    'order'   => $table->order,
    'options' => $table->options || [],
    $table->comments ? ('comments' => [ $table->comments ]) : (),
    'constraints' => [
      map { view_constraint($_) } $table->get_constraints
    ],
    'indices' => [
      map { view_index($_) } $table->get_indices
    ],
    'fields' => {
      map { ($_->name => view_field($_)) }
          $table->get_fields
    },
    keys %{ $table->extra } ? ('extra' => { $table->extra }) : (),
  };
}

sub view_constraint {
  my $constraint = shift;

  return {
    'deferrable'       => scalar $constraint->deferrable,
    'expression'       => scalar $constraint->expression,
    'fields'           => [ map { ref $_ ? $_->name : $_ } $constraint->field_names ],
    'match_type'       => scalar $constraint->match_type,
    'name'             => scalar $constraint->name,
    'options'          => scalar $constraint->options,
    'on_delete'        => scalar $constraint->on_delete,
    'on_update'        => scalar $constraint->on_update,
    'reference_fields' => [ map { ref $_ ? $_->name : $_ } $constraint->reference_fields ],
    'reference_table'  => scalar $constraint->reference_table,
    'type'             => scalar $constraint->type,
    keys %{ $constraint->extra }
    ? ('extra' => { $constraint->extra })
    : (),
  };
}

sub view_field {
  my $field = shift;

  return {
    'order'          => scalar $field->order,
    'name'           => scalar $field->name,
    'data_type'      => scalar $field->data_type,
    'size'           => [ $field->size ],
    'default_value'  => scalar $field->default_value,
    'is_nullable'    => scalar $field->is_nullable,
    'is_primary_key' => scalar $field->is_primary_key,
    'is_unique'      => scalar $field->is_unique,
    $field->is_auto_increment ? ('is_auto_increment' => 1)                    : (),
    $field->comments          ? ('comments'          => [ $field->comments ]) : (),
    keys %{ $field->extra }   ? ('extra'             => { $field->extra })    : (),
  };
}

sub view_procedure {
  my $procedure = shift;

  return {
    'order'      => scalar $procedure->order,
    'name'       => scalar $procedure->name,
    'sql'        => scalar $procedure->sql,
    'parameters' => scalar $procedure->parameters,
    'owner'      => scalar $procedure->owner,
    $procedure->comments        ? ('comments' => [ $procedure->comments ]) : (),
    keys %{ $procedure->extra } ? ('extra'    => { $procedure->extra })    : (),
  };
}

sub view_trigger {
  my $trigger = shift;

  return {
    'order'               => scalar $trigger->order,
    'name'                => scalar $trigger->name,
    'perform_action_when' => scalar $trigger->perform_action_when,
    'database_events'     => scalar $trigger->database_events,
    'fields'              => scalar $trigger->fields,
    'on_table'            => scalar $trigger->on_table,
    'action'              => scalar $trigger->action,
    (
      defined $trigger->scope
      ? ('scope' => scalar $trigger->scope,)
      : ()
    ),
    keys %{ $trigger->extra } ? ('extra' => { $trigger->extra }) : (),
  };
}

sub view_view {
  my $view = shift;

  return {
    'order'  => scalar $view->order,
    'name'   => scalar $view->name,
    'sql'    => scalar $view->sql,
    'fields' => scalar $view->fields,
    keys %{ $view->extra } ? ('extra' => { $view->extra }) : (),
  };
}

sub view_index {
  my $index = shift;

  return {
    'name'   => scalar $index->name,
    'type'   => scalar $index->type,
    'fields' => [
      map { ref($_) && $_->extra && keys %{ $_->extra } ? { name => $_->name, %{ $_->extra } } : "$_" }
          $index->fields
    ],
    'options' => scalar $index->options,
    keys %{ $index->extra } ? ('extra' => { $index->extra }) : (),
  };
}

1;

=head1 SEE ALSO

SQL::Translator, JSON::MaybeXS, http://www.json.org/.

=head1 AUTHORS

darren chamberlain E<lt>darren@cpan.orgE<gt>,
Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.
Jon Jensen E<lt>jonj@cpan.orgE<gt>.

=cut
