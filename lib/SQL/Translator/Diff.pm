package SQL::Translator::Diff;


## SQLT schema diffing code
use strict;
use warnings;

use Data::Dumper;
use SQL::Translator::Schema::Constants;

use base 'Class::Accessor::Fast';

# Input/option accessors
__PACKAGE__->mk_accessors(qw/
  ignore_index_names ignore_constraint_names ignore_view_sql
  ignore_proc_sql output_db source_schema source_db target_schema target_db
  case_insensitive no_batch_alters ignore_missing_methods
/);

my @diff_arrays = qw/
  tables_to_drop
  tables_to_create
/;

my @diff_hash_keys = qw/
  constraints_to_create
  constraints_to_drop
  indexes_to_create
  indexes_to_drop
  fields_to_create
  fields_to_alter
  fields_to_rename
  fields_to_drop
  table_options
/;

__PACKAGE__->mk_accessors(@diff_arrays, 'table_diff_hash');

sub schema_diff {
    #  use Data::Dumper;
    ## we are getting instructions on how to turn the source into the target
    ## source == original, target == new (hmm, if I need to comment this, should I rename the vars again ??)
    ## _schema isa SQL::Translator::Schema
    ## _db is the name of the producer/db it came out of/into
    ## results are formatted to the source preferences

    my ($source_schema, $source_db, $target_schema, $target_db, $options) = @_;
    $options ||= {};

    my $obj = SQL::Translator::Diff->new( {
      %$options,
      source_schema => $source_schema,
      source_db     => $source_db,
      target_schema => $target_schema,
      target_db     => $target_db
    } );

    $obj->compute_differences->produce_diff_sql;
}

sub new {
  my ($class, $values) = @_;
  $values->{$_} ||= [] foreach @diff_arrays;
  $values->{table_diff_hash} = {};

  $values->{output_db} ||= $values->{source_db};
  return $class->SUPER::new($values);
}

sub compute_differences {
    my ($self) = @_;

    my $target_schema = $self->target_schema;
    my $source_schema = $self->source_schema;

    my @tar_tables = sort { $a->name cmp $b->name } $target_schema->get_tables;
    ## do original/source tables exist in target?
    for my $tar_table ( @tar_tables ) {
      my $tar_table_name = $tar_table->name;
      my $src_table      = $source_schema->get_table( $tar_table_name, $self->case_insensitive );

      unless ( $src_table ) {
        ## table is new
        ## add table(s) later. 
        push @{$self->tables_to_create}, $tar_table;
        next;
      }

      $self->table_diff_hash->{$tar_table_name} = {
        map {$_ => [] } @diff_hash_keys
      };

      $self->diff_table_options($src_table, $tar_table);

      ## Compare fields, their types, defaults, sizes etc etc
      $self->diff_table_fields($src_table, $tar_table);

      $self->diff_table_indexes($src_table, $tar_table);
      $self->diff_table_constraints($src_table, $tar_table);

    } # end of target_schema->get_tables loop

    for my $src_table ( $source_schema->get_tables ) {
      my $src_table_name = $src_table->name;
      my $tar_table      = $target_schema->get_table( $src_table_name, $self->case_insensitive );

      unless ( $tar_table ) {
        $self->table_diff_hash->{$src_table_name} = {
          map {$_ => [] } @diff_hash_keys
        };

        push @{ $self->tables_to_drop}, $src_table;
        next;
      }
    }

    return $self;
}

sub produce_diff_sql {
    my ($self) = @_;

    my $target_schema = $self->target_schema;
    my $source_schema = $self->source_schema;
    my $tar_name  = $target_schema->name;
    my $src_name  = $source_schema->name;

    my $producer_class = "SQL::Translator::Producer::@{[$self->output_db]}";
    eval "require $producer_class";
    die $@ if $@;

    # Map of name we store under => producer method name
    my %func_map = (
      constraints_to_create => 'alter_create_constraint',
      constraints_to_drop   => 'alter_drop_constraint',
      indexes_to_create     => 'alter_create_index',
      indexes_to_drop       => 'alter_drop_index',
      fields_to_create      => 'add_field',
      fields_to_alter       => 'alter_field',
      fields_to_rename      => 'rename_field',
      fields_to_drop        => 'drop_field',
      table_options         => 'alter_table'
    );
    my @diffs;
  
    if (!$self->no_batch_alters && 
        (my $batch_alter = $producer_class->can('batch_alter_table')) ) 
    {
      # Good - Producer supports batch altering of tables.
      foreach my $table ( sort keys %{$self->table_diff_hash} ) {
        my $tar_table = $target_schema->get_table($table)
                     || $source_schema->get_table($table);

  $DB::single = 1 if $table eq 'deleted'; 
        push @diffs, $batch_alter->($tar_table,
          { map {
              $func_map{$_} => $self->table_diff_hash->{$table}{$_}
            } keys %func_map 
          }
        );
      }
    } else {

      my %flattened_diffs;
      foreach my $table ( sort keys %{$self->table_diff_hash} ) {
        my $table_diff = $self->table_diff_hash->{$table};
        for (@diff_hash_keys) {
          push( @{ $flattened_diffs{ $func_map{$_} } ||= [] }, @{ $table_diff->{$_} } );
        }
      }

      push @diffs, map( {
          if (@{$flattened_diffs{$_}}) {
            my $meth = $producer_class->can($_);
            
            $meth ? map { my $sql = $meth->(ref $_ eq 'ARRAY' ? @$_ : $_); $sql ?  ("$sql;") : () } @{ $flattened_diffs{$_} }
                  : $self->ignore_missing_methods
                  ? "-- $producer_class cant $_"
                  : die "$producer_class cant $_";
          } else { () }

        } qw/alter_drop_constraint
             alter_drop_index
             drop_field
             add_field
             alter_field
             rename_field
             alter_create_index
             alter_create_constraint
             alter_table/),
    }

    if (my @tables = @{ $self->tables_to_create } ) {
      my $translator = new SQL::Translator(
        producer_type => $self->output_db,
        add_drop_table => 0,
        no_comments => 1,
        # TODO: sort out options
        quote_table_names => 0,
        quote_field_names => 0,
      );
      my $schema = $translator->schema;

      $schema->add_table($_) for @tables;

      unshift @diffs, 
        # Remove begin/commit here, since we wrap everything in one.
        grep { $_ !~ /^(?:COMMIT|BEGIN(?: TRANSACTION)?);/ } $producer_class->can('produce')->($translator);
    }

    if (my @tables_to_drop = @{ $self->{tables_to_drop} || []} ) {
      my $meth = $producer_class->can('drop_table');
      
      push @diffs, $meth ? map( { $meth->($_) } @tables_to_drop )
                         : $self->ignore_missing_methods
                         ? "-- $producer_class cant drop_table"
                         : die "$producer_class cant drop_table";
    }

    if (@diffs) {
      unshift @diffs, "BEGIN TRANSACTION;\n";
      push    @diffs, "\nCOMMIT;\n";
    } else {
      @diffs = ("-- No differences found\n\n");
    }

    if ( @diffs ) {
      if ( $self->target_db !~ /^(?:MySQL|SQLite)$/ ) {
        unshift(@diffs, "-- Target database @{[$self->target_db]} is untested/unsupported!!!");
      }
      return join( "\n", "-- Convert schema '$src_name' to '$tar_name':\n", @diffs);
    }
    return undef;

}

sub diff_table_indexes {
  my ($self, $src_table, $tar_table) = @_;

  my (%checked_indices);
  INDEX_CREATE:
  for my $i_tar ( $tar_table->get_indices ) {
    for my $i_src ( $src_table->get_indices ) {
      if ( $i_tar->equals($i_src, $self->case_insensitive, $self->ignore_index_names) ) {
        $checked_indices{$i_src} = 1;
        next INDEX_CREATE;
      }
    }
    push @{$self->table_diff_hash->{$tar_table}{indexes_to_create}}, $i_tar;
  }

  INDEX_DROP:
  for my $i_src ( $src_table->get_indices ) {
    next if !$self->ignore_index_names && $checked_indices{$i_src};
    for my $i_tar ( $tar_table->get_indices ) {
      next INDEX_DROP if $i_src->equals($i_tar, $self->case_insensitive, $self->ignore_index_names);
    }
    push @{$self->table_diff_hash->{$tar_table}{indexes_to_drop}}, $i_src;
  }
}


sub diff_table_constraints {
  my ($self, $src_table, $tar_table) = @_;

  my(%checked_constraints);
  CONSTRAINT_CREATE:
  for my $c_tar ( $tar_table->get_constraints ) {
    for my $c_src ( $src_table->get_constraints ) {
      if ( $c_tar->equals($c_src, $self->case_insensitive, $self->ignore_constraint_names) ) {
        $checked_constraints{$c_src} = 1;
        next CONSTRAINT_CREATE;
      }
    }
    push @{ $self->table_diff_hash->{$tar_table}{constraints_to_create} }, $c_tar;
  }


  CONSTRAINT_DROP:
  for my $c_src ( $src_table->get_constraints ) {
    next if !$self->ignore_constraint_names && $checked_constraints{$c_src};
    for my $c_tar ( $tar_table->get_constraints ) {
      next CONSTRAINT_DROP if $c_src->equals($c_tar, $self->case_insensitive, $self->ignore_constraint_names);
    }

    push @{ $self->table_diff_hash->{$tar_table}{constraints_to_drop} }, $c_src;
  }

}

sub diff_table_fields {
  my ($self, $src_table, $tar_table) = @_;

  # List of ones ew've renamed from so we dont drop them
  my %renamed_source_fields;

  for my $tar_table_field ( $tar_table->get_fields ) {
    my $f_tar_name      = $tar_table_field->name;

    if (my $old_name = $tar_table_field->extra->{renamed_from}) {
      my $src_table_field = $src_table->get_field( $old_name, $self->case_insensitive );
      die qq#Renamed cant find "@{[$src_table->name]}.$old_name" for renamed column\n# unless $src_table_field;
      push @{$self->table_diff_hash->{$tar_table}{fields_to_rename} }, [ $src_table_field, $tar_table_field ];
      $renamed_source_fields{$old_name} = 1;
      next;
    }

    my $src_table_field = $src_table->get_field( $f_tar_name, $self->case_insensitive );

    unless ( $src_table_field ) {
      push @{$self->table_diff_hash->{$tar_table}{fields_to_create}}, $tar_table_field;
      next;
    }

    ## field exists, something changed.
    if ( !$tar_table_field->equals($src_table_field, $self->case_insensitive) ) {

      # Some producers might need src field to diff against
      push @{$self->table_diff_hash->{$tar_table}{fields_to_alter}}, [ $src_table_field, $tar_table_field ];
      next;
    }
  }


  # Now check to see if any fields from src_table need to be dropped
  for my $src_table_field ( $src_table->get_fields ) {
    my $f_src_name      = $src_table_field->name;
    next if $renamed_source_fields{$f_src_name};

    my $tar_table_field = $tar_table->get_field( $f_src_name, $self->case_insensitive );

    unless ( $tar_table_field ) {
      push @{$self->table_diff_hash->{$tar_table}{fields_to_drop}}, $src_table_field;
      next;
    }
  }
}

sub diff_table_options {
  my ($self, $src_table, $tar_table) = @_;


  # Go through our options
  my $options_different = 0;
  my %checkedOptions;

  OPTION:
  for my $tar_table_option_ref ( $tar_table->options ) {
    my($key_tar, $value_tar) = %{$tar_table_option_ref};
    for my $src_table_option_ref ( $src_table->options ) {
      my($key_src, $value_src) = %{$src_table_option_ref};
      if ( $key_tar eq $key_src ) {
        if ( defined $value_tar != defined $value_src ) {
          $options_different = 1;
          last OPTION;
        }
        if ( defined $value_tar && $value_tar ne $value_src ) {
          $options_different = 1;
          last OPTION;
        }
        $checkedOptions{$key_tar} = 1;
        next OPTION;
      }
    }
    $options_different = 1;
    last OPTION;
  }

  # Go through the other table's options
  unless ( $options_different ) {
    for my $src_table_option_ref ( $src_table->options ) {
      my($key, $value) = %{$src_table_option_ref};
      next if $checkedOptions{$key};
      $options_different = 1;
      last;
    }
  }

  # If there's a difference, just re-set all the options
  push @{ $self->table_diff_hash->{$tar_table}{table_options} }, $tar_table
    if ( $options_different );
}

1;

__END__

=head1 NAME

SQL::Translator::Diff

=head1 DESCRIPTION

Takes two input SQL::Translator::Schemas (or SQL files) and produces ALTER 
statments to make them the same

=head1 SNYOPSIS

Simplest usage:

 use SQL::Translator::Diff;
 my $sql = SQL::Translator::Diff::schema_diff($source_schema, 'MySQL', $target_schema, 'MySQL', $options_hash)

OO usage:

 use SQL::Translator::Diff;
 my $diff = SQL::Translator::Diff->new({
   output_db     => 'MySQL',
   source_schema => $source_schema,
   target_schema => $target_schema,
   %$options_hash,
 })->compute_differences->produce_diff_sql;

=head1 OPTIONS

=over

=item B<ignore_index_names>

Match indexes based on types and fields, ignoring name.

=item B<ignore_constraint_names>

Match constrains based on types, fields and tables, ignoring name.

=item B<output_db>

Which producer to use to produce the output.

=item B<case_insensitive>

Ignore case of table, field, index and constraint names when comparing

=item B<no_batch_alters>

Produce each alter as a distinct C<ALTER TABLE> statement even if the producer
supports the ability to do all alters for a table as one statement.

=item B<ignore_missing_methods>

If the diff would need a method that is missing from the producer, just emit a
comment showing the method is missing, rather than dieing with an error

=back

=head1 PRODUCER FUNCTIONS

The following producer functions should be implemented for completeness. If
any of them are needed for a given diff, but not found, an error will be 
thrown.

=over

=item * C<alter_create_constraint($con)>

=item * C<alter_drop_constraint($con)>

=item * C<alter_create_index($idx)>

=item * C<alter_drop_index($idx)>

=item * C<add_field($fld)>

=item * C<alter_field($old_fld, $new_fld)>

=item * C<rename_field($old_fld, $new_fld)>

=item * C<drop_field($fld)>

=item * C<alter_table($table)>

=item * C<drop_table($table)>

=item * C<batch_alter_table($table, $hash)> (optional)

=back

If the producer supports C<batch_alter_table>, it will be called with the 
table to alter and a hash, the keys of which will be the method names listed
above; values will be arrays of fields or constraints to operate on. In the 
case of the field functions that take two arguments this will appear as a hash.

I.e. the hash might look something like the following:

 {
   alter_create_constraint => [ $constraint1, $constraint2 ],
   add_field   => [ $field ],
   alter_field => [ [$old_field, $new_field] ]
 }

=head1 AUTHOR

Original Author(s) unknown.

Refactor and more comprehensive tests by Ash Berlin C<< ash@cpan.org >>.

Redevelopment sponsored by Takkle Inc.

=cut
