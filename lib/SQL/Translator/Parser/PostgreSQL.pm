package SQL::Translator::Parser::PostgreSQL;

# -------------------------------------------------------------------
# $Id: PostgreSQL.pm,v 1.9 2003-02-26 05:17:21 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>,
#                    Allen Day <allenday@users.sourceforge.net>,
#                    darren chamberlain <darren@cpan.org>,
#                    Chris Mungall <cjm@fruitfly.org>
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

SQL::Translator::Parser::PostgreSQL - parser for PostgreSQL

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::PostgreSQL;

  my $translator = SQL::Translator->new;
  $translator->parser("SQL::Translator::Parser::PostgreSQL");

=head1 DESCRIPTION

The grammar was started from the MySQL parsers.  Here is the description 
from PostgreSQL:

Table:
(http://www.postgresql.org/docs/view.php?version=7.3&idoc=1&file=sql-createtable.html)

  CREATE [ [ LOCAL ] { TEMPORARY | TEMP } ] TABLE table_name (
      { column_name data_type [ DEFAULT default_expr ] 
         [ column_constraint [, ... ] ]
      | table_constraint }  [, ... ]
  )
  [ INHERITS ( parent_table [, ... ] ) ]
  [ WITH OIDS | WITHOUT OIDS ]
  
  where column_constraint is:
  
  [ CONSTRAINT constraint_name ]
  { NOT NULL | NULL | UNIQUE | PRIMARY KEY |
    CHECK (expression) |
    REFERENCES reftable [ ( refcolumn ) ] [ MATCH FULL | MATCH PARTIAL ]
      [ ON DELETE action ] [ ON UPDATE action ] }
  [ DEFERRABLE | NOT DEFERRABLE ] 
  [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]
  
  and table_constraint is:
  
  [ CONSTRAINT constraint_name ]
  { UNIQUE ( column_name [, ... ] ) |
    PRIMARY KEY ( column_name [, ... ] ) |
    CHECK ( expression ) |
    FOREIGN KEY ( column_name [, ... ] ) 
     REFERENCES reftable [ ( refcolumn [, ... ] ) ]
      [ MATCH FULL | MATCH PARTIAL ] 
      [ ON DELETE action ] [ ON UPDATE action ] }
  [ DEFERRABLE | NOT DEFERRABLE ] 
  [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]

Index:
(http://www.postgresql.org/docs/view.php?version=7.3&idoc=1&file=sql-createindex.html)

  CREATE [ UNIQUE ] INDEX index_name ON table
      [ USING acc_method ] ( column [ ops_name ] [, ...] )
      [ WHERE predicate ]
  CREATE [ UNIQUE ] INDEX index_name ON table
      [ USING acc_method ] ( func_name( column [, ... ]) [ ops_name ] )
      [ WHERE predicate ]

Alter table:

  ALTER TABLE [ ONLY ] table [ * ]
      ADD [ COLUMN ] column type [ column_constraint [ ... ] ]
  ALTER TABLE [ ONLY ] table [ * ]
      ALTER [ COLUMN ] column { SET DEFAULT value | DROP DEFAULT }
  ALTER TABLE [ ONLY ] table [ * ]
      ALTER [ COLUMN ] column SET STATISTICS integer
  ALTER TABLE [ ONLY ] table [ * ]
      RENAME [ COLUMN ] column TO newcolumn
  ALTER TABLE table
      RENAME TO new_table
  ALTER TABLE table
      ADD table_constraint_definition
  ALTER TABLE [ ONLY ] table 
          DROP CONSTRAINT constraint { RESTRICT | CASCADE }
  ALTER TABLE table
          OWNER TO new_owner 

=cut

use strict;
use vars qw[ $DEBUG $VERSION $GRAMMAR @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

use Data::Dumper;
use Parse::RecDescent;
use Exporter;
use base qw(Exporter);

@EXPORT_OK = qw(parse);

# Enable warnings within the Parse::RecDescent module.
$::RD_ERRORS = 1; # Make sure the parser dies when it encounters an error
$::RD_WARN   = 1; # Enable warnings. This will warn on unused rules &c.
$::RD_HINT   = 1; # Give out hints to help fix problems.

my $parser; # should we do this?  There's no programmic way to 
            # change the grammar, so I think this is safe.

$GRAMMAR = q!

{ our ( %tables, $table_order ) }

#
# The "eofile" rule makes the parser fail if any "statement" rule
# fails.  Otherwise, the first successful match by a "statement" 
# won't cause the failure needed to know that the parse, as a whole,
# failed. -ky
#
startrule : statement(s) eofile { \%tables }

eofile : /^\Z/

statement : create
  | comment
  | alter
  | grant
  | revoke
  | drop
  | connect
  | set
  | <error>

connect : /^\s*\\\connect.*\n/

set : /SET/ /[^;]*/ ';'

revoke : /revoke/i WORD(s /,/) /on/i table_name /from/i name_with_opt_quotes(s /,/) ';'
    {
        my $table_name = $item{'table_name'};
        push @{ $tables{ $table_name }{'permissions'} }, {
            type       => 'revoke',
            actions    => $item[2],
            users      => $item[6],
        }
    }

grant : /grant/i WORD(s /,/) /on/i table_name /to/i name_with_opt_quotes(s /,/) ';'
    {
        my $table_name = $item{'table_name'};
        push @{ $tables{ $table_name }{'permissions'} }, {
            type       => 'grant',
            actions    => $item[2],
            users      => $item[6],
        }
    }

drop : /drop/i /[^;]*/ ';'

#
# Create table.
#
create : create_table table_name '(' create_definition(s /,/) ')' table_option(s?) ';'
    {
        my $table_name                       = $item{'table_name'};
        $tables{ $table_name }{'order'}      = ++$table_order;
        $tables{ $table_name }{'table_name'} = $table_name;

        my $i = 1;
        my @constraints;
        for my $definition ( @{ $item[4] } ) {
            if ( $definition->{'type'} eq 'field' ) {
                my $field_name = $definition->{'name'};
                $tables{ $table_name }{'fields'}{ $field_name } = 
                    { %$definition, order => $i };
                $i++;
				
                if ( $definition->{'is_primary_key'} ) {
                    push @{ $tables{ $table_name }{'indices'} }, {
                        type   => 'primary_key',
                        fields => [ $field_name ],
                    };
                }

                for my $constraint ( @{ $definition->{'constaints'} || [] } ) {
                    $constraint->{'fields' } = [ $field_name ];
                    push @{$tables{ $table_name }{'constraints'}}, $constraint;
                }
            }
            elsif ( $definition->{'type'} eq 'constraint' ) {
                $definition->{'type'} = $definition->{'constraint_type'};
                push @{ $tables{ $table_name }{'constraints'} }, $definition;
            }
            else {
                push @{ $tables{ $table_name }{'indices'} }, $definition;
            }
        }

        for my $option ( @{ $item[6] } ) {
            $tables{ $table_name }{'table_options'}{ $option->{'type'} } = 
                $option;
        }

        1;
    }

#
# Create index.
#
create : /create/i unique(?) /(index|key)/i index_name /on/i table_name using_method(?) '(' field_name(s /,/) ')' where_predicate(?) ';'
    {
        push @{ $tables{ $item{'table_name'} }{'indices'} },
            {
                name   => $item{'index_name'},
                type   => $item{'unique'}[0] ? 'unique' : 'normal',
                fields => $item[9],
                method => $item{'using_method'}[0],
            }
        ;
    }

#
# Create anything else (e.g., domain, function, etc.)
#
create : /create/i WORD /[^;]+/ ';'

using_method : /using/i WORD { $item[2] }

where_predicate : /where/i /[^;]+/

create_definition : field
    | table_constraint
    | <error>

comment : /^\s*(?:#|-{2}).*\n/

field : comment(s?) field_name data_type field_meta(s?) comment(s?)
    {
        my ( $default, @constraints );
        for my $meta ( @{ $item[4] } ) {
            $default = $meta if $meta->{'meta_type'} eq 'default';
            push @constraints, $meta if $meta->{'meta_type'} eq 'constraint';
        }

        my $null = ( grep { $_->{'type'} eq 'not_null' } @constraints ) ? 0 : 1;

        my @comments = ( @{ $item[1] }, @{ $item[5] } );

        $return = { 
            type           => 'field',
            name           => $item{'field_name'}, 
            data_type      => $item{'data_type'}{'type'},
            size           => $item{'data_type'}{'size'},
            list           => $item{'data_type'}{'list'},
            null           => $null,
            default        => $default->{'value'},
            constraints    => [ @constraints ],
            comments       => [ @comments ],
        } 
    }
    | <error>

field_meta : default_val
    |
    column_constraint

column_constraint : constraint_name(?) column_constraint_type deferrable(?) deferred(?)
    {
        my $desc       = $item{'column_constraint_type'};
        my $type       = $desc->{'type'};
        my $fields     = $desc->{'fields'}     || [];
        my $expression = $desc->{'expression'} || '';

        $return              =  {
            meta_type        => 'constraint',
            name             => $item{'constraint_name'}[0] || '',
            type             => $type,
            expression       => $type eq 'check' ? $expression : '',
            deferreable      => $item{'deferrable'},
            deferred         => $item{'deferred'},
            reference_table  => $desc->{'reference_table'},
            reference_fields => $desc->{'reference_fields'},
            match_type       => $desc->{'match_type'},
            on_delete_do     => $desc->{'on_delete_do'},
            on_update_do     => $desc->{'on_update_do'},
        } 
    }

constraint_name : /constraint/i name_with_opt_quotes { $item[2] }

column_constraint_type : /not null/i { $return = { type => 'not_null' } }
    |
    /null/ 
        { $return = { type => 'null' } }
    |
    /unique/ 
        { $return = { type => 'unique' } }
    |
    /primary key/i 
        { $return = { type => 'primary_key' } }
    |
    /check/i '(' /[^)]+/ ')' 
        { $return = { type => 'check', expression => $item[2] } }
    |
    /references/i table_name parens_value_list(?) match_type(?) on_delete_do(?) on_update_do(?)
    {
        $return              =  {
            type             => 'foreign_key',
            reference_table  => $item[2],
            reference_fields => $item[3],
            match_type       => $item[4][0],
            on_delete_do     => $item[5][0],
            on_update_do     => $item[6][0],
        }
    }

table_name : name_with_opt_quotes

field_name : name_with_opt_quotes

name_with_opt_quotes : double_quote(?) NAME double_quote(?) { $item[2] }

double_quote: /"/

index_name : WORD

data_type : pg_data_type parens_value_list(?)
    { 
        my $type = $item[1];

        #
        # We can deduce some sizes from the data type's name.
        #
        my $size; 
        if ( ref $type eq 'ARRAY' ) {
            $size = [ $type->[1] ];
            $type = $type->[0];
        }
        else {
            $size = $item[2][0] || '';
        }

        $return  = { 
            type => $type,
            size => $size,
        } 
    }

pg_data_type :
    /(bigint|int8|bigserial|serial8)/ { $return = [ 'integer', 8 ] }
    |
    /(smallint|int2)/ { $return = [ 'integer', 2 ] }
    |
    /int(eger)?|int4/ { $return = [ 'integer', 4 ] }
    |
    /(double precision|float8?)/ { $return = [ 'float', 8 ] }
    |
    /(real|float4)/ { $return = [ 'real', 4 ] }
    |
    /serial4?/ { $return = [ 'serial', 4 ] }
    |
    /bigserial/ { $return = [ 'serial', 8 ] }
    |
    /(bit varying|varbit)/ { $return = 'varbit' }
    |
    /character varying/ { $return = 'varchar' }
    |
    /char(acter)?/ { $return = 'char' }
    |
    /bool(ean)?/ { $return = 'boolean' }
    |
    /(bytea|binary data)/ { $return = 'binary' }
    |
    /timestampz?/ { $return = 'timestamp' }
    |
    /(bit|box|cidr|circle|date|inet|interval|line|lseg|macaddr|money|numeric|decimal|path|point|polygon|text|time|varchar)/
    { $item[1] }

parens_value_list : '(' VALUE(s /,/) ')'
    { $item[2] }

parens_word_list : '(' WORD(s /,/) ')'
    { $item[2] }

field_size : '(' num_range ')' { $item{'num_range'} }

num_range : DIGITS ',' DIGITS
    { $return = $item[1].','.$item[3] }
    | DIGITS
    { $return = $item[1] }

table_constraint : comment(s?) constraint_name(?) table_constraint_type deferrable(?) deferred(?) comment(s?)
    {
        my $desc       = $item{'table_constraint_type'};
        my $type       = $desc->{'type'};
        my $fields     = $desc->{'fields'};
        my $expression = $desc->{'expression'};
        my @comments   = ( @{ $item[1] }, @{ $item[-1] } );

        $return              =  {
            name             => $item{'constraint_name'}[0] || '',
            type             => 'constraint',
            constraint_type  => $type,
            fields           => $type ne 'check' ? $fields : [],
            expression       => $type eq 'check' ? $expression : '',
            deferreable      => $item{'deferrable'},
            deferred         => $item{'deferred'},
            reference_table  => $desc->{'reference_table'},
            reference_fields => $desc->{'reference_fields'},
            match_type       => $desc->{'match_type'}[0],
            on_delete_do     => $desc->{'on_delete_do'},
            on_update_do     => $desc->{'on_update_do'},
            comments         => [ @comments ],
        } 
    }

table_constraint_type : /primary key/i '(' name_with_opt_quotes(s /,/) ')' 
    { 
        $return = {
            type   => 'primary_key',
            fields => $item[3],
        }
    }
    |
    /unique/i '(' name_with_opt_quotes(s /,/) ')' 
    { 
        $return    =  {
            type   => 'unique',
            fields => $item[3],
        }
    }
    |
    /check/ '(' /(.+)/ ')'
    {
        $return        =  {
            type       => 'check',
            expression => $item[3],
        }
    }
    |
    /foreign key/i '(' name_with_opt_quotes(s /,/) ')' /references/i table_name parens_word_list(?) match_type(?) on_delete_do(?) on_update_do(?)
    {
        $return              =  {
            type             => 'foreign_key',
            fields           => $item[3],
            reference_table  => $item[6],
            reference_fields => $item[7][0],
            match_type       => $item[8][0],
            on_delete_do     => $item[9][0],
            on_update_do     => $item[10][0],
        }
    }

deferrable : /not/i /deferrable/i 
    { 
        $return = ( $item[1] =~ /not/i ) ? 0 : 1;
    }

deferred : /initially/i /(deferred|immediate)/i { $item[2] }

match_type : /match full/i { 'match_full' }
    |
    /match partial/i { 'match_partial' }

on_delete_do : /on delete/i WORD(s)
    { $item[2] }

on_update_do : /on update/i WORD(s)
    { $item[2] }

alter : alter_table table_name /add/i table_constraint ';' 
    { 
        my $table_name = $item[2];
        my $constraint = $item[4];
        $constraint->{'type'} = $constraint->{'constraint_type'};
        push @{ $tables{ $table_name }{'constraints'} }, $constraint;
    }

alter_table : /alter/i /table/i only(?)

only : /only/i

create_table : /create/i /table/i

create_index : /create/i /index/i

default_val  : /default/i /(?:')?[\w\d.-]*(?:')?/ 
    { 
        my $val =  $item[2] || '';
        $val    =~ s/'//g; 
        $return =  {
            meta_type => 'default',
            value     => $val,
        }
    }

name_with_opt_paren : NAME parens_value_list(s?)
    { $item[2][0] ? "$item[1]($item[2][0][0])" : $item[1] }

unique : /unique/i { 1 }

key : /key/i | /index/i

table_option : /inherits/i '(' name_with_opt_quotes(s /,/) ')'
    { 
        $return = { type => 'inherits', table_name => $item[3] }
    }
    |
    /with(out)? oids/i
    {
        $return = { type => $item[1] =~ /out/i ? 'without_oids' : 'with_oids' }
    }

SEMICOLON : /\s*;\n?/

WORD : /\w+/

DIGITS : /\d+/

COMMA : ','

NAME    : "`" /\w+/ "`"
    { $item[2] }
    | /\w+/
    { $item[1] }
    | /[\$\w]+/
    { $item[1] }

VALUE   : /[-+]?\.?\d+(?:[eE]\d+)?/
    { $item[1] }
    | /'.*?'/   # XXX doesn't handle embedded quotes
    { $item[1] }
    | /NULL/
    { 'NULL' }

!;

# -------------------------------------------------------------------
sub parse {
    my ( $translator, $data ) = @_;
    $parser ||= Parse::RecDescent->new($GRAMMAR);

    $::RD_TRACE  = $translator->trace ? 1 : undef;
    $DEBUG       = $translator->debug;

    unless (defined $parser) {
        return $translator->error("Error instantiating Parse::RecDescent ".
            "instance: Bad grammer");
    }

    my $result = $parser->startrule($data);
    die "Parse failed.\n" unless defined $result;
    warn Dumper($result) if $DEBUG;
    return $result;
}

1;

#-----------------------------------------------------
# Where man is not nature is barren.
# William Blake
#-----------------------------------------------------

=pod

=head1 AUTHORS

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>,
Allen Day <allenday@users.sourceforge.net>.

=head1 SEE ALSO

perl(1), Parse::RecDescent.

=cut
