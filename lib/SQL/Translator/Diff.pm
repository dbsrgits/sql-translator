package SQL::Translator::Diff;
## SQLT schema diffing code
use strict;
use warnings;
use Data::Dumper;
use SQL::Translator::Schema::Constants;

sub schema_diff
  {
    #  use Data::Dumper;
    ## we are getting instructions on how to turn the source into the target
    ## source == original, target == new (hmm, if I need to comment this, should I rename the vars again ??)
    ## _schema isa SQL::Translator::Schema
    ## _db is the name of the producer/db it came out of/into
    ## results are formatted to the source preferences

    my ($source_schema, $source_db, $target_schema, $target_db, $options) = @_;
    #     print Data::Dumper::Dumper($target_schema);

    my $producer_class = "SQL::Translator::Producer::$source_db";
    eval "require $producer_class";

    my $case_insensitive = $options->{caseopt} || 0;
    my $debug = $options->{debug} || 0;
    my $trace = $options->{trace} || 0;
    my $ignore_index_names = $options->{ignore_index_names} || 0;
    my $ignore_constraint_names = $options->{ignore_constraint_names} || 0;
    my $ignore_view_sql = $options->{ignore_view_sql} || 0;
    my $ignore_proc_sql = $options->{ignore_proc_sql} || 0;
    my $output_db = $options->{output_db} || $source_db;

    my $tar_name  = $target_schema->name;
    my $src_name  = $source_schema->name;

    my ( @diffs_new_tables, @diffs_at_end, @new_tables, @diffs_index_drops, @diffs_constraint_drops, @diffs_table_drops, @diffs_table_adds, @diffs_index_creates, @diffs_constraint_creates, @diffs_table_options );
    ## do original/source tables exist in target?
    for my $tar_table ( $target_schema->get_tables ) {
      my $tar_table_name = $tar_table->name;
      my $src_table      = $source_schema->get_table( $tar_table_name, $case_insensitive );

      warn "TABLE '$tar_name.$tar_table_name'\n" if $debug;
      unless ( $src_table ) {
        warn "Couldn't find table '$tar_name.$tar_table_name' in '$src_name'\n"
          if $debug;
        ## table is new
        ## add table(s) later. 
          my $cr_table = $producer_class->can('create_table') || die "$producer_class does not support create_table";
        my $new_table_sql = $cr_table->($tar_table,  { leave_name => 1 });
        push (@diffs_new_tables, $new_table_sql);
        push (@new_tables, $tar_table);
        next;
      }

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
      if ( $options_different ) {
        my $al_table = $producer_class->can('alter_table') || die "$producer_class does not support alter_table";
        my $alter_sql = $al_table->( $tar_table ) . ';';
        @diffs_table_options = ("$alter_sql");
      }

      my $src_table_name = $src_table->name;
      ## Compare fields, their types, defaults, sizes etc etc
      for my $tar_table_field ( $tar_table->get_fields ) {
        my $f_tar_type      = $tar_table_field->data_type;
        my $f_tar_size      = $tar_table_field->size;
        my $f_tar_name      = $tar_table_field->name;
        my $f_tar_nullable  = $tar_table_field->is_nullable;
        my $f_tar_default   = $tar_table_field->default_value;
        my $f_tar_auto_inc  = $tar_table_field->is_auto_increment;
        my $src_table_field     = $src_table->get_field( $f_tar_name, $case_insensitive );
        my $f_tar_full_name = "$tar_name.$tar_table_name.$f_tar_name";
        warn "FIELD '$f_tar_full_name'\n" if $debug;

        my $f_src_full_name = "$src_name.$src_table_name.$f_tar_name";

        unless ( $src_table_field ) {
          warn "Couldn't find field '$f_src_full_name' in '$src_table_name'\n" 
            if $debug;

          my $add_field = $producer_class->can('add_field') || die "$producer_class does not support add_field";
          my $alter_add_sql = $add_field->( $tar_table_field ) . ';';
          push (@diffs_table_adds, $alter_add_sql);
          next;
        }

        ## field exists, so what changed? 
        ## (do we care? just call equals to see IF)
        if ( !$tar_table_field->equals($src_table_field, $case_insensitive) ) {
          ## throw all this junk away and call producer->alter_field
          ## check output same, etc etc

          my $al_field = $producer_class->can('alter_field') || die "$producer_class does not support alter_field";
          my $alter_field_sql = $al_field->( $src_table_field, $tar_table_field ) . ';';
          push (@diffs_table_adds, $alter_field_sql);
          next;
        }
      }

      for my $src_table_field ( $src_table->get_fields ) {
        my $f_src_name      = $src_table_field->name;
        my $tar_table_field     = $tar_table->get_field( $f_src_name, $case_insensitive );
        my $f_src_full_name = "$tar_name.$tar_table_name.$f_src_name";

        unless ( $tar_table_field ) {
          warn "Couldn't find field '$f_src_full_name' in '$src_table_name'\n" 
            if $debug;

          my $dr_field = $producer_class->can('drop_field') || die "$producer_class does not support drop_field";
          my $alter_drop_sql = $dr_field->( $src_table_field ) . ';';
          push (@diffs_table_drops, $alter_drop_sql);
          next;
        }
      }

      my (%checked_indices);
    INDEX_CREATE:
      for my $i_tar ( $tar_table->get_indices ) {
        for my $i_src ( $src_table->get_indices ) {
          if ( $i_tar->equals($i_src, $case_insensitive, $ignore_index_names) ) {
            $checked_indices{$i_src} = 1;
            next INDEX_CREATE;
          }
        }
        my $al_cr_index = $producer_class->can('alter_create_index') || die "$producer_class does not support alter_create_index";
        my $create_index_sql = $al_cr_index->( $i_tar ) . ';';
        push ( @diffs_index_creates, $create_index_sql );
      }
    INDEX_DROP:
      for my $i_src ( $src_table->get_indices ) {
        next if !$ignore_index_names && $checked_indices{$i_src};
        for my $i_tar ( $tar_table->get_indices ) {
          next INDEX_DROP if $i_src->equals($i_tar, $case_insensitive, $ignore_index_names);
        }
        my $al_dr_index = $producer_class->can('alter_drop_index') || die "$producer_class does not support alter_drop_index";
        my $drop_index_sql = $al_dr_index->( $i_src ) . ';';
        push ( @diffs_index_drops, $drop_index_sql );
      }

      my(%checked_constraints);
      CONSTRAINT_CREATE:
        for my $c_tar ( $tar_table->get_constraints ) {
          for my $c_src ( $src_table->get_constraints ) {
                        if ( $c_tar->equals($c_src, $case_insensitive, $ignore_constraint_names) ) {
              $checked_constraints{$c_src} = 1;
              next CONSTRAINT_CREATE;
                        }
          }
          my $al_cr_const = $producer_class->can('alter_create_constraint') || die "$producer_class does not support alter_create_constraint";
          my $create_constraint_sql = $al_cr_const->( $c_tar, { leave_name => 1 }) . ';';
          push ( @diffs_constraint_creates, $create_constraint_sql );
        }

     CONSTRAINT_DROP:
        for my $c_src ( $src_table->get_constraints ) {
          next if !$ignore_constraint_names && $checked_constraints{$c_src};
          for my $c_tar ( $tar_table->get_constraints ) {
                        next CONSTRAINT_DROP if $c_src->equals($c_tar, $case_insensitive, $ignore_constraint_names);
          }

          my $al_dr_const = $producer_class->can('alter_drop_constraint') || die "$producer_class does not support alter_drop_constraint";
          my $drop_constraint_sql = $al_dr_const->( $c_src ) . ';';
          push ( @diffs_constraint_drops, $drop_constraint_sql );
        }
    }

    my @diffs_dropped_tables;
    for my $src_table ( $source_schema->get_tables ) {
      my $src_table_name = $src_table->name;
      my $tar_table      = $target_schema->get_table( $src_table_name, $case_insensitive );

      unless ( $tar_table ) {
        for my $c_src ( $src_table->get_constraints ) {
           my $al_dr_const = $producer_class->can('alter_drop_constraint') || die "$producer_class does not support alter_drop_constraint";
           my $drop_constraint_sql = $al_dr_const->( $c_src ) . ';';
           push ( @diffs_constraint_drops, $drop_constraint_sql );
        }

        push @diffs_dropped_tables, "DROP TABLE $src_table_name;";
        next;
      }
    }

    my @diffs;
    push ( @diffs, @diffs_constraint_drops, @diffs_index_drops, @diffs_table_drops, @diffs_table_adds, @diffs_index_creates, @diffs_constraint_creates, @diffs_table_options );
    unshift (@diffs, "SET foreign_key_checks=0;\n\n", @diffs_new_tables, "SET foreign_key_checks=1;\n\n" );
    push (@diffs, @diffs_dropped_tables);

    if(@diffs_constraint_drops+@diffs_index_drops+@diffs_table_drops+@diffs_table_adds+@diffs_index_creates+@diffs_constraint_creates+@diffs_table_options+@diffs_new_tables+@diffs_dropped_tables == 0 )
    {
        @diffs = ('No differences found');
    }

    if ( @diffs ) {
#      if ( $target_db !~ /^(MySQL|SQLServer|Oracle)$/ ) {
      if ( $target_db !~ /^(MySQL)$/ ) {
        unshift(@diffs, "-- Target database $target_db is untested/unsupported!!!");
      }
      return join( "\n", 
                   "-- Convert schema '$src_name' to '$tar_name':\n", @diffs, "\n"
                 );
    }
    return undef;
  }

1;
