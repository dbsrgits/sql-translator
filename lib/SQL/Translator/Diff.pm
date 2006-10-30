package SQL::Translator::Diff;
## SQLT schema diffing code
use strict;
use warnings;
use SQL::Translator::Schema::Constants;

sub schema_diff
{
#  use Data::Dumper;
    my ($source_schema, $source_db, $target_schema, $target_db, $options) = @_;
#  print Data::Dumper::Dumper($target_schema);
    my $caseopt = $options->{caseopt} || 0;
    my $debug = $options->{debug} || 0;
    my $trace = $options->{trace} || 0;

    my $case_insensitive = $source_db =~ /SQLServer/ || $caseopt;

    my $tar_name  = $target_schema->name;
    my $src_name  = $source_schema->name;
    my ( @new_tables, @diffs , @diffs_at_end);
    for my $tar_table ( $target_schema->get_tables ) {
        my $tar_table_name = $tar_table->name;
        my $src_table      = $source_schema->get_table( $tar_table_name, $case_insensitive );

        warn "TABLE '$tar_name.$tar_table_name'\n" if $debug;
        unless ( $src_table ) {
            warn "Couldn't find table '$tar_name.$tar_table_name' in '$src_name'\n"
                if $debug;
            if ( $source_db =~ /(SQLServer|Oracle)/ ) {
                for my $constraint ( $tar_table->get_constraints ) {
                    next if $constraint->type ne FOREIGN_KEY;
                    push @diffs_at_end, "ALTER TABLE $tar_table_name ADD ".
                        constraint_to_string($constraint, $source_db, $target_schema).";";
                    $tar_table->drop_constraint($constraint);
                }
            }
            push @new_tables, $tar_table;
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
        my @diffs_table_options;
        if ( $options_different ) {
            my @options = ();
            foreach my $option_ref ( $tar_table->options ) {
                my($key, $value) = %{$option_ref};
                push(@options, defined $value ? "$key=$value" : $key);
            }
            my $options = join(' ', @options);
            @diffs_table_options = ("ALTER TABLE $tar_table_name $options;");
        }

        my $src_table_name = $src_table->name;
        my(@diffs_table_adds, @diffs_table_changes);
        for my $tar_table_field ( $tar_table->get_fields ) {
            my $f_tar_type      = $tar_table_field->data_type;
            my $f_tar_size      = $tar_table_field->size;
            my $f_tar_name      = $tar_table_field->name;
            my $f_tar_nullable  = $tar_table_field->is_nullable;
            my $f_tar_default   = $tar_table_field->default_value;
            my $f_tar_auto_inc  = $tar_table_field->is_auto_increment;
            my $src_table_field     = $src_table->get_field( $f_tar_name, $case_insensitive );
            my $f_tar_full_name = "$tar_name.$tar_table_name.$tar_table_name";
            warn "FIELD '$f_tar_full_name'\n" if $debug;

            my $f_src_full_name = "$src_name.$src_table_name.$f_tar_name";

            unless ( $src_table_field ) {
                warn "Couldn't find field '$f_src_full_name' in '$src_table_name'\n" 
                    if $debug;
                my $temp_default_value = 0;
                if ( $source_db =~ /SQLServer/ && 
                     !$f_tar_nullable             && 
                     !defined $f_tar_default ) {
                    # SQL Server doesn't allow adding non-nullable, non-default columns
                    # so we add it with a default value, then remove the default value
                    $temp_default_value = 1;
                    my(@numeric_types) = qw(decimal numeric float real int bigint smallint tinyint);
                    $f_tar_default = grep($_ eq $f_tar_type, @numeric_types) ? 0 : '';
                }
                push @diffs_table_adds, sprintf
                    ( "ALTER TABLE %s ADD %s%s %s%s%s%s%s%s;",
                      $tar_table_name, $source_db =~ /Oracle/ ? '(' : '',
                      $f_tar_name, $f_tar_type,
                      ($f_tar_size && $f_tar_type !~ /(blob|text)$/) ? "($f_tar_size)" : '',
                      !defined $f_tar_default ? ''
                      : uc $f_tar_default eq 'NULL' ? ' DEFAULT NULL'
                      : uc $f_tar_default eq 'CURRENT_TIMESTAMP' ? ' DEFAULT CURRENT_TIMESTAMP'
                      : " DEFAULT '$f_tar_default'",
                      $f_tar_nullable ? '' : ' NOT NULL',
                      $f_tar_auto_inc ? ' AUTO_INCREMENT' : '',
                      $source_db =~ /Oracle/ ? ')' : '',
                      );
                if ( $temp_default_value ) {
                    undef $f_tar_default;
                    push @diffs_table_adds, sprintf
                        ( <<END
DECLARE \@defname VARCHAR(100), \@cmd VARCHAR(1000)
SET \@defname = 
(SELECT name 
 FROM sysobjects so JOIN sysconstraints sc
  ON so.id = sc.constid 
 WHERE object_name(so.parent_obj) = '%s' 
   AND so.xtype = 'D'
   AND sc.colid = 
    (SELECT colid FROM syscolumns 
     WHERE id = object_id('%s') AND 
         name = '%s'))
SET \@cmd = 'ALTER TABLE %s DROP CONSTRAINT '
+ \@defname
EXEC(\@cmd)
END
                         , $tar_table_name, $tar_table_name, $f_tar_name, $tar_table_name,
                        );
                  }
                next;
              }

            my $f_src_type = $src_table_field->data_type;
            my $f_src_size = $src_table_field->size || '';
            my $f_src_nullable  = $src_table_field->is_nullable;
            my $f_src_default   = $src_table_field->default_value;
            my $f_src_auto_inc  = $src_table_field->is_auto_increment;
            if ( !$tar_table_field->equals($src_table_field, $case_insensitive) ) {
              # SQLServer timestamp fields can't be altered, so we drop and add instead
              if ( $source_db =~ /SQLServer/ && $f_src_type eq "timestamp" ) {
        		push @diffs_table_changes, "ALTER TABLE $tar_table_name DROP COLUMN $f_tar_name;";
	            push @diffs_table_changes, sprintf
                  ( "ALTER TABLE %s ADD %s%s %s%s%s%s%s%s;",
                    $tar_table_name, $source_db =~ /Oracle/ ? '(' : '',
                    $f_tar_name, $f_tar_type,
                    ($f_tar_size && $f_tar_type !~ /(blob|text)$/) ? "($f_tar_size)" : '',
                    !defined $f_tar_default ? ''
                    : uc $f_tar_default eq 'NULL' ? ' DEFAULT NULL'
                    : uc $f_tar_default eq 'CURRENT_TIMESTAMP' ? ' DEFAULT CURRENT_TIMESTAMP'
                    : " DEFAULT '$f_tar_default'",
	                $f_tar_nullable ? '' : ' NOT NULL',
	                $f_tar_auto_inc ? ' AUTO_INCREMENT' : '',
	                $source_db =~ /Oracle/ ? ')' : '',
                  );
	            next;
              }

              my $changeText = $source_db =~ /SQLServer/ ? 'ALTER COLUMN' :
				$source_db =~ /Oracle/ ? 'MODIFY (' : 'CHANGE';
              my $nullText = $f_tar_nullable ? '' : ' NOT NULL';
              $nullText = '' if $source_db =~ /Oracle/ && $f_tar_nullable == $f_src_nullable;
              push @diffs_table_changes, sprintf
                ( "ALTER TABLE %s %s %s%s %s%s%s%s%s%s;",
                  $tar_table_name, $changeText,
                  $f_tar_name, $source_db =~ /MySQL/ ? " $f_tar_name" : '',
                  $f_tar_type, ($f_tar_size && $f_tar_type !~ /(blob|text)$/) ? "($f_tar_size)" : '',
                  $nullText,
                  !defined $f_tar_default || $source_db =~ /SQLServer/ ? ''
                  : uc $f_tar_default eq 'NULL' ? ' DEFAULT NULL'
                  : uc $f_tar_default eq 'CURRENT_TIMESTAMP' ? ' DEFAULT CURRENT_TIMESTAMP'
                  : " DEFAULT '$f_tar_default'",
                  $f_tar_auto_inc ? ' AUTO_INCREMENT' : '',
                  $source_db =~ /Oracle/ ? ')' : '',
                );
              if ( defined $f_tar_default && $source_db =~ /SQLServer/ ) {
            	# Adding a column with a default value for SQL Server means adding a 
            	# constraint and setting existing NULLs to the default value
            	push @diffs_table_changes, sprintf
                  ( "ALTER TABLE %s ADD CONSTRAINT DF_%s_%s %s FOR %s;",
                    $tar_table_name, $tar_table_name, $f_tar_name, uc $f_tar_default eq 'NULL' ? 'DEFAULT NULL'
                    : uc $f_tar_default eq 'CURRENT_TIMESTAMP' ? 'DEFAULT CURRENT_TIMESTAMP'
                	: "DEFAULT '$f_tar_default'", $f_tar_name,
                  );
            	push @diffs_table_changes, sprintf
                  ( "UPDATE %s SET %s = %s WHERE %s IS NULL;",
                    $tar_table_name, $f_tar_name, uc $f_tar_default eq 'NULL' ? 'NULL'
                	: uc $f_tar_default eq 'CURRENT_TIMESTAMP' ? 'CURRENT_TIMESTAMP'
                	: "'$f_tar_default'", $f_tar_name,
                  );
              }
            }
          }

        my(%checked_indices, @diffs_index_creates, @diffs_index_drops);
      INDEX:
        for my $i_tar ( $tar_table->get_indices ) {
          for my $i_src ( $src_table->get_indices ) {
			if ( $i_tar->equals($i_src, $case_insensitive) ) {
              $checked_indices{$i_src} = 1;
              next INDEX;
			}
          }
          push @diffs_index_creates, sprintf
            ( "CREATE %sINDEX%s ON %s (%s);",
              $i_tar->type eq NORMAL ? '' : $i_tar->type." ",
              $i_tar->name ? " ".$i_tar->name : '',
              $tar_table_name,
              join(",", $i_tar->fields),
            );
        }
      INDEX2:
        for my $i_src ( $src_table->get_indices ) {
          next if $checked_indices{$i_src};
          for my $i_tar ( $tar_table->get_indices ) {
			next INDEX2 if $i_src->equals($i_tar, $case_insensitive);
          }
          $source_db =~ /SQLServer/
			? push @diffs_index_drops, "DROP INDEX $tar_table_name.".$i_src->name.";"
              : push @diffs_index_drops, "DROP INDEX ".$i_src->name." on $tar_table_name;";
        }

        my(%checked_constraints, @diffs_constraint_drops);
      CONSTRAINT:
        for my $c_tar ( $tar_table->get_constraints ) {
          next if $target_db =~ /Oracle/ && 
            $c_tar->type eq UNIQUE && $c_tar->name =~ /^SYS_/i;
          for my $c_src ( $src_table->get_constraints ) {
			if ( $c_tar->equals($c_src, $case_insensitive) ) {
              $checked_constraints{$c_src} = 1;
              next CONSTRAINT;
			}
          }
          push @diffs_at_end, "ALTER TABLE $tar_table_name ADD ".
			constraint_to_string($c_tar, $source_db, $target_schema).";";
        }
      CONSTRAINT2:
        for my $c_src ( $src_table->get_constraints ) {
          next if $source_db =~ /Oracle/ && 
            $c_src->type eq UNIQUE && $c_src->name =~ /^SYS_/i;
          next if $checked_constraints{$c_src};
          for my $c_tar ( $tar_table->get_constraints ) {
			next CONSTRAINT2 if $c_src->equals($c_tar, $case_insensitive);
          }
          if ( $c_src->type eq UNIQUE ) {
			push @diffs_constraint_drops, "ALTER TABLE $tar_table_name DROP INDEX ".
              $c_src->name.";";
          } elsif ( $source_db =~ /SQLServer/ ) {
			push @diffs_constraint_drops, "ALTER TABLE $tar_table_name DROP ".$c_src->name.";";
          } else {
			push @diffs_constraint_drops, "ALTER TABLE $tar_table_name DROP ".$c_src->type.
              ($c_src->type eq FOREIGN_KEY ? " ".$c_src->name : '').";";
          }
        }

        push @diffs, @diffs_index_drops, @diffs_constraint_drops,
          @diffs_table_options, @diffs_table_adds,
            @diffs_table_changes, @diffs_index_creates;
      }

    for my $src_table ( $source_schema->get_tables ) {
      my $src_table_name = $src_table->name;
      my $tar_table      = $target_schema->get_table( $src_table_name, $source_db =~ /SQLServer/ );

      unless ( $tar_table ) {
    	if ( $source_db =~ /SQLServer/ ) {
          for my $constraint ( $src_table->get_constraints ) {
            next if $constraint->type eq PRIMARY_KEY;
            push @diffs, "ALTER TABLE $src_table_name DROP ".$constraint->name.";";
          }
    	}
        push @diffs_at_end, "DROP TABLE $src_table_name;";
        next;
      }

      for my $src_table_field ( $src_table->get_fields ) {
        my $f_src_name      = $src_table_field->name;
        my $tar_table_field     = $tar_table->get_field( $f_src_name );
        unless ( $tar_table_field ) {
          my $modifier = $source_db =~ /SQLServer/ ? "COLUMN " : '';
          push @diffs, "ALTER TABLE $src_table_name DROP $modifier$f_src_name;";
        }
      }
    }

    if ( @new_tables ) {
      my $dummytr = SQL::Translator->new;
      $dummytr->schema->add_table( $_ ) for @new_tables;
      my $producer = $dummytr->producer( $source_db );
      unshift @diffs, $producer->( $dummytr );
    }
    push(@diffs, @diffs_at_end);

    if ( @diffs ) {
    	if ( $target_db !~ /^(MySQL|SQLServer|Oracle)$/ ) {
    		unshift(@diffs, "-- Target database $target_db is untested/unsupported!!!");
    	}
        return join( "\n", 
                  "-- Convert schema '$src_name' to '$tar_name':\n", @diffs, "\n"
                );
    }
    return undef;
}

sub constraint_to_string {
  my $c = shift;
  my $source_db = shift;
  my $schema = shift or die "No schema given";
  my @fields = $c->field_names or return '';

  if ( $c->type eq PRIMARY_KEY ) {
    if ( $source_db =~ /Oracle/ ) {
      return (defined $c->name ? 'CONSTRAINT '.$c->name.' ' : '') .
        'PRIMARY KEY (' . join(', ', @fields). ')';
    } else {
      return 'PRIMARY KEY (' . join(', ', @fields). ')';
    }
  }
  elsif ( $c->type eq UNIQUE ) {
    if ( $source_db =~ /Oracle/ ) {
      return (defined $c->name ? 'CONSTRAINT '.$c->name.' ' : '') .
        'UNIQUE (' . join(', ', @fields). ')';
    } else {
      return 'UNIQUE '.
        (defined $c->name ? $c->name.' ' : '').
          '(' . join(', ', @fields). ')';
    }
  }
  elsif ( $c->type eq FOREIGN_KEY ) {
    my $def = join(' ', 
                   map { $_ || () } 'CONSTRAINT', $c->name, 'FOREIGN KEY' 
                  );

    $def .= ' (' . join( ', ', @fields ) . ')';

    $def .= ' REFERENCES ' . $c->reference_table;

    my @rfields = map { $_ || () } $c->reference_fields;
    unless ( @rfields ) {
      my $rtable_name = $c->reference_table;
      if ( my $ref_table = $schema->get_table( $rtable_name ) ) {
        push @rfields, $ref_table->primary_key;
      }
      else {
        warn "Can't find reference table '$rtable_name' " .
          "in schema\n";
      }
    }

    if ( @rfields ) {
      $def .= ' (' . join( ', ', @rfields ) . ')';
    }
    else {
      warn "FK constraint on " . 'some table' . '.' .
        join('', @fields) . " has no reference fields\n";
    }

    if ( $c->match_type ) {
      $def .= ' MATCH ' . 
        ( $c->match_type =~ /full/i ) ? 'FULL' : 'PARTIAL';
    }

    if ( $c->on_delete ) {
      $def .= ' ON DELETE '.join( ' ', $c->on_delete );
    }

    if ( $c->on_update ) {
      $def .= ' ON UPDATE '.join( ' ', $c->on_update );
    }

    return $def;
  }
}

1;
