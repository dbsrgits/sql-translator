package SQL::Translator::Parser::PostgreSQL;

=head1 NAME

SQL::Translator::Parser::PostgreSQL - parser for PostgreSQL

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::PostgreSQL;

  my $translator = SQL::Translator->new;
  $translator->parser("SQL::Translator::Parser::PostgreSQL");

=head1 DESCRIPTION

The grammar was started from the MySQL parsers.  Here is the description
from PostgreSQL, truncated to what's currently supported (patches welcome, of course) :

Table:
(http://www.postgresql.org/docs/current/sql-createtable.html)

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
  [ DEFERRABLE | NOT DEFERRABLE ] [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]

  and table_constraint is:

  [ CONSTRAINT constraint_name ]
  { UNIQUE ( column_name [, ... ] ) |
    PRIMARY KEY ( column_name [, ... ] ) |
    CHECK ( expression ) |
    EXCLUDE [USING acc_method] (expression) [INCLUDE (column [, ...])] [WHERE (predicate)]
    FOREIGN KEY ( column_name [, ... ] )
     REFERENCES reftable [ ( refcolumn [, ... ] ) ]
      [ MATCH FULL | MATCH PARTIAL ] [ ON DELETE action ] [ ON UPDATE action ] }
  [ DEFERRABLE | NOT DEFERRABLE ] [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]

Index :
(http://www.postgresql.org/docs/current/sql-createindex.html)

  CREATE [ UNIQUE ] INDEX index_name ON table
      [ USING acc_method ] ( column [ ops_name ] [, ...] )
      [ INCLUDE  ( column [, ...] ) ]
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

View :

    CREATE [ OR REPLACE ] VIEW view [ ( column name list ) ] AS SELECT query

=cut

use strict;
use warnings;

our $VERSION = '1.66';

our $DEBUG;
$DEBUG = 0 unless defined $DEBUG;

use Data::Dumper;
use SQL::Translator::Utils qw/ddl_parser_instance/;

use base qw(Exporter);
our @EXPORT_OK = qw(parse);

our $GRAMMAR = <<'END_OF_GRAMMAR';

{ my ( %tables, @views, @triggers, $table_order, $field_order, @table_comments) }

#
# The "eofile" rule makes the parser fail if any "statement" rule
# fails.  Otherwise, the first successful match by a "statement"
# won't cause the failure needed to know that the parse, as a whole,
# failed. -ky
#
startrule : statement(s) eofile {
    {
        tables => \%tables,
        views => \@views,
        triggers => \@triggers,
    }
}

eofile : /^\Z/

statement : create
  | comment_on_table
  | comment_on_column
  | comment_on_other
  | comment
  | alter
  | grant
  | revoke
  | drop
  | insert
  | connect
  | update
  | set
  | select
  | copy
  | readin_symbol
  | commit
  | <error>

commit : /commit/i ';'

connect : /^\s*\\connect.*\n/

set : /set/i /[^;]*/ ';'

revoke : /revoke/i WORD(s /,/) /on/i TABLE(?) table_id /from/i NAME(s /,/) ';'
    {
        my $table_info  = $item{'table_id'};
        my $schema_name = $table_info->{'schema_name'};
        my $table_name  = $table_info->{'table_name'};
        push @{ $tables{ $table_name }{'permissions'} }, {
            type       => 'revoke',
            actions    => $item[2],
            users      => $item[7],
        }
    }

revoke : /revoke/i WORD(s /,/) /on/i SCHEMA(?) schema_name /from/i NAME(s /,/) ';'
    { 1 }

grant : /grant/i WORD(s /,/) /on/i TABLE(?) table_id /to/i NAME(s /,/) ';'
    {
        my $table_info  = $item{'table_id'};
        my $schema_name = $table_info->{'schema_name'};
        my $table_name  = $table_info->{'table_name'};
        push @{ $tables{ $table_name }{'permissions'} }, {
            type       => 'grant',
            actions    => $item[2],
            users      => $item[7],
        }
    }

grant : /grant/i WORD(s /,/) /on/i SCHEMA(?) schema_name /to/i NAME(s /,/) ';'
    { 1 }

drop : /drop/i /[^;]*/ ';'

string :
   /'(\.|''|[^\\'])*'/

nonstring : /[^;\'"]+/

statement_body : string | nonstring

insert : /insert/i statement_body(s?) ';'

update : /update/i statement_body(s?) ';'

#
# Create table.
#
create : CREATE temporary(?) TABLE table_id '(' create_definition(s? /,/) ')' table_option(s?) ';'
    {
        my $table_info  = $item{'table_id'};
        my $schema_name = $table_info->{'schema_name'};
        my $table_name  = $table_info->{'table_name'};
        $tables{ $table_name }{'order'}       = ++$table_order;
        $tables{ $table_name }{'schema_name'} = $schema_name;
        $tables{ $table_name }{'table_name'}  = $table_name;

        $tables{ $table_name }{'temporary'} = $item[2][0];

        if ( @table_comments ) {
            $tables{ $table_name }{'comments'} = [ @table_comments ];
            @table_comments = ();
        }

        my @constraints;
        for my $definition ( @{ $item[6] } ) {
            if ( $definition->{'supertype'} eq 'field' ) {
                my $field_name = $definition->{'name'};
                $tables{ $table_name }{'fields'}{ $field_name } =
                    { %$definition, order => $field_order++ };

                for my $constraint ( @{ $definition->{'constraints'} || [] } ) {
                    $constraint->{'fields'} = [ $field_name ];
                    push @{ $tables{ $table_name }{'constraints'} },
                        $constraint;
                }
            }
            elsif ( $definition->{'supertype'} eq 'constraint' ) {
                push @{ $tables{ $table_name }{'constraints'} }, $definition;
            }
            elsif ( $definition->{'supertype'} eq 'index' ) {
                push @{ $tables{ $table_name }{'indices'} }, $definition;
            }
        }

        for my $option ( @{ $item[8] } ) {
            $tables{ $table_name }{'table_options(s?)'}{ $option->{'type'} } =
                $option;
        }

        1;
    }

create : CREATE unique(?) /(index|key)/i index_name /on/i table_id using_method(?) '(' field_name(s /,/) ')' include_covering(?) where_predicate(?) ';'
    {
        my $table_info  = $item{'table_id'};
        my $schema_name = $table_info->{'schema_name'};
        my $table_name  = $table_info->{'table_name'};
        push @{ $tables{ $table_name }{'indices'} },
            {
                name      => $item{'index_name'},
                supertype => $item{'unique'}[0] ? 'constraint' : 'index',
                type      => $item{'unique'}[0] ? 'unique'     : 'normal',
                fields    => $item[9],
                method    => $item{'using_method(?)'}[0],
                where     => $item{'where_predicate(?)'}[0],
                include   => $item{'include_covering(?)'}[0]
            }
        ;
    }

create : CREATE or_replace(?) temporary(?) VIEW view_id view_fields(?) /AS/i view_target ';'
    {
        push @views, {
            schema_name  => $item{view_id}{schema_name},
            view_name    => $item{view_id}{view_name},
            sql          => $item{view_target},
            fields       => $item[6],
            is_temporary => $item[3][0],
        }
    }

create: CREATE /MATERIALIZED VIEW/i if_not_exists(?) view_id view_fields(?) /AS/i view_target ';'
    {
        push @views, {
            schema_name  => $item{view_id}{schema_name},
            view_name    => $item{view_id}{view_name},
            sql          => $item{view_target},
            fields       => $item[5],
            extra        => { materialized => 1 }
        }
    }

if_not_exists : /IF NOT EXISTS/i

trigger_name : NAME

trigger_scope : /FOR/i /EACH/i /(ROW|STATEMENT)/i { $return = lc $1 }

before_or_after : /(before|after)/i { $return = lc $1 }

trigger_action : /.+/

database_event : /insert|update|delete/i
database_events : database_event(s /OR/)

create : CREATE /TRIGGER/i trigger_name before_or_after database_events /ON/i table_id trigger_scope(?) trigger_action
    {
        # Hack to pass roundtrip tests which have trigger statements terminated by double semicolon
        # and expect the returned data to have the same
        my $action = $item{trigger_action};
        $action =~ s/;$//;

        push @triggers, {
            name => $item{trigger_name},
            perform_action_when => $item{before_or_after},
            database_events => $item{database_events},
            on_table => $item{table_id}{table_name},
            scope => $item{'trigger_scope(?)'}[0],
            action => $action,
        }
    }

#
# Create anything else (e.g., domain, etc.)
#
create : CREATE WORD /[^;]+/ ';'
    { @table_comments = (); }

using_method : /using/i WORD { $item[2] }

where_predicate : /where/i /[^;]+/

where_paren_predicate : /where/i '(' /[^;]+/ ')'

include_covering : /include/i '(' covering_field_name(s /,/) ')'
  { $item{'covering_field_name(s)'} }

create_definition : field
    | table_constraint
    | <error>

comment : /^\s*(?:#|-{2})(.*)\n/
    {
        my $comment =  $item[1];
        $comment    =~ s/^\s*(#|-*)\s*//;
        $comment    =~ s/\s*$//;
        $return     = $comment;
        push @table_comments, $comment;
    }

comment_on_table : /comment/i /on/i /table/i table_id /is/i comment_phrase ';'
    {
        my $table_info  = $item{'table_id'};
        my $schema_name = $table_info->{'schema_name'};
        my $table_name  = $table_info->{'table_name'};
        push @{ $tables{ $table_name }{'comments'} }, $item{'comment_phrase'};
    }

comment_on_column : /comment/i /on/i /column/i column_name /is/i comment_phrase ';'
    {
        my $table_name = $item[4]->{'table'};
        my $field_name = $item[4]->{'field'};
        if ($tables{ $table_name }{'fields'}{ $field_name } ) {
          push @{ $tables{ $table_name }{'fields'}{ $field_name }{'comments'} },
              $item{'comment_phrase'};
        }
        else {
           die "No such column as $table_name.$field_name";
        }
    }

comment_on_other : /comment/i /on/i /\w+/ /\w+/ /is/i comment_phrase ';'
    {
        push(@table_comments, $item{'comment_phrase'});
    }

# [added by cjm 20041019]
# [TODO: other comment-on types]
# for now we just have a general mechanism for handling other
# kinds of comments than table/column; I'm not sure of the best
# way to incorporate these into the datamodel
#
# this is the exhaustive list of types of comment:
#COMMENT ON DATABASE my_database IS 'Development Database';
#COMMENT ON INDEX my_index IS 'Enforces uniqueness on employee id';
#COMMENT ON RULE my_rule IS 'Logs UPDATES of employee records';
#COMMENT ON SEQUENCE my_sequence IS 'Used to generate primary keys';
#COMMENT ON TABLE my_table IS 'Employee Information';
#COMMENT ON TYPE my_type IS 'Complex Number support';
#COMMENT ON VIEW my_view IS 'View of departmental costs';
#COMMENT ON COLUMN my_table.my_field IS 'Employee ID number';
#COMMENT ON TRIGGER my_trigger ON my_table IS 'Used for R.I.';
#
# this is tested by test 08

column_name : NAME '.' NAME
    { $return = { table => $item[1], field => $item[3] } }

comment_phrase : /null/i
    { $return = 'NULL' }
    | SQSTRING
    | DOLLARSTRING

field : field_comment(s?) field_name data_type field_meta(s?) field_comment(s?)
    {
        my ( $default, @constraints, $is_pk );
        my $is_nullable = 1;
        for my $meta ( @{ $item[4] } ) {
            if ( $meta->{'type'} eq 'default' ) {
                $default = $meta;
                next;
            }
            elsif ( $meta->{'type'} eq 'not_null' ) {
                $is_nullable = 0;
            }
            elsif ( $meta->{'type'} eq 'primary_key' ) {
                $is_pk = 1;
            }

            push @constraints, $meta if $meta->{'supertype'} eq 'constraint';
        }

        my @comments = ( @{ $item[1] }, @{ $item[5] } );

        $return = {
            supertype         => 'field',
            name              => $item{'field_name'},
            data_type         => $item{'data_type'}{'type'},
            size              => $item{'data_type'}{'size'},
            is_nullable       => $is_nullable,
            default           => $default->{'value'},
            constraints       => [ @constraints ],
            comments          => [ @comments ],
            is_primary_key    => $is_pk || 0,
            is_auto_increment => $item{'data_type'}{'is_auto_increment'},
        }
    }
    | <error>

field_comment : /^\s*(?:#|-{2})(.*)\n/
    {
        my $comment =  $item[1];
        $comment    =~ s/^\s*(#|-*)\s*//;
        $comment    =~ s/\s*$//;
        $return     = $comment;
    }

field_meta : default_val
    | column_constraint

view_fields : '(' field_name(s /,/) ')'
    { $return = join (',', @{$item[2]} ) }

column_constraint : constraint_name(?) column_constraint_type deferrable(?) deferred(?)
    {
        my $desc       = $item{'column_constraint_type'};
        my $type       = $desc->{'type'};
        my $fields     = $desc->{'fields'}     || [];
        my $expression = $desc->{'expression'} || '';

        $return              =  {
            supertype        => 'constraint',
            name             => $item{'constraint_name'}[0] || '',
            type             => $type,
            expression       => $type eq 'check' ? $expression : '',
            deferrable       => $item{'deferrable'},
            deferred         => $item{'deferred'},
            reference_table  => $desc->{'reference_table'},
            reference_fields => $desc->{'reference_fields'},
            match_type       => $desc->{'match_type'},
            on_delete        => $desc->{'on_delete'} || $desc->{'on_delete_do'},
            on_update        => $desc->{'on_update'} || $desc->{'on_update_do'},
        }
    }

constraint_name : /constraint/i NAME { $item[2] }

column_constraint_type : /not null/i { $return = { type => 'not_null' } }
    |
    /null/i
        { $return = { type => 'null' } }
    |
    /unique/i
        { $return = { type => 'unique' } }
    |
    /primary key/i
        { $return = { type => 'primary_key' } }
    |
    /check/i '(' /[^)]+/ ')'
        { $return = { type => 'check', expression => $item[3] } }
    |
    /references/i table_id parens_word_list(?) match_type(?) key_action(s?)
    {
        my $table_info  = $item{'table_id'};
        my $schema_name = $table_info->{'schema_name'};
        my $table_name  = $table_info->{'table_name'};
        my ( $on_delete, $on_update );
        for my $action ( @{ $item[5] || [] } ) {
            $on_delete = $action->{'action'} if $action->{'type'} eq 'delete';
            $on_update = $action->{'action'} if $action->{'type'} eq 'update';
        }

        $return              =  {
            type             => 'foreign_key',
            reference_table  => $table_name,
            reference_fields => $item[3][0],
            match_type       => $item[4][0],
            on_delete        => $on_delete,
            on_update        => $on_update,
        }
    }

table_id : schema_qualification(?) NAME {
    $return = { schema_name => $item[1][0], table_name => $item[2] }
}

view_id : schema_qualification(?) NAME {
    $return = { schema_name => $item[1][0], view_name => $item[2] }
}

view_target : /select|with/i /[^;]+/ {
    $return = "$item[1] $item[2]";
}

# SELECT views _may_ support outer parens, and we used to produce
# such sql, although non-standard. Use ugly lookeahead to parse
view_target : '('   /select/i    / [^;]+ (?= \) ) /x    ')'    {
    $return = "$item[2] $item[3]"
}

view_target_spec :

schema_qualification : NAME '.'

schema_name : NAME

field_name : NAME

covering_field_name : NAME

double_quote: /"/

index_name : NAME

array_indicator : '[' ']'
    { $return = $item[1].$item[2] }

data_type : pg_data_type parens_value_list(?) array_indicator(?)
    {
        my $data_type = $item[1];

        $data_type->{type} .= $item[3][0] if $item[3][0];

        #
        # We can deduce some sizes from the data type's name.
        #
        if ( my @size = @{$item[2]} ) {
            $data_type->{'size'} = (@size == 1 ? $size[0] : \@size);
        }

        $return  = $data_type;
    }

pg_data_type :
    /(bigint|int8)/i
        {
            $return = {
                type => 'integer',
                size => 20,
            };
        }
    |
    /(smallint|int2)/i
        {
            $return = {
                type => 'integer',
                size => 5,
            };
        }
    |
    /interval/i
        {
            $return = { type => 'interval' };
        }
    |
    /(integer|int4?)/i # interval must come before this
        {
            $return = {
                type => 'integer',
                size => 10,
            };
        }
    |
    /(real|float4)/i
        {
            $return = {
                type => 'real',
                size => 10,
            };
        }
    |
    /(double precision|float8?)/i
        {
            $return = {
                type => 'float',
                size => 20,
            };
        }
    |
    /(bigserial|serial8)/i
        {
            $return = {
                type              => 'integer',
                size              => 20,
                is_auto_increment => 1,
            };
        }
    |
    /serial4?/i
        {
            $return = {
                type              => 'integer',
                size              => 11,
                is_auto_increment => 1,
            };
        }
    |
    /(bit varying|varbit)/i
        {
            $return = { type => 'varbit' };
        }
    |
    /character varying/i
        {
            $return = { type => 'varchar' };
        }
    |
    /char(acter)?/i
        {
            $return = { type => 'char' };
        }
    |
    /bool(ean)?/i
        {
            $return = { type => 'boolean' };
        }
    |
    /bytea/i
        {
            $return = { type => 'bytea' };
        }
    |
    / ( timestamp (?:tz)? ) (?: \( \d \) )? ( \s with (?:out)? \s time \s zone )? /ix
        {
            $return = { type => 'timestamp' . ($2||'') };
        }
    |
    / ( time (?:tz)? ) (?: \( \d \) )? ( \s with (?:out)? \s time \s zone )? /ix
        {
            $return = { type => 'time' . ($2||'') };
        }
    |
    /text/i
        {
            $return = {
                type => 'text',
                size => 64_000,
            };
        }
    |
    /(bit|box|cidr|circle|date|inet|line|lseg|macaddr|money|numeric|decimal|path|point|polygon|varchar|json|hstore|uuid)/i
        {
            $return = { type => $item[1] };
        }

parens_value_list : '(' VALUE(s /,/) ')'
    { $item[2] }


parens_word_list : '(' NAME(s /,/) ')'
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
        my $expr_constraint = $type eq 'check' || $type eq 'exclude';

        $return              =  {
            name             => $item[2][0] || '',
            supertype        => 'constraint',
            type             => $type,
            fields           => $expr_constraint ? [] : $fields,
            expression       => $expr_constraint ? $expression : '',
            deferrable       => $item{'deferrable'},
            deferred         => $item{'deferred'},
            on_delete        => $desc->{'on_delete'} || $desc->{'on_delete_do'},
            on_update        => $desc->{'on_update'} || $desc->{'on_update_do'},
            comments         => [ @comments ],
            %{$desc}{qw/include using where reference_table reference_fields match_type/}
        }
    }

table_constraint_type : /primary key/i '(' NAME(s /,/) ')' include_covering(?)
    {
        $return = {
            type   => 'primary_key',
            fields => $item[3],
            include => $item{'include_convering(?)'}[0],
        }
    }
    |
    /unique/i '(' NAME(s /,/) ')' include_covering(?)
    {
        $return    =  {
            type   => 'unique',
            fields => $item[3],
            include => $item{'include_convering(?)'}[0],
        }
    }
    |
    /check/i '(' /[^)]+/ ')'
    {
        $return        =  {
            type       => 'check',
            expression => $item[3],
        }
    }
    |
    /exclude/i using_method(?) '(' /[^)]+/ ')' include_covering(?) where_paren_predicate(?) {
        $return        = {
            type       => 'exclude',
            expression => $item{__PATTERN2__},
            using      => $item{'using_method(?)'}[0],
            include    => $item{'include_convering(?)'}[0],
            where      => $item{'where_paren_predicate(?)'}[0],
        }
    }
    |
    /foreign key/i '(' NAME(s /,/) ')' /references/i table_id parens_word_list(?) match_type(?) key_action(s?)
    {
        my ( $on_delete, $on_update );
        for my $action ( @{ $item[9] || [] } ) {
            $on_delete = $action->{'action'} if $action->{'type'} eq 'delete';
            $on_update = $action->{'action'} if $action->{'type'} eq 'update';
        }

        $return              =  {
            supertype        => 'constraint',
            type             => 'foreign_key',
            fields           => $item[3],
            reference_table  => $item[6]->{'table_name'},
            reference_fields => $item[7][0],
            match_type       => $item[8][0],
            on_delete     => $on_delete || '',
            on_update     => $on_update || '',
        }
    }

deferrable : not(?) /deferrable/i
    {
        $return = ( $item[1] =~ /not/i ) ? 0 : 1;
    }

deferred : /initially/i /(deferred|immediate)/i { $item[2] }

match_type : /match/i /partial|full|simple/i { $item[2] }

key_action : key_delete
    |
    key_update

key_delete : /on delete/i key_mutation
    {
        $return = {
            type   => 'delete',
            action => $item[2],
        };
    }

key_update : /on update/i key_mutation
    {
        $return = {
            type   => 'update',
            action => $item[2],
        };
    }

key_mutation : /no action/i { $return = 'no_action' }
    |
    /restrict/i { $return = 'restrict' }
    |
    /cascade/i { $return = 'cascade' }
    |
    /set null/i { $return = 'set null' }
    |
    /set default/i { $return = 'set default' }

alter : alter_table table_id add_column field ';'
    {
        my $field_def = $item[4];
        $tables{ $item[2]->{'table_name'} }{'fields'}{ $field_def->{'name'} } = {
            %$field_def, order => $field_order++
        };
        1;
    }

alter : alter_table table_id ADD table_constraint ';'
    {
        my $table_name = $item[2]->{'table_name'};
        my $constraint = $item[4];
        push @{ $tables{ $table_name }{'constraints'} }, $constraint;
        1;
    }

alter : alter_table table_id drop_column NAME restrict_or_cascade(?) ';'
    {
        $tables{ $item[2]->{'table_name'} }{'fields'}{ $item[4] }{'drop'} = 1;
        1;
    }

alter : alter_table table_id alter_column NAME alter_default_val ';'
    {
        $tables{ $item[2]->{'table_name'} }{'fields'}{ $item[4] }{'default'} =
            $item[5]->{'value'};
        1;
    }

#
# These will just parse for now but won't affect the structure. - ky
#
alter : alter_table table_id /rename/i /to/i NAME ';'
    { 1 }

alter : alter_table table_id alter_column NAME SET /statistics/i INTEGER ';'
    { 1 }

alter : alter_table table_id alter_column NAME SET /storage/i storage_type ';'
    { 1 }

alter : alter_table table_id rename_column NAME /to/i NAME ';'
    { 1 }

alter : alter_table table_id DROP /constraint/i NAME restrict_or_cascade ';'
    { 1 }

alter : alter_table table_id /owner/i /to/i NAME ';'
    { 1 }

alter : alter_sequence NAME /owned/i /by/i column_name ';'
    { 1 }

storage_type : /(plain|external|extended|main)/i

temporary : /temp(orary)?\b/i
  {
    1;
  }

or_replace : /or replace/i

alter_default_val : SET default_val
    {
        $return = { value => $item[2]->{'value'} }
    }
    | DROP DEFAULT
    {
        $return = { value => undef }
    }

#
# This is a little tricky to get right, at least WRT to making the
# tests pass.  The problem is that the constraints are stored just as
# a list (no name access), and the tests expect the constraints in a
# particular order.  I'm going to leave the rule but disable the code
# for now. - ky
#
alter : alter_table table_id alter_column NAME alter_nullable ';'
    {
#        my $table_name  = $item[2]->{'table_name'};
#        my $field_name  = $item[4];
#        my $is_nullable = $item[5]->{'is_nullable'};
#
#        $tables{ $table_name }{'fields'}{ $field_name }{'is_nullable'} =
#            $is_nullable;
#
#        if ( $is_nullable ) {
#            1;
#            push @{ $tables{ $table_name }{'constraints'} }, {
#                type   => 'not_null',
#                fields => [ $field_name ],
#            };
#        }
#        else {
#            for my $i (
#                0 .. $#{ $tables{ $table_name }{'constraints'} || [] }
#            ) {
#                my $c = $tables{ $table_name }{'constraints'}[ $i ] or next;
#                my $fields = join( '', @{ $c->{'fields'} || [] } ) or next;
#                if ( $c->{'type'} eq 'not_null' && $fields eq $field_name ) {
#                    delete $tables{ $table_name }{'constraints'}[ $i ];
#                    last;
#                }
#            }
#        }

        1;
    }

alter_nullable : SET not_null
    {
        $return = { is_nullable => 0 }
    }
    | DROP not_null
    {
        $return = { is_nullable => 1 }
    }

not_null : /not/i /null/i

not : /not/i

add_column : ADD COLUMN(?)

alter_table : ALTER TABLE ONLY(?)

alter_sequence : ALTER SEQUENCE

drop_column : DROP COLUMN(?)

alter_column : ALTER COLUMN(?)

rename_column : /rename/i COLUMN(?)

restrict_or_cascade : /restrict/i |
    /cascade/i

# Handle functions that can be called
select : SELECT select_function ';'
    { 1 }

# Read the setval function but don't do anything with it because this parser
# isn't handling sequences
select_function : schema_qualification(?) /setval/i '(' VALUE /,/ VALUE /,/ /(true|false)/i ')'
    { 1 }

# Skipping all COPY commands
copy : COPY WORD /[^;]+/ ';' { 1 }
    { 1 }

# The "\." allows reading in from STDIN but this isn't needed for schema
# creation, so it is skipped.
readin_symbol : '\.'
    {1}

#
# End basically useless stuff. - ky
#

create_table : CREATE TABLE

create_index : CREATE /index/i

default_val  : DEFAULT DEFAULT_VALUE ( '::' data_type )(?)
    {
        my $val =  $item[2];
        $val =~ s/^\((\d+)\)\z/$1/; # for example (0)::smallint
        $return =  {
            supertype => 'constraint',
            type      => 'default',
            value     => $val,
        }
    }
    | /null/i
    {
        $return =  {
            supertype => 'constraint',
            type      => 'default',
            value     => 'NULL',
        }
    }

DEFAULT_VALUE : VALUE
    | /\w+\(.*\)/
    | /\w+/
    | /\(\d+\)/

name_with_opt_paren : NAME parens_value_list(s?)
    { $item[2][0] ? "$item[1]($item[2][0][0])" : $item[1] }

unique : /unique/i { 1 }

key : /key/i | /index/i

table_option : /inherits/i '(' NAME(s /,/) ')'
    {
        $return = { type => 'inherits', table_name => $item[3] }
    }
    |
    /with(out)? oids/i
    {
        $return = { type => $item[1] =~ /out/i ? 'without_oids' : 'with_oids' }
    }

ADD : /add/i

ALTER : /alter/i

CREATE : /create/i

ONLY : /only/i

DEFAULT : /default/i

DROP : /drop/i

COLUMN : /column/i

TABLE : /table/i

VIEW : /view/i

SCHEMA : /schema/i

SEMICOLON : /\s*;\n?/

SEQUENCE : /sequence/i

SELECT : /select/i

COPY : /copy/i

INTEGER : /\d+/

WORD : /\w+/

DIGITS : /\d+/

COMMA : ','

SET : /set/i

NAME : DQSTRING
    | /\w+/

DQSTRING : '"' <skip: ''> /((?:[^"]|"")+)/ '"'
    { ($return = $item[3]) =~ s/""/"/g; }

SQSTRING : "'" <skip: ''> /((?:[^']|'')*)/ "'"
    { ($return = $item[3]) =~ s/''/'/g }

DOLLARSTRING : /\$[^\$]*\$/ <skip: ''> /.*?(?=\Q$item[1]\E)/s "$item[1]"
    { $return = $item[3]; }

VALUE : /[-+]?\d*\.?\d+(?:[eE]\d+)?/
    | SQSTRING
    | DOLLARSTRING
    | /null/i
    { 'NULL' }

END_OF_GRAMMAR

sub parse {
  my ($translator, $data) = @_;

  # Enable warnings within the Parse::RecDescent module.
  local $::RD_ERRORS = 1
      unless defined $::RD_ERRORS;    # Make sure the parser dies when it encounters an error
  local $::RD_WARN = 1
      unless defined $::RD_WARN;      # Enable warnings. This will warn on unused rules &c.
  local $::RD_HINT = 1
      unless defined $::RD_HINT;      # Give out hints to help fix problems.

  local $::RD_TRACE = $translator->trace ? 1 : undef;
  local $DEBUG      = $translator->debug;

  my $parser = ddl_parser_instance('PostgreSQL');

  my $result = $parser->startrule($data);
  die "Parse failed.\n" unless defined $result;
  warn Dumper($result) if $DEBUG;

  my $schema = $translator->schema;
  my @tables = sort { ($result->{tables}{$a}{'order'} || 0) <=> ($result->{tables}{$b}{'order'} || 0) }
      keys %{ $result->{tables} };

  for my $table_name (@tables) {
    my $tdata = $result->{tables}{$table_name};
    my $table = $schema->add_table(

      #schema => $tdata->{'schema_name'},
      name => $tdata->{'table_name'},
    ) or die "Couldn't create table '$table_name': " . $schema->error;

    $table->extra(temporary => 1) if $tdata->{'temporary'};

    $table->comments($tdata->{'comments'});

    my @fields
        = sort { $tdata->{'fields'}{$a}{'order'} <=> $tdata->{'fields'}{$b}{'order'} } keys %{ $tdata->{'fields'} };

    for my $fname (@fields) {
      my $fdata = $tdata->{'fields'}{$fname};
      next if $fdata->{'drop'};
      my $field = $table->add_field(
        name              => $fdata->{'name'},
        data_type         => $fdata->{'data_type'},
        size              => $fdata->{'size'},
        default_value     => $fdata->{'default'},
        is_auto_increment => $fdata->{'is_auto_increment'},
        is_nullable       => $fdata->{'is_nullable'},
        comments          => $fdata->{'comments'},
      ) or die $table->error;

      $table->primary_key($field->name) if $fdata->{'is_primary_key'};

      for my $cdata (@{ $fdata->{'constraints'} }) {
        next unless $cdata->{'type'} eq 'foreign_key';
        $cdata->{'fields'} ||= [ $field->name ];
        push @{ $tdata->{'constraints'} }, $cdata;
      }
    }

    for my $idata (@{ $tdata->{'indices'} || [] }) {
      my @options = ();
      push @options, { using   => $idata->{'method'} } if $idata->{method};
      push @options, { where   => $idata->{'where'} }  if $idata->{where};
      push @options, { include => $idata->{'include'} }
          if $idata->{include};
      my $index = $table->add_index(
        name    => $idata->{'name'},
        type    => uc $idata->{'type'},
        fields  => $idata->{'fields'},
        options => \@options
      ) or die $table->error . ' ' . $table->name;
    }

    for my $cdata (@{ $tdata->{'constraints'} || [] }) {
      my $options = [

        # load this up with the extras
        map +{ %$cdata{$_} }, grep $cdata->{$_},
        qw/include using where/
      ];
      my $constraint = $table->add_constraint(
        name             => $cdata->{'name'},
        type             => $cdata->{'type'},
        fields           => $cdata->{'fields'},
        reference_table  => $cdata->{'reference_table'},
        reference_fields => $cdata->{'reference_fields'},
        match_type       => $cdata->{'match_type'} || '',
        on_delete        => $cdata->{'on_delete'}  || $cdata->{'on_delete_do'},
        on_update        => $cdata->{'on_update'}  || $cdata->{'on_update_do'},
        expression       => $cdata->{'expression'},
        options          => $options
          )
          or die "Can't add constraint of type '"
          . $cdata->{'type'}
          . "' to table '"
          . $table->name . "': "
          . $table->error;
    }
  }

  for my $vinfo (@{ $result->{views} }) {
    my $sql = $vinfo->{sql};
    $sql =~ s/\A\s+|\s+\z//g;
    my $view = $schema->add_view(
      name   => $vinfo->{view_name},
      sql    => $sql,
      fields => $vinfo->{fields},
    );

    $view->extra(temporary => 1) if $vinfo->{is_temporary};
  }

  for my $trigger (@{ $result->{triggers} }) {
    $schema->add_trigger(%$trigger);
  }

  return 1;
}

1;

# -------------------------------------------------------------------
# Rescue the drowning and tie your shoestrings.
# Henry David Thoreau
# -------------------------------------------------------------------

=pod

=head1 AUTHORS

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>,
Allen Day E<lt>allenday@ucla.eduE<gt>.

=head1 SEE ALSO

perl(1), Parse::RecDescent.

=cut
