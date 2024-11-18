package SQL::Translator::Filter::Globals;

=head1 NAME

SQL::Translator::Filter::Globals - Add global fields and indices to all tables.

=head1 SYNOPSIS

  # e.g. Add timestamp field to all tables.
  use SQL::Translator;

  my $sqlt = SQL::Translator->new(
      from => 'MySQL',
      to   => 'MySQL',
      filters => [
        Globals => {
            fields => [
                {
                    name => 'modified'
                    data_type => 'TIMESTAMP'
                }
            ],
            indices => [
                {
                    fields => 'modifed',
                },
            ]
            constraints => [
                {
                }
            ]
        },
      ],
  ) || die "SQLFairy error : ".SQL::Translator->error;
  my $sql = $sqlt->translate || die "SQLFairy error : ".$sqlt->error;

=cut

use strict;
use warnings;
our $VERSION = '1.66';

sub filter {
  my $schema       = shift;
  my %args         = @_;
  my $global_table = $args{global_table} ||= '_GLOBAL_';

  my (@global_fields, @global_indices, @global_constraints);
  push @global_fields,      @{ $args{fields} }      if $args{fields};
  push @global_indices,     @{ $args{indices} }     if $args{indices};
  push @global_constraints, @{ $args{constraints} } if $args{constraints};

  # Pull fields and indices off global table and then remove it.
  if (my $gtbl = $schema->get_table($global_table)) {

    foreach ($gtbl->get_fields) {

      # We don't copy the order attrib so the added fields should get
      # pushed on the end of each table.
      push @global_fields,
          {
            name                  => $_->name,
            comments              => "" . $_->comments,
            data_type             => $_->data_type,
            default_value         => $_->default_value,
            size                  => [ $_->size ],
            extra                 => scalar($_->extra),
            foreign_key_reference => $_->foreign_key_reference,
            is_auto_increment     => $_->is_auto_increment,
            is_foreign_key        => $_->is_foreign_key,
            is_nullable           => $_->is_nullable,
            is_primary_key        => $_->is_primary_key,
            is_unique             => $_->is_unique,
            is_valid              => $_->is_valid,
          };
    }

    foreach ($gtbl->get_indices) {
      push @global_indices,
          {
            name    => $_->name,
            type    => $_->type,
            fields  => [ $_->fields ],
            options => [ $_->options ],
            extra   => scalar($_->extra),
          };
    }

    foreach ($gtbl->get_constraints) {
      push @global_constraints,
          {
            name             => $_->name,
            fields           => [ $_->fields ],
            deferrable       => $_->deferrable,
            expression       => $_->expression,
            match_type       => $_->match_type,
            options          => [ $_->options ],
            on_delete        => $_->on_delete,
            on_update        => $_->on_update,
            reference_fields => [ $_->reference_fields ],
            reference_table  => $_->reference_table,
            table            => $_->table,
            type             => $_->type,
            extra            => scalar($_->extra),
          };
    }

    $schema->drop_table($gtbl);
  }

  # Add globals to tables
  foreach my $tbl ($schema->get_tables) {

    foreach my $new_fld (@global_fields) {

      # Don't add if field already there
      next if $tbl->get_field($new_fld->{name});
      $tbl->add_field(%$new_fld);
    }

    foreach my $new_index (@global_indices) {
      $tbl->add_index(%$new_index);
    }

    foreach my $new_constraint (@global_constraints) {
      $tbl->add_constraint(%$new_constraint);
    }
  }
}

1;

__END__

=head1 DESCRIPTION

Adds global fields, indices and constraints to all tables in the schema.
The globals to add can either be defined in the filter args or using a _GLOBAL_
table (see below).

If a table already contains a field with the same name as a global then it is
skipped for that table.

=head2 The _GLOBAL_ Table

An alternative to using the args is to add a table called C<_GLOBAL_> to the
schema and then just use the filter. Any fields and indices defined on this table
will be added to all the tables in the schema and the _GLOBAL_ table removed.

The name of the global can be changed using a C<global_table> arg to the
filter.

=head1 SEE ALSO

C<perl(1)>, L<SQL::Translator>

=head1 BUGS

Will generate duplicate indices if an index already exists on a table the same
as one added globally.

Will generate duplicate constraints if a constraint already exists on a table
the same as one added globally.

=head1 TODO

Some extra data values that can be used to control the global addition. e.g.
'skip_global'.

=head1 AUTHOR

Mark Addison <grommit@users.sourceforge.net>

=cut
