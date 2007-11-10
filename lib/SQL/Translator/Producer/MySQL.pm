package SQL::Translator::Producer::MySQL;

# -------------------------------------------------------------------
# $Id: MySQL.pm,v 1.54 2007-11-10 03:36:43 mwz444 Exp $
# -------------------------------------------------------------------
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

=head1 NAME

SQL::Translator::Producer::MySQL - MySQL-specific producer for SQL::Translator

=head1 SYNOPSIS

Use via SQL::Translator:

  use SQL::Translator;

  my $t = SQL::Translator->new( parser => '...', producer => 'MySQL', '...' );
  $t->translate;

=head1 DESCRIPTION

This module will produce text output of the schema suitable for MySQL.
There are still some issues to be worked out with syntax differences 
between MySQL versions 3 and 4 ("SET foreign_key_checks," character sets
for fields, etc.).

=head2 Table Types

Normally the tables will be created without any explicit table type given and
so will use the MySQL default.

Any tables involved in foreign key constraints automatically get a table type
of InnoDB, unless this is overridden by setting the C<mysql_table_type> extra
attribute explicitly on the table.

=head2 Extra attributes.

The producer recognises the following extra attributes on the Schema objects.

=over 4

=item field.list

Set the list of allowed values for Enum fields.

=item field.binary, field.unsigned, field.zerofill

Set the MySQL field options of the same name.

=item table.mysql_table_type

Set the type of the table e.g. 'InnoDB', 'MyISAM'. This will be
automatically set for tables involved in foreign key constraints if it is
not already set explicitly. See L<"Table Types">.

=item mysql_character_set

MySql-4.1+. Set the tables character set.
Run SHOW CHARACTER SET to see list.

=item mysql_collate

MySql-4.1+. Set the tables colation order.

=item table.mysql_charset, table.mysql_collate

Set the tables default charater set and collation order.

=item field.mysql_charset, field.mysql_collate

Set the fields charater set and collation order.

=back

=cut

use strict;
use warnings;
use vars qw[ $VERSION $DEBUG %used_names ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.54 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

use Data::Dumper;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(debug header_comment);

#
# Use only lowercase for the keys (e.g. "long" and not "LONG")
#
my %translate  = (
    #
    # Oracle types
    #
    varchar2   => 'varchar',
    long       => 'text',
    clob       => 'longtext',

    #
    # Sybase types
    #
    int        => 'integer',
    money      => 'float',
    real       => 'double',
    comment    => 'text',
    bit        => 'tinyint',

    #
    # Access types
    #
    'long integer' => 'integer',
    'text'         => 'text',
    'datetime'     => 'datetime',
);

sub produce {
    my $translator     = shift;
    local $DEBUG       = $translator->debug;
    local %used_names;
    my $no_comments    = $translator->no_comments;
    my $add_drop_table = $translator->add_drop_table;
    my $schema         = $translator->schema;
    my $show_warnings  = $translator->show_warnings || 0;

    my ($qt, $qf) = ('','');
    $qt = '`' if $translator->quote_table_names;
    $qf = '`' if $translator->quote_field_names;

    debug("PKG: Beginning production\n");
    %used_names = ();
    my $create; 
    $create .= header_comment unless ($no_comments);
    # \todo Don't set if MySQL 3.x is set on command line
    $create .= "SET foreign_key_checks=0;\n\n";

    #
    # Work out which tables need to be InnoDB to support foreign key
    # constraints. We do this first as we need InnoDB at both ends.
    #
    foreach ( map { $_->get_constraints } $schema->get_tables ) {
        next unless $_->type eq FOREIGN_KEY;
        foreach my $meth (qw/table reference_table/) {
            my $table = $schema->get_table($_->$meth) || next;
            next if $table->extra('mysql_table_type');
            $table->extra( 'mysql_table_type' => 'InnoDB');
        }
    }

    #
    # Generate sql
    #
    my @table_defs =();
    for my $table ( $schema->get_tables ) {
#        print $table->name, "\n";
        push @table_defs, create_table($table, 
                                       { add_drop_table    => $add_drop_table,
                                         show_warnings     => $show_warnings,
                                         no_comments       => $no_comments,
                                         quote_table_names => $qt,
                                         quote_field_names => $qf
                                         });
    }

#    print "@table_defs\n";
    push @table_defs, "SET foreign_key_checks=1;\n\n";

    return wantarray ? ($create, @table_defs) : $create . join ('', @table_defs);
}

sub create_table
{
    my ($table, $options) = @_;

    my $qt = $options->{quote_table_names} || '';
    my $qf = $options->{quote_field_names} || '';

    my $table_name = $table->name;
    debug("PKG: Looking at table '$table_name'\n");

    #
    # Header.  Should this look like what mysqldump produces?
    #
    my $create = '';
    my $drop;
    $create .= "--\n-- Table: $qt$table_name$qt\n--\n" unless $options->{no_comments};
    $drop = qq[DROP TABLE IF EXISTS $qt$table_name$qt;\n] if $options->{add_drop_table};
    $create .= "CREATE TABLE $qt$table_name$qt (\n";

    #
    # Fields
    #
    my @field_defs;
    for my $field ( $table->get_fields ) {
        push @field_defs, create_field($field, $options);
    }

    #
    # Indices
    #
    my @index_defs;
    my %indexed_fields;
    for my $index ( $table->get_indices ) {
        push @index_defs, create_index($index, $options);
        $indexed_fields{ $_ } = 1 for $index->fields;
    }

    #
    # Constraints -- need to handle more than just FK. -ky
    #
    my @constraint_defs;
    my @constraints = $table->get_constraints;
    for my $c ( @constraints ) {
        my $constr = create_constraint($c, $options);
        push @constraint_defs, $constr if($constr);
        
         unless ( $indexed_fields{ ($c->fields())[0] } || $c->type ne FOREIGN_KEY ) {
             push @index_defs, "INDEX ($qf" . ($c->fields())[0] . "$qf)";
             $indexed_fields{ ($c->fields())[0] } = 1;
         }
    }

    $create .= join(",\n", map { "  $_" } 
                    @field_defs, @index_defs, @constraint_defs
                    );

    #
    # Footer
    #
    $create .= "\n)";
    $create .= generate_table_options($table) || '';
    $create .= ";\n\n";

    return $drop ? ($drop,$create) : $create;
}

sub generate_table_options 
{
  my ($table) = @_;
  my $create;

  my $table_type_defined = 0;
  for my $t1_option_ref ( $table->options ) {
    my($key, $value) = %{$t1_option_ref};
    $table_type_defined = 1
      if uc $key eq 'ENGINE' or uc $key eq 'TYPE';
    $create .= " $key=$value";
  }
  my $mysql_table_type = $table->extra('mysql_table_type');
  #my $charset          = $table->extra('mysql_character_set');
  #my $collate          = $table->extra('mysql_collate');
  #$create .= " Type=$mysql_table_type" if $mysql_table_type;
  #$create .= " DEFAULT CHARACTER SET $charset" if $charset;
  #$create .= " COLLATE $collate" if $collate;
  $create .= " Type=$mysql_table_type"
    if $mysql_table_type && !$table_type_defined;
  my $charset          = $table->extra('mysql_charset');
  my $collate          = $table->extra('mysql_collate');
  my $comments         = $table->comments;

  $create .= " DEFAULT CHARACTER SET $charset" if $charset;
  $create .= " COLLATE $collate" if $collate;
  $create .= qq[ comment='$comments'] if $comments;
  return $create;
}

sub create_field
{
    my ($field, $options) = @_;

    my $qf = $options->{quote_field_names} ||= '';

    my $field_name = $field->name;
    debug("PKG: Looking at field '$field_name'\n");
    my $field_def = "$qf$field_name$qf";

    # data type and size
    my $data_type = $field->data_type;
    my @size      = $field->size;
    my %extra     = $field->extra;
    my $list      = $extra{'list'} || [];
    # \todo deal with embedded quotes
    my $commalist = join( ', ', map { qq['$_'] } @$list );
    my $charset = $extra{'mysql_charset'};
    my $collate = $extra{'mysql_collate'};

    #
    # Oracle "number" type -- figure best MySQL type
    #
    if ( lc $data_type eq 'number' ) {
        # not an integer
        if ( scalar @size > 1 ) {
            $data_type = 'double';
        }
        elsif ( $size[0] && $size[0] >= 12 ) {
            $data_type = 'bigint';
        }
        elsif ( $size[0] && $size[0] <= 1 ) {
            $data_type = 'tinyint';
        }
        else {
            $data_type = 'int';
        }
    }
    #
    # Convert a large Oracle varchar to "text"
    #
    elsif ( $data_type =~ /char/i && $size[0] > 255 ) {
        $data_type = 'text';
        @size      = ();
    }
    elsif ( $data_type =~ /char/i && ! $size[0] ) {
        @size = (255);
    }
    elsif ( $data_type =~ /boolean/i ) {
        $data_type = 'enum';
        $commalist = "'0','1'";
    }
    elsif ( exists $translate{ lc $data_type } ) {
        $data_type = $translate{ lc $data_type };
    }

    @size = () if $data_type =~ /(text|blob)/i;

    if ( $data_type =~ /(double|float)/ && scalar @size == 1 ) {
        push @size, '0';
    }

    $field_def .= " $data_type";

    if ( lc $data_type eq 'enum' ) {
        $field_def .= '(' . $commalist . ')';
    } 
    elsif ( defined $size[0] && $size[0] > 0 ) {
        $field_def .= '(' . join( ', ', @size ) . ')';
    }

    # char sets
    $field_def .= " CHARACTER SET $charset" if $charset;
    $field_def .= " COLLATE $collate" if $collate;

    # MySQL qualifiers
    for my $qual ( qw[ binary unsigned zerofill ] ) {
        my $val = $extra{ $qual } || $extra{ uc $qual } or next;
        $field_def .= " $qual";
    }
    for my $qual ( 'character set', 'collate', 'on update' ) {
        my $val = $extra{ $qual } || $extra{ uc $qual } or next;
        $field_def .= " $qual $val";
    }

    # Null?
    $field_def .= ' NOT NULL' unless $field->is_nullable;

    # Default?  XXX Need better quoting!
    my $default = $field->default_value;
    if ( defined $default ) {
        if ( uc $default eq 'NULL') {
            $field_def .= ' DEFAULT NULL';
        } else {
            $field_def .= " DEFAULT '$default'";
        }
    }

    if ( my $comments = $field->comments ) {
        $field_def .= qq[ comment '$comments'];
    }

    # auto_increment?
    $field_def .= " auto_increment" if $field->is_auto_increment;

    return $field_def;
}

sub alter_create_index
{
    my ($index, $options) = @_;

    my $qt = $options->{quote_table_names} || '';
    my $qf = $options->{quote_field_names} || '';

    return join( ' ',
                 'ALTER TABLE',
                 $qt.$index->table->name.$qt,
                 'ADD',
                 create_index(@_)
                 );
}

sub create_index
{
    my ($index, $options) = @_;

    my $qf = $options->{quote_field_names} || '';

    return join( ' ', 
                 lc $index->type eq 'normal' ? 'INDEX' : $index->type . ' INDEX',
                 $index->name,
                 '(' . $qf . join( "$qf, $qf", $index->fields ) . $qf . ')'
                 );

}

sub alter_drop_index
{
    my ($index, $options) = @_;

    my $qt = $options->{quote_table_names} || '';
    my $qf = $options->{quote_field_names} || '';

    return join( ' ', 
                 'ALTER TABLE',
                 $qt.$index->table->name.$qt,
                 'DROP',
                 'INDEX',
                 $index->name || $index->fields
                 );

}

sub alter_drop_constraint
{
    my ($c, $options) = @_;

    my $qt      = $options->{quote_table_names} || '';
    my $qc      = $options->{quote_constraint_names} || '';

    my $out = sprintf('ALTER TABLE %s DROP %s %s',
                      $c->table->name,
                      $c->type,
                      $qc . $c->name . $qc );

    return $out;
}

sub alter_create_constraint
{
    my ($index, $options) = @_;

    my $qt = $options->{quote_table_names} || '';
    return join( ' ',
                 'ALTER TABLE',
                 $qt.$index->table->name.$qt,
                 'ADD',
                 create_constraint(@_) );
}

sub create_constraint
{
    my ($c, $options) = @_;

    my $qf      = $options->{quote_field_names} || '';
    my $qt      = $options->{quote_table_names} || '';
    my $leave_name      = $options->{leave_name} || undef;
    my $counter = ($options->{fk_name_counter}   ||= {});

    my @fields = $c->fields or next;

    if ( $c->type eq PRIMARY_KEY ) {
        return 'PRIMARY KEY (' . $qf . join("$qf, $qf", @fields). $qf . ')';
    }
    elsif ( $c->type eq UNIQUE ) {
        return
        'UNIQUE '. 
            (defined $c->name ? $qf.$c->name.$qf.' ' : '').
            '(' . $qf . join("$qf, $qf", @fields). $qf . ')';
    }
    elsif ( $c->type eq FOREIGN_KEY ) {
        #
        # Make sure FK field is indexed or MySQL complains.
        #

        my $table = $c->table;
        my $c_name = $c->name;

        # Give the constraint a name if it doesn't have one, so it doens't feel
        # left out
        unless ( $c_name ){
            $c_name   = $table->name . '_fk';
        }

        $counter->{$table} ||= {};
        my $def = join(' ', 
                       map { $_ || () } 
                         'CONSTRAINT', 
                         $qt . join('_', next_unused_name($c_name)
                                   ) . $qt, 
                         'FOREIGN KEY'
                      );


        $def .= ' ('.$qf . join( "$qf, $qf", @fields ) . $qf . ')';

        $def .= ' REFERENCES ' . $qt . $c->reference_table . $qt;

        my @rfields = map { $_ || () } $c->reference_fields;
        unless ( @rfields ) {
            my $rtable_name = $c->reference_table;
            if ( my $ref_table = $table->schema->get_table( $rtable_name ) ) {
                push @rfields, $ref_table->primary_key;
            }
            else {
                warn "Can't find reference table '$rtable_name' " .
                    "in schema\n" if $options->{show_warnings};
            }
        }

        if ( @rfields ) {
            $def .= ' (' . $qf . join( "$qf, $qf", @rfields ) . $qf . ')';
        }
        else {
            warn "FK constraint on " . $table->name . '.' .
                join('', @fields) . " has no reference fields\n" 
                if $options->{show_warnings};
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

    return undef;
}

sub alter_table
{
    my ($to_table, $options) = @_;

    my $qt = $options->{quote_table_name} || '';

    my $table_options = generate_table_options($to_table) || '';
    my $out = sprintf('ALTER TABLE %s%s',
                      $qt . $to_table->name . $qt,
                      $table_options);

    return $out;
}

sub alter_field
{
    my ($from_field, $to_field, $options) = @_;

    my $qf = $options->{quote_field_name} || '';
    my $qt = $options->{quote_table_name} || '';

    my $out = sprintf('ALTER TABLE %s CHANGE COLUMN %s %s',
                      $qt . $to_field->table->name . $qt,
                      $qf . $to_field->name . $qf,
                      create_field($to_field, $options));

    return $out;
}

sub add_field
{
    my ($new_field, $options) = @_;

    my $qt = $options->{quote_table_name} || '';

    my $out = sprintf('ALTER TABLE %s ADD COLUMN %s',
                      $qt . $new_field->table->name . $qt,
                      create_field($new_field, $options));

    return $out;

}

sub drop_field
{ 
    my ($old_field, $options) = @_;

    my $qf = $options->{quote_field_name} || '';
    my $qt = $options->{quote_table_name} || '';
    
    my $out = sprintf('ALTER TABLE %s DROP COLUMN %s',
                      $qt . $old_field->table->name . $qt,
                      $qf . $old_field->name . $qf);

    return $out;
    
}

sub next_unused_name {
  my $name       = shift || '';
  if ( !defined($used_names{$name}) ) {
    $used_names{$name} = $name;
    return $name;
  }

  my $i = 1;
  while ( defined($used_names{$name . '_' . $i}) ) {
    ++$i;
  }
  $name .= '_' . $i;
  $used_names{$name} = $name;
  return $name;
}

1;

# -------------------------------------------------------------------

=pod

=head1 SEE ALSO

SQL::Translator, http://www.mysql.com/.

=head1 AUTHORS

darren chamberlain E<lt>darren@cpan.orgE<gt>,
Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=cut
