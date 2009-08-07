package SQL::Translator::Producer::Oracle;

# -------------------------------------------------------------------
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

=head1 NAME

SQL::Translator::Producer::Oracle - Oracle SQL producer

=head1 SYNOPSIS

  use SQL::Translator;

  my $t = SQL::Translator->new( parser => '...', producer => 'Oracle' );
  print $translator->translate( $file );

=head1 DESCRIPTION

Creates an SQL DDL suitable for Oracle.

=head1 producer_args

=over

=item delay_constraints

This option remove the primary key and other key constraints from the
CREATE TABLE statement and adds ALTER TABLEs at the end with it.

=back

=head1 NOTES

=head2 Autoincremental primary keys

This producer uses sequences and triggers to autoincrement primary key
columns, if necessary. SQLPlus and DBI expect a slightly different syntax
of CREATE TRIGGER statement. You might have noticed that this
producer returns a scalar containing all statements concatenated by
newlines or an array of single statements depending on the context
(scalar, array) it has been called in.

SQLPlus expects following trigger syntax:

    CREATE OR REPLACE TRIGGER ai_person_id
    BEFORE INSERT ON person
    FOR EACH ROW WHEN (
     new.id IS NULL OR new.id = 0
    )
    BEGIN
     SELECT sq_person_id.nextval
     INTO :new.id
     FROM dual;
    END;
    /

Whereas if you want to create the same trigger using L<DBI/do>, you need
to omit the last slash:

    my $dbh = DBI->connect('dbi:Oracle:mysid', 'scott', 'tiger');
    $dbh->do("
        CREATE OR REPLACE TRIGGER ai_person_id
        BEFORE INSERT ON person
        FOR EACH ROW WHEN (
         new.id IS NULL OR new.id = 0
        )
        BEGIN
         SELECT sq_person_id.nextval
         INTO :new.id
         FROM dual;
        END;
    ");

If you call this producer in array context, we expect you want to process
the returned array of statements using L<DBI> like
L<DBIx::Class::Schema/deploy> does.

To get this working we removed the slash in those statements in version
0.09002 of L<SQL::Translator> when called in array context. In scalar
context the slash will be still there to ensure compatibility with SQLPlus.

=cut

use strict;
use vars qw[ $VERSION $DEBUG $WARN ];
$VERSION = '1.59';
$DEBUG   = 0 unless defined $DEBUG;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(header_comment);

my %translate  = (
    #
    # MySQL types
    #
    bigint     => 'number',
    double     => 'number',
    decimal    => 'number',
    float      => 'number',
    int        => 'number',
    integer    => 'number',
    mediumint  => 'number',
    smallint   => 'number',
    tinyint    => 'number',
    char       => 'char',
    varchar    => 'varchar2',
    tinyblob   => 'blob',
    blob       => 'blob',
    mediumblob => 'blob',
    longblob   => 'blob',
    tinytext   => 'varchar2',
    text       => 'clob',
    longtext   => 'clob',
    mediumtext => 'clob',
    enum       => 'varchar2',
    set        => 'varchar2',
    date       => 'date',
    datetime   => 'date',
    time       => 'date',
    timestamp  => 'date',
    year       => 'date',

    #
    # PostgreSQL types
    #
    numeric             => 'number',
    'double precision'  => 'number',
    serial              => 'number',
    bigserial           => 'number',
    money               => 'number',
    character           => 'char',
    'character varying' => 'varchar2',
    bytea               => 'BLOB',
    interval            => 'number',
    boolean             => 'number',
    point               => 'number',
    line                => 'number',
    lseg                => 'number',
    box                 => 'number',
    path                => 'number',
    polygon             => 'number',
    circle              => 'number',
    cidr                => 'number',
    inet                => 'varchar2',
    macaddr             => 'varchar2',
    bit                 => 'number',
    'bit varying'       => 'number',

    #
    # Oracle types
    #
    number              => 'number',
    varchar2            => 'varchar2',
    long                => 'clob',
);

#
# Oracle reserved words from:
# http://technet.oracle.com/docs/products/oracle8i/doc_library/\
# 817_doc/server.817/a85397/ap_keywd.htm
#
my %ora_reserved = map { $_, 1 } qw(
    ACCESS ADD ALL ALTER AND ANY AS ASC AUDIT 
    BETWEEN BY
    CHAR CHECK CLUSTER COLUMN COMMENT COMPRESS CONNECT CREATE CURRENT
    DATE DECIMAL DEFAULT DELETE DESC DISTINCT DROP
    ELSE EXCLUSIVE EXISTS 
    FILE FLOAT FOR FROM
    GRANT GROUP 
    HAVING
    IDENTIFIED IMMEDIATE IN INCREMENT INDEX INITIAL INSERT
    INTEGER INTERSECT INTO IS
    LEVEL LIKE LOCK LONG 
    MAXEXTENTS MINUS MLSLABEL MODE MODIFY 
    NOAUDIT NOCOMPRESS NOT NOWAIT NULL NUMBER 
    OF OFFLINE ON ONLINE OPTION OR ORDER
    PCTFREE PRIOR PRIVILEGES PUBLIC
    RAW RENAME RESOURCE REVOKE ROW ROWID ROWNUM ROWS
    SELECT SESSION SET SHARE SIZE SMALLINT START 
    SUCCESSFUL SYNONYM SYSDATE 
    TABLE THEN TO TRIGGER 
    UID UNION UNIQUE UPDATE USER
    VALIDATE VALUES VARCHAR VARCHAR2 VIEW
    WHENEVER WHERE WITH
);

#
# Oracle 8/9 max size of data types from:
# http://www.ss64.com/orasyntax/datatypes.html
#
my %max_size = (
    char      => 2000,
    nchar     => 2000,
    nvarchar2 => 4000,
    number    => [ 38, 127 ],
    raw       => 2000,
    varchar   => 4000,          # only synonym for varchar2
    varchar2  => 4000,
);

my $max_id_length    = 30;
my %used_identifiers = ();
my %global_names;
my %unreserve;
my %truncated;

# -------------------------------------------------------------------
sub produce {
    my $translator     = shift;
    $DEBUG             = $translator->debug;
    $WARN              = $translator->show_warnings || 0;
    my $no_comments    = $translator->no_comments;
    my $add_drop_table = $translator->add_drop_table;
    my $schema         = $translator->schema;
    my $delay_constraints = $translator->producer_args->{delay_constraints};
    my ($output, $create, @table_defs, @fk_defs, @trigger_defs, @index_defs, @constraint_defs);

    $create .= header_comment unless ($no_comments);

    if ( $translator->parser_type =~ /mysql/i ) {
        $create .= 
            "-- We assume that default NLS_DATE_FORMAT has been changed\n".
            "-- but we set it here anyway to be self-consistent.\n"
            unless $no_comments;

        $create .= 
        "ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS';\n\n";
    }

    for my $table ( $schema->get_tables ) { 
        my ( $table_def, $fk_def, $trigger_def, $index_def, $constraint_def ) = create_table(
            $table,
            {
                add_drop_table    => $add_drop_table,
                show_warnings     => $WARN,
                no_comments       => $no_comments,
                delay_constraints => $delay_constraints,
                wantarray         => wantarray ? 1 : 0,
            }
        );
        push @table_defs, @$table_def;
        push @fk_defs, @$fk_def;
        push @trigger_defs, @$trigger_def;
        push @index_defs, @$index_def;
        push @constraint_defs, @$constraint_def;
    }

    my (@view_defs);
    foreach my $view ( $schema->get_views ) {
        push @view_defs, create_view($view);
    }

    if (wantarray) {
        return defined $create ? $create : (), @table_defs, @view_defs, @fk_defs, @trigger_defs, @index_defs, @constraint_defs;
    }
    else {
        $create .= join ('', map { $_ ? "$_;\n\n" : () } @table_defs, @view_defs, @fk_defs, @index_defs, @constraint_defs);
        # triggers may NOT end with a semicolon
        $create .= join "\n\n", @trigger_defs;
        return $create;
    }
}

sub create_table {
    my ($table, $options) = @_;
    my $table_name = $table->name;
    
    my $item = '';
    my $drop;
    my (@create, @field_defs, @constraint_defs, @fk_defs, @trigger_defs);

    my $table_name_ur = unreserve($table_name) or next;

    push @create, "--\n-- Table: $table_name_ur\n--" unless $options->{no_comments};
    push @create, qq[DROP TABLE $table_name_ur CASCADE CONSTRAINTS] if $options->{add_drop_table};

        my ( %field_name_scope, @field_comments );
        for my $field ( $table->get_fields ) {
            my ($field_create, $field_defs, $trigger_defs, $field_comments) =
              create_field($field, $options, \%field_name_scope);
            push @create, @$field_create if ref $field_create;
            push @field_defs, @$field_defs if ref $field_defs;
            push @trigger_defs, @$trigger_defs if ref $trigger_defs;
            push @field_comments, @$field_comments if ref $field_comments;
        }

        #
        # Table options
        #
        my @table_options;
        for my $opt ( $table->options ) {
            if ( ref $opt eq 'HASH' ) {
                my ( $key, $value ) = each %$opt;
                if ( ref $value eq 'ARRAY' ) {
                    push @table_options, "$key\n(\n".  join ("\n",
                        map { "  $_->[0]\t$_->[1]" } 
                        map { [ each %$_ ] }
                        @$value
                    )."\n)";
                }
                elsif ( !defined $value ) {
                    push @table_options, $key;
                }
                else {
                    push @table_options, "$key    $value";
                }
            }
        }

        #
        # Table constraints
        #
        for my $c ( $table->get_constraints ) {
            my $name    = $c->name || '';
            my @fields  = map { unreserve( $_, $table_name ) } $c->fields;
            my @rfields = map { unreserve( $_, $table_name ) } 
                $c->reference_fields;
            next if !@fields && $c->type ne CHECK_C;

            if ( $c->type eq PRIMARY_KEY ) {
                # create a name if delay_constraints
                $name ||= mk_name( $table_name, 'pk' )
                  if $options->{delay_constraints};
                push @constraint_defs, ($name ? "CONSTRAINT $name " : '') .
                	'PRIMARY KEY (' . join( ', ', @fields ) . ')';
            }
            elsif ( $c->type eq UNIQUE ) {
            	# Don't create UNIQUE constraints identical to the primary key
            	if ( my $pk = $table->primary_key ) {
					my $u_fields = join(":", @fields);
					my $pk_fields = join(":", $pk->fields);
					next if $u_fields eq $pk_fields;
            	}

                $name ||= mk_name( $name || $table_name, 'u' );

                for my $f ( $c->fields ) {
                    my $field_def = $table->get_field( $f ) or next;
                    my $dtype     = $translate{ $field_def->data_type } or next;
                    if ( $WARN && $dtype =~ /clob/i ) {
                        warn "Oracle will not allow UNIQUE constraints on " .
                             "CLOB field '" . $field_def->table->name . '.' .
                             $field_def->name . ".'\n"
                    }
                }

                push @constraint_defs, "CONSTRAINT $name UNIQUE " .
                    '(' . join( ', ', @fields ) . ')';
            }
            elsif ( $c->type eq CHECK_C ) {
                $name ||= mk_name( $name || $table_name, 'ck' );
                my $expression = $c->expression || '';
                push @constraint_defs, "CONSTRAINT $name CHECK ($expression)";
            }
            elsif ( $c->type eq FOREIGN_KEY ) {
                $name = mk_name( join('_', $table_name, $c->fields). '_fk' );
                my $def = "CONSTRAINT $name FOREIGN KEY ";

                if ( @fields ) {
                    $def .= '(' . join( ', ', @fields ) . ')';
                }

                my $ref_table = unreserve($c->reference_table);

                $def .= " REFERENCES $ref_table";

                if ( @rfields ) {
                    $def .= ' (' . join( ', ', @rfields ) . ')';
                }

                if ( $c->match_type ) {
                    $def .= ' MATCH ' . 
                        ( $c->match_type =~ /full/i ) ? 'FULL' : 'PARTIAL';
                }

                if ( $c->on_delete ) {
                    $def .= ' ON DELETE '.join( ' ', $c->on_delete );
                }

                # disabled by plu 2007-12-29 - doesn't exist for oracle
                #if ( $c->on_update ) {
                #    $def .= ' ON UPDATE '.join( ' ', $c->on_update );
                #}

                push @fk_defs, sprintf("ALTER TABLE %s ADD %s", $table_name_ur, $def);
            }
        }

        #
        # Index Declarations
        #
        my @index_defs = ();
        for my $index ( $table->get_indices ) {
            my $index_name = $index->name || '';
            my $index_type = $index->type || NORMAL;
            my @fields     = map { unreserve( $_, $table_name ) }
                             $index->fields;
            next unless @fields;

            my @index_options;
            for my $opt ( $index->options ) {
                if ( ref $opt eq 'HASH' ) {
                    my ( $key, $value ) = each %$opt;
                    if ( ref $value eq 'ARRAY' ) {
                        push @table_options, "$key\n(\n".  join ("\n",
                            map { "  $_->[0]\t$_->[1]" } 
                            map { [ each %$_ ] }
                           @$value
                        )."\n)";
                    }
                    elsif ( !defined $value ) {
                        push @index_options, $key;
                    }
                    else {
                        push @index_options, "$key    $value";
                    }
                }
            }
            my $index_options = @index_options
              ? "\n".join("\n", @index_options) : '';

            if ( $index_type eq PRIMARY_KEY ) {
                $index_name = $index_name ? mk_name( $index_name ) 
                    : mk_name( $table_name, 'pk' );
                push @field_defs, 'CONSTRAINT '.$index_name.' PRIMARY KEY '.
                    '(' . join( ', ', @fields ) . ')';
            }
            elsif ( $index_type eq NORMAL ) {
                $index_name = $index_name ? mk_name( $index_name ) 
                    : mk_name( $table_name, $index_name || 'i' );
                push @index_defs, 
                    "CREATE INDEX $index_name on $table_name_ur (".
                        join( ', ', @fields ).  
                    ")$index_options";
            }
            elsif ( $index_type eq UNIQUE ) {
                $index_name = $index_name ? mk_name( $index_name ) 
                    : mk_name( $table_name, $index_name || 'i' );
                push @index_defs, 
                    "CREATE UNIQUE INDEX $index_name on $table_name_ur (".
                        join( ', ', @fields ).  
                    ")$index_options"; 
            }
            else {
                warn "Unknown index type ($index_type) on table $table_name.\n"
                    if $WARN;
            }
        }

        if ( my @table_comments = $table->comments ) {
            for my $comment ( @table_comments ) {
                next unless $comment;
                $comment =~ s/'/''/g;
                push @field_comments, "COMMENT ON TABLE $table_name_ur is\n '".
                $comment . "'" unless $options->{no_comments}
                ;
            }
        }

        my $table_options = @table_options 
            ? "\n".join("\n", @table_options) : '';
    push @create, "CREATE TABLE $table_name_ur (\n" .
            join( ",\n", map { "  $_" } @field_defs,
            ($options->{delay_constraints} ? () : @constraint_defs) ) .
            "\n)$table_options";

    @constraint_defs = map { 'ALTER TABLE '.$table_name_ur.' ADD '.$_  }
      @constraint_defs;

    if ( $WARN ) {
        if ( %truncated ) {
            warn "Truncated " . keys( %truncated ) . " names:\n";
            warn "\t" . join( "\n\t", sort keys %truncated ) . "\n";
        }

        if ( %unreserve ) {
            warn "Encounted " . keys( %unreserve ) .
                " unsafe names in schema (reserved or invalid):\n";
            warn "\t" . join( "\n\t", sort keys %unreserve ) . "\n";
        }
    }

    return \@create, \@fk_defs, \@trigger_defs, \@index_defs, ($options->{delay_constraints} ? \@constraint_defs : []);
}

sub alter_field {
    my ($from_field, $to_field, $options) = @_;

    my ($field_create, $field_defs, $trigger_defs, $field_comments) =
      create_field($to_field, $options, {});

    # Fix ORA-01442
    if ($to_field->is_nullable && !$from_field->is_nullable) {
        die 'Cannot remove NOT NULL from table field';
    } elsif (!$from_field->is_nullable && !$to_field->is_nullable) {
        @$field_defs = map { s/ NOT NULL//; $_} @$field_defs;
    }

    my $table_name = $to_field->table->name;
    my $table_name_ur = unreserve( $table_name );

    return 'ALTER TABLE '.$table_name_ur.' MODIFY ( '.join('', @$field_defs).' )';
}

sub add_field {
    my ($new_field, $options) = @_;

    my ($field_create, $field_defs, $trigger_defs, $field_comments) =
      create_field($new_field, $options, {});

    my $table_name = $new_field->table->name;
    my $table_name_ur = unreserve( $table_name );

    my $out = sprintf('ALTER TABLE %s ADD ( %s )',
                      $table_name_ur,
                      join('', @$field_defs));
    return $out;
}

sub create_field {
    my ($field, $options, $field_name_scope) = @_;

    my (@create, @field_defs, @trigger_defs, @field_comments);

    my $table_name = $field->table->name;
    my $table_name_ur = unreserve( $table_name );

    #
    # Field name
    #
    my $field_name    = mk_name(
                                $field->name, '', $field_name_scope, 1
                               );

    my $field_name_ur = unreserve( $field_name, $table_name );
    my $field_def     = $field_name_ur;
    $field->name( $field_name_ur );

    #
    # Datatype
    #
    my $check;
    my $data_type = lc $field->data_type;
    my @size      = $field->size;
    my %extra     = $field->extra;
    my $list      = $extra{'list'} || [];
    # \todo deal with embedded quotes
    my $commalist = join( ', ', map { qq['$_'] } @$list );

    if ( $data_type eq 'enum' ) {
        $check = "CHECK ($field_name_ur IN ($commalist))";
        $data_type = 'varchar2';
    }
    elsif ( $data_type eq 'set' ) {
        # XXX add a CHECK constraint maybe 
        # (trickier and slower, than enum :)
        $data_type = 'varchar2';
    }
    else {
        $data_type  = defined $translate{ $data_type } ?
          $translate{ $data_type } :
            $data_type;
        $data_type ||= 'varchar2';
    }
    
    # ensure size is not bigger than max size oracle allows for data type
    if ( defined $max_size{$data_type} ) {
        for ( my $i = 0 ; $i < scalar @size ; $i++ ) {
            my $max =
              ref( $max_size{$data_type} ) eq 'ARRAY'
              ? $max_size{$data_type}->[$i]
              : $max_size{$data_type};
            $size[$i] = $max if $size[$i] > $max;
        }
    }

    #
    # Fixes ORA-02329: column of datatype LOB cannot be 
    # unique or a primary key
    #
    if ( $data_type eq 'clob' && $field->is_primary_key ) {
        $data_type = 'varchar2';
        $size[0]   = 4000;
        warn "CLOB cannot be a primary key, changing to VARCHAR2\n"
          if $WARN;
    }

    if ( $data_type eq 'clob' && $field->is_unique ) {
        $data_type = 'varchar2';
        $size[0]   = 4000;
        warn "CLOB cannot be a unique key, changing to VARCHAR2\n"
          if $WARN;
    }

    #
    # Fixes ORA-00907: missing right parenthesis
    #
    if ( $data_type =~ /(date|clob)/i ) {
        undef @size;
    }

    $field_def .= " $data_type";
    if ( defined $size[0] && $size[0] > 0 ) {
        $field_def .= '(' . join( ', ', @size ) . ')';
    }

    #
    # Default value
    #
    my $default = $field->default_value;
    if ( defined $default ) {
        #
        # Wherein we try to catch a string being used as 
        # a default value for a numerical field.  If "true/false,"
        # then sub "1/0," otherwise just test the truthity of the
        # argument and use that (naive?).
        #
        if (ref $default and defined $$default) {
          $default = $$default;
        } elsif (ref $default) {
          $default = 'NULL';
        } elsif ( 
            $data_type =~ /^number$/i && 
            $default   !~ /^-?\d+$/     &&
            $default   !~ m/null/i
           ) {
            if ( $default =~ /^true$/i ) {
                $default = "'1'";
            } elsif ( $default =~ /^false$/i ) {
                $default = "'0'";
            } else {
                $default = $default ? "'1'" : "'0'";
            }
        } elsif ( 
                 $data_type =~ /date/ && (
                                          $default eq 'current_timestamp' 
                                          ||
                                          $default eq 'now()' 
                                         )
                ) {
            $default = 'SYSDATE';
        } else {
            $default = $default =~ m/null/i ? 'NULL' : "'$default'"
        } 

        $field_def .= " DEFAULT $default",
    }

    #
    # Not null constraint
    #
    unless ( $field->is_nullable ) {
        $field_def .= ' NOT NULL';
    }

    $field_def .= " $check" if $check;

    #
    # Auto_increment
    #
    if ( $field->is_auto_increment ) {
        my $base_name    = $table_name_ur . "_". $field_name;
        my $seq_name     = mk_name( $base_name, 'sq' );
        my $trigger_name = mk_name( $base_name, 'ai' );

        push @create, qq[DROP SEQUENCE $seq_name] if $options->{add_drop_table};
        push @create, "CREATE SEQUENCE $seq_name";
        my $trigger =
          "CREATE OR REPLACE TRIGGER $trigger_name\n" .
          "BEFORE INSERT ON $table_name_ur\n" .
          "FOR EACH ROW WHEN (\n" .
          " new.$field_name_ur IS NULL".
          " OR new.$field_name_ur = 0\n".
          ")\n".
          "BEGIN\n" .
          " SELECT $seq_name.nextval\n" .
          " INTO :new." . $field->name."\n" .
          " FROM dual;\n" .
          "END;\n";
        
        #
        # If wantarray is set we have to omit the last "/" in this statement so it
        # can be executed by DBI->do() directly.
        #
        $trigger .= "/" unless $options->{wantarray};
        
        push @trigger_defs, $trigger;
    }

    if ( lc $field->data_type eq 'timestamp' ) {
        my $base_name = $table_name_ur . "_". $field_name_ur;
        my $trig_name = mk_name( $base_name, 'ts' );
        my $trigger = 
          "CREATE OR REPLACE TRIGGER $trig_name\n".
          "BEFORE INSERT OR UPDATE ON $table_name_ur\n".
          "FOR EACH ROW WHEN (new.$field_name_ur IS NULL)\n".
          "BEGIN \n".
          " SELECT sysdate INTO :new.$field_name_ur FROM dual;\n".
          "END;\n";

          #
          # If wantarray is set we have to omit the last "/" in this statement so it
          # can be executed by DBI->do() directly.
          #
          $trigger .= "/" unless $options->{wantarray};

          push @trigger_defs, $trigger;
    }

    push @field_defs, $field_def;

    if ( my $comment = $field->comments ) {
        $comment =~ s/'/''/g;
        push @field_comments, 
          "COMMENT ON COLUMN $table_name_ur.$field_name_ur is\n '" .
            $comment . "';" unless $options->{no_comments};
    }

    return \@create, \@field_defs, \@trigger_defs, \@field_comments;

}


sub create_view {
    my ($view) = @_;

    my $out = sprintf("CREATE VIEW %s AS\n%s",
                      $view->name,
                      $view->sql);

    return $out;
}

# -------------------------------------------------------------------
sub mk_name {
    my $basename      = shift || ''; 
    my $type          = shift || ''; 
       $type          = '' if $type =~ /^\d/;
    my $scope         = shift || ''; 
    my $critical      = shift || '';
    my $basename_orig = $basename;
    my $max_name      = $type 
                        ? $max_id_length - (length($type) + 1) 
                        : $max_id_length;
    $basename         = substr( $basename, 0, $max_name ) 
                        if length( $basename ) > $max_name;
    my $name          = $type ? "${type}_$basename" : $basename;

    if ( $basename ne $basename_orig and $critical ) {
        my $show_type = $type ? "+'$type'" : "";
        warn "Truncating '$basename_orig'$show_type to $max_id_length ",
            "character limit to make '$name'\n" if $WARN;
        $truncated{ $basename_orig } = $name;
    }

    $scope ||= \%global_names;
    if ( my $prev = $scope->{ $name } ) {
        my $name_orig = $name;
        substr($name, $max_id_length - 2) = ""
            if length( $name ) >= $max_id_length - 1;
        $name        .= sprintf( "%02d", $prev++ );

        warn "The name '$name_orig' has been changed to ",
             "'$name' to make it unique.\n" if $WARN;

        $scope->{ $name_orig }++;
    }

    $scope->{ $name }++;
    return $name;
}

# -------------------------------------------------------------------
sub unreserve {
    my $name            = shift || '';
    my $schema_obj_name = shift || '';

    my ( $suffix ) = ( $name =~ s/(\W.*)$// ) ? $1 : '';

    # also trap fields that don't begin with a letter
    return $name if !$ora_reserved{ uc $name } && $name =~ /^[a-z]/i; 

    if ( $schema_obj_name ) {
        ++$unreserve{"$schema_obj_name.$name"};
    }
    else {
        ++$unreserve{"$name (table name)"};
    }

    my $unreserve = sprintf '%s_', $name;
    return $unreserve.$suffix;
}

1;

# -------------------------------------------------------------------
# All bad art is the result of good intentions.
# Oscar Wilde
# -------------------------------------------------------------------

=pod

=head1 CREDITS

Mad props to Tim Bunce for much of the logic stolen from his "mysql2ora"
script.

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

SQL::Translator, DDL::Oracle, mysql2ora.

=cut
