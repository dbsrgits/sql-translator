package SQL::Translator::Producer::MySQL;

# -------------------------------------------------------------------
# $Id: MySQL.pm,v 1.46 2005-12-16 05:49:37 grommit Exp $
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

=item field.binary field.unsigned field.zerofill

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

=item table.mysql_charset table.mysql_collate

Set the tables default charater set and collation order.

=item field.mysql_charset field.mysql_collate

Set the fields charater set and collation order.

=back

=cut

use strict;
use vars qw[ $VERSION $DEBUG ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.46 $ =~ /(\d+)\.(\d+)/;
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
    my $no_comments    = $translator->no_comments;
    my $add_drop_table = $translator->add_drop_table;
    my $schema         = $translator->schema;
    my $show_warnings  = $translator->show_warnings || 0;

    debug("PKG: Beginning production\n");

    my $create; 
    $create .= header_comment unless ($no_comments);
    # \todo Don't set if MySQL 3.x is set on command line
    $create .= "SET foreign_key_checks=0;\n\n";

    #
    # Work out which tables need to be InnoDB to support foreign key
    # constraints. We do this first as we need InnoDB at both ends.
    #
    foreach ( map { $_->get_constraints } $schema->get_tables ) {
        foreach my $meth (qw/table reference_table/) {
            my $table = $schema->get_table($_->$meth) || next;
            next if $table->extra('mysql_table_type');
            $table->extra( 'mysql_table_type' => 'InnoDB');
        }
    }

    #
    # Generate sql
    #
    for my $table ( $schema->get_tables ) {
        my $table_name = $table->name;
        debug("PKG: Looking at table '$table_name'\n");

        #
        # Header.  Should this look like what mysqldump produces?
        #
        $create .= "--\n-- Table: $table_name\n--\n" unless $no_comments;
        $create .= qq[DROP TABLE IF EXISTS $table_name;\n] if $add_drop_table;
        $create .= "CREATE TABLE $table_name (\n";

        #
        # Fields
        #
        my @field_defs;
        for my $field ( $table->get_fields ) {
            my $field_name = $field->name;
            debug("PKG: Looking at field '$field_name'\n");
            my $field_def = $field_name;

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
            push @field_defs, $field_def;
		}

        #
        # Indices
        #
        my @index_defs;
        my %indexed_fields;
        for my $index ( $table->get_indices ) {
            push @index_defs, join( ' ', 
                lc $index->type eq 'normal' ? 'INDEX' : $index->type,
                $index->name,
                '(' . join( ', ', $index->fields ) . ')'
            );
            $indexed_fields{ $_ } = 1 for $index->fields;
        }

        #
        # Constraints -- need to handle more than just FK. -ky
        #
        my @constraint_defs;
        my @constraints = $table->get_constraints;
        for my $c ( @constraints ) {
            my @fields = $c->fields or next;

            if ( $c->type eq PRIMARY_KEY ) {
                push @constraint_defs,
                    'PRIMARY KEY (' . join(', ', @fields). ')';
            }
            elsif ( $c->type eq UNIQUE ) {
                push @constraint_defs,
                    'UNIQUE '.
                    (defined $c->name ? $c->name.' ' : '').
                    '(' . join(', ', @fields). ')';
            }
            elsif ( $c->type eq FOREIGN_KEY ) {
                #
                # Make sure FK field is indexed or MySQL complains.
                #
                unless ( $indexed_fields{ $fields[0] } ) {
                    push @index_defs, "INDEX ($fields[0])";
                    $indexed_fields{ $fields[0] } = 1;
                }

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
                            "in schema\n" if $show_warnings;
                    }
                }

                if ( @rfields ) {
                    $def .= ' (' . join( ', ', @rfields ) . ')';
                }
                else {
                    warn "FK constraint on " . $table->name . '.' .
                        join('', @fields) . " has no reference fields\n" 
                        if $show_warnings;
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

                push @constraint_defs, $def;
            }
        }

        $create .= join(",\n", map { "  $_" } 
            @field_defs, @index_defs, @constraint_defs
        );

        #
        # Footer
        #
        $create .= "\n)";
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
        $create .= ";\n\n";
    }

    return $create;
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
