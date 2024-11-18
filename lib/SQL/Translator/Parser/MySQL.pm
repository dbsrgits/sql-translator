package SQL::Translator::Parser::MySQL;

=head1 NAME

SQL::Translator::Parser::MySQL - parser for MySQL

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::MySQL;

  my $translator = SQL::Translator->new;
  $translator->parser("SQL::Translator::Parser::MySQL");

=head1 DESCRIPTION

The grammar is influenced heavily by Tim Bunce's "mysql2ora" grammar.

Here's the word from the MySQL site
(http://www.mysql.com/doc/en/CREATE_TABLE.html):

  CREATE [TEMPORARY] TABLE [IF NOT EXISTS] tbl_name [(create_definition,...)]
  [table_options] [select_statement]

  or

  CREATE [TEMPORARY] TABLE [IF NOT EXISTS] tbl_name LIKE old_table_name;

  create_definition:
    col_name type [NOT NULL | NULL] [DEFAULT default_value] [AUTO_INCREMENT]
              [PRIMARY KEY] [reference_definition]
    or    PRIMARY KEY (index_col_name,...)
    or    KEY [index_name] (index_col_name,...)
    or    INDEX [index_name] (index_col_name,...)
    or    UNIQUE [INDEX] [index_name] (index_col_name,...)
    or    FULLTEXT [INDEX] [index_name] (index_col_name,...)
    or    [CONSTRAINT symbol] FOREIGN KEY [index_name] (index_col_name,...)
              [reference_definition]
    or    CHECK (expr)

  type:
          TINYINT[(length)] [UNSIGNED] [ZEROFILL]
    or    SMALLINT[(length)] [UNSIGNED] [ZEROFILL]
    or    MEDIUMINT[(length)] [UNSIGNED] [ZEROFILL]
    or    INT[(length)] [UNSIGNED] [ZEROFILL]
    or    INTEGER[(length)] [UNSIGNED] [ZEROFILL]
    or    BIGINT[(length)] [UNSIGNED] [ZEROFILL]
    or    REAL[(length,decimals)] [UNSIGNED] [ZEROFILL]
    or    DOUBLE[(length,decimals)] [UNSIGNED] [ZEROFILL]
    or    FLOAT[(length,decimals)] [UNSIGNED] [ZEROFILL]
    or    DECIMAL(length,decimals) [UNSIGNED] [ZEROFILL]
    or    NUMERIC(length,decimals) [UNSIGNED] [ZEROFILL]
    or    CHAR(length) [BINARY]
    or    VARCHAR(length) [BINARY]
    or    DATE
    or    TIME
    or    TIMESTAMP
    or    DATETIME
    or    TINYBLOB
    or    BLOB
    or    MEDIUMBLOB
    or    LONGBLOB
    or    TINYTEXT
    or    TEXT
    or    MEDIUMTEXT
    or    LONGTEXT
    or    ENUM(value1,value2,value3,...)
    or    SET(value1,value2,value3,...)

  index_col_name:
          col_name [(length)]

  reference_definition:
          REFERENCES tbl_name [(index_col_name,...)]
                     [MATCH FULL | MATCH PARTIAL]
                     [ON DELETE reference_option]
                     [ON UPDATE reference_option]

  reference_option:
          RESTRICT | CASCADE | SET NULL | NO ACTION | SET DEFAULT

  table_options:
          TYPE = {BDB | HEAP | ISAM | InnoDB | MERGE | MRG_MYISAM | MYISAM }
  or      ENGINE = {BDB | HEAP | ISAM | InnoDB | MERGE | MRG_MYISAM | MYISAM }
  or      AUTO_INCREMENT = #
  or      AVG_ROW_LENGTH = #
  or      [ DEFAULT ] CHARACTER SET charset_name
  or      CHECKSUM = {0 | 1}
  or      COLLATE collation_name
  or      COMMENT = "string"
  or      MAX_ROWS = #
  or      MIN_ROWS = #
  or      PACK_KEYS = {0 | 1 | DEFAULT}
  or      PASSWORD = "string"
  or      DELAY_KEY_WRITE = {0 | 1}
  or      ROW_FORMAT= { default | dynamic | fixed | compressed }
  or      RAID_TYPE= {1 | STRIPED | RAID0 } RAID_CHUNKS=#  RAID_CHUNKSIZE=#
  or      UNION = (table_name,[table_name...])
  or      INSERT_METHOD= {NO | FIRST | LAST }
  or      DATA DIRECTORY="absolute path to directory"
  or      INDEX DIRECTORY="absolute path to directory"


A subset of the ALTER TABLE syntax that allows addition of foreign keys:

  ALTER [IGNORE] TABLE tbl_name alter_specification [, alter_specification] ...

  alter_specification:
          ADD [CONSTRAINT [symbol]]
          FOREIGN KEY [index_name] (index_col_name,...)
             [reference_definition]

A subset of INSERT that we ignore:

  INSERT anything

=head1 ARGUMENTS

This parser takes a single optional parser_arg C<mysql_parser_version>, which
provides the desired version for the target database. Any statement in the processed
dump file, that is commented with a version higher than the one supplied, will be stripped.

The default C<mysql_parser_version> is set to the conservative value of 40000 (MySQL 4.0)

Valid version specifiers for C<mysql_parser_version> are listed L<here|SQL::Translator::Utils/parse_mysql_version>

More information about the MySQL comment-syntax: L<http://dev.mysql.com/doc/refman/5.0/en/comments.html>


=cut

use strict;
use warnings;

our $VERSION = '1.66';

our $DEBUG;
$DEBUG = 0 unless defined $DEBUG;

use Data::Dumper;
use Storable               qw(dclone);
use DBI                    qw(:sql_types);
use SQL::Translator::Utils qw/parse_mysql_version ddl_parser_instance/;

use base qw(Exporter);
our @EXPORT_OK = qw(parse);

our %type_mapping = ();

use constant DEFAULT_PARSER_VERSION => 40000;

our $GRAMMAR = << 'END_OF_GRAMMAR';

{
    my ( $database_name, %tables, $table_order, @table_comments, %views,
        $view_order, %procedures, $proc_order );
    my $delimiter = ';';
}

#
# The "eofile" rule makes the parser fail if any "statement" rule
# fails.  Otherwise, the first successful match by a "statement"
# won't cause the failure needed to know that the parse, as a whole,
# failed. -ky
#
startrule : statement(s) eofile {
    {
        database_name => $database_name,
        tables        => \%tables,
        views         => \%views,
        procedures    => \%procedures,
    }
}

eofile : /^\Z/

statement : comment
    | use
    | set
    | drop
    | create
    | alter
    | insert
    | delimiter
    | empty_statement
    | <error>

use : /use/i NAME "$delimiter"
    {
        $database_name = $item[2];
        @table_comments = ();
    }

set : /set/i not_delimiter "$delimiter"
    { @table_comments = () }

drop : /drop/i TABLE not_delimiter "$delimiter"

drop : /drop/i NAME(s) "$delimiter"
    { @table_comments = () }

bit:
    /(b'[01]{1,64}')/ |
    /(b"[01]{1,64}")/

string :
  # MySQL strings, unlike common SQL strings, can be double-quoted or
  # single-quoted.

  SQSTRING | DQSTRING

nonstring : /[^;\'"]+/

statement_body : string | nonstring

insert : /insert/i  statement_body(s?) "$delimiter"

delimiter : /delimiter/i /[\S]+/
    { $delimiter = $item[2] }

empty_statement : "$delimiter"

alter : ALTER TABLE table_name alter_specification(s /,/) "$delimiter"
    {
        my $table_name                       = $item{'table_name'};
    die "Cannot ALTER table '$table_name'; it does not exist"
        unless $tables{ $table_name };
        for my $definition ( @{ $item[4] } ) {
        $definition->{'extra'}->{'alter'} = 1;
        push @{ $tables{ $table_name }{'constraints'} }, $definition;
    }
    }

alter_specification : ADD foreign_key_def
    { $return = $item[2] }

create : CREATE /database/i NAME "$delimiter"
    { @table_comments = () }

create : CREATE TEMPORARY(?) TABLE opt_if_not_exists(?) table_name '(' create_definition(s /,/) /(,\s*)?\)/ table_option(s?) "$delimiter"
    {
        my $table_name                       = $item{'table_name'};
        die "There is more than one definition for $table_name"
            if ($tables{$table_name});

        $tables{ $table_name }{'order'}      = ++$table_order;
        $tables{ $table_name }{'table_name'} = $table_name;

        if ( @table_comments ) {
            $tables{ $table_name }{'comments'} = [ @table_comments ];
            @table_comments = ();
        }

        my $i = 1;
        for my $definition ( @{ $item[7] } ) {
            if ( $definition->{'supertype'} eq 'field' ) {
                my $field_name = $definition->{'name'};
                $tables{ $table_name }{'fields'}{ $field_name } =
                    { %$definition, order => $i };
                $i++;

                if ( $definition->{'is_primary_key'} ) {
                    push @{ $tables{ $table_name }{'constraints'} },
                        {
                            type   => 'primary_key',
                            fields => [ $field_name ],
                        }
                    ;
                }
            }
            elsif ( $definition->{'supertype'} eq 'constraint' ) {
                push @{ $tables{ $table_name }{'constraints'} }, $definition;
            }
            elsif ( $definition->{'supertype'} eq 'index' ) {
                push @{ $tables{ $table_name }{'indices'} }, $definition;
            }
        }

        if ( my @options = @{ $item{'table_option(s?)'} } ) {
            for my $option ( @options ) {
                my ( $key, $value ) = each %$option;
                if ( $key eq 'comment' ) {
                    push @{ $tables{ $table_name }{'comments'} }, $value;
                }
                else {
                    push @{ $tables{ $table_name }{'table_options'} }, $option;
                }
            }
        }

        1;
    }

opt_if_not_exists : /if not exists/i

create : CREATE UNIQUE(?) /(index|key)/i index_name /on/i table_name '(' field_name(s /,/) ')' "$delimiter"
    {
        @table_comments = ();
        push @{ $tables{ $item{'table_name'} }{'indices'} },
            {
                name   => $item[4],
                type   => $item[2][0] ? 'unique' : 'normal',
                fields => $item[8],
            }
        ;
    }

create : CREATE /trigger/i NAME not_delimiter "$delimiter"
    {
        @table_comments = ();
    }

create : CREATE PROCEDURE NAME not_delimiter "$delimiter"
    {
        @table_comments = ();
        my $func_name = $item[3];
        my $owner = '';
        my $sql = "$item[1] $item[2] $item[3] $item[4]";

        $procedures{ $func_name }{'order'}  = ++$proc_order;
        $procedures{ $func_name }{'name'}   = $func_name;
        $procedures{ $func_name }{'owner'}  = $owner;
        $procedures{ $func_name }{'sql'}    = $sql;
    }

PROCEDURE : /procedure/i
    | /function/i

create : CREATE or_replace(?) create_view_option(s?) /view/i NAME /as/i view_select_statement "$delimiter"
    {
        @table_comments = ();
        my $view_name   = $item{'NAME'};
        my $select_sql  = $item{'view_select_statement'};
        my $options     = $item{'create_view_option(s?)'};

        my $sql = join(q{ },
            grep { defined and length }
            map  { ref $_ eq 'ARRAY' ? @$_ : $_ }
            $item{'CREATE'},
            $item{'or_replace(?)'},
            $options,
            $view_name,
            'as select',
            join(', ',
                map {
                    sprintf('%s%s',
                        $_->{'name'},
                        $_->{'alias'} ? ' as ' . $_->{'alias'} : ''
                    )
                }
                @{ $select_sql->{'columns'} || [] }
            ),
            ' from ',
            join(', ',
                map {
                    sprintf('%s%s',
                        $_->{'name'},
                        $_->{'alias'} ? ' as ' . $_->{'alias'} : ''
                    )
                }
                @{ $select_sql->{'from'}{'tables'} || [] }
            ),
            $select_sql->{'from'}{'where'}
                ? 'where ' . $select_sql->{'from'}{'where'}
                : ''
            ,
        );

        # Hack to strip database from function calls in SQL
        $sql =~ s#`\w+`\.(`\w+`\()##g;

        $views{ $view_name }{'order'}   = ++$view_order;
        $views{ $view_name }{'name'}    = $view_name;
        $views{ $view_name }{'sql'}     = $sql;
        $views{ $view_name }{'options'} = $options;
        $views{ $view_name }{'select'}  = $item{'view_select_statement'};
    }

create_view_option : view_algorithm | view_sql_security | view_definer

or_replace : /or replace/i

view_algorithm : /algorithm/i /=/ WORD
    {
        $return = "$item[1]=$item[3]";
    }

view_definer : /definer=\S+/i

view_sql_security : /sql \s+ security  \s+ (definer|invoker)/ixs

not_delimiter : /.*?(?=$delimiter)/is

view_select_statement : /[(]?/ /select/i view_column_def /from/i view_table_def /[)]?/
    {
        $return = {
            columns => $item{'view_column_def'},
            from    => $item{'view_table_def'},
        };
    }

view_column_def : /(.*?)(?=\bfrom\b)/ixs
    {
        # split on commas not in parens,
        # e.g., "concat_ws(\' \', first, last) as first_last"
        my @tmp = $1 =~ /((?:[^(,]+|\(.*?\))+)/g;
        my @cols;
        for my $col ( @tmp ) {
            my ( $name, $alias ) = map {
              s/^\s+|\s+$//g;
              s/[`]//g;
              $_
            } split /\s+as\s+/i, $col;

            push @cols, { name => $name, alias => $alias || '' };
        }

        $return = \@cols;
    }

not_delimiter : /.*?(?=$delimiter)/is

view_table_def : not_delimiter
    {
        my $clause = $item[1];
        my $where  = $1 if $clause =~ s/\bwhere \s+ (.*)//ixs;
        $clause    =~ s/[)]\s*$//;

        my @tables;
        for my $tbl ( split( /\s*,\s*/, $clause ) ) {
            my ( $name, $alias ) = split /\s+as\s+/i, $tbl;
            push @tables, { name => $name, alias => $alias || '' };
        }

        $return = {
            tables => \@tables,
            where  => $where || '',
        };
    }

view_column_alias : /as/i NAME
    { $return = $item[2] }

create_definition : constraint
    | index
    | field
    | comment
    | <error>

comment : /^\s*(?:#|-{2}).*\n/
    {
        my $comment =  $item[1];
        $comment    =~ s/^\s*(#|--)\s*//;
        $comment    =~ s/\s*$//;
        $return     = $comment;
    }

comment : m{ / \* (?! \!) .*? \* / }xs
    {
        my $comment = $item[2];
        $comment = substr($comment, 0, -2);
        $comment    =~ s/^\s*|\s*$//g;
        $return = $comment;
    }

comment_like_command : m{/\*!(\d+)?}s

comment_end : m{ \* / }xs

field_comment : /^\s*(?:#|-{2}).*\n/
    {
        my $comment =  $item[1];
        $comment    =~ s/^\s*(#|--)\s*//;
        $comment    =~ s/\s*$//;
        $return     = $comment;
    }


blank : /\s*/

field : field_comment(s?) field_name data_type field_qualifier(s?) reference_definition(?) on_update(?) field_comment(s?)
    {
        my %qualifiers  = map { %$_ } @{ $item{'field_qualifier(s?)'} || [] };
        if ( my @type_quals = @{ $item{'data_type'}{'qualifiers'} || [] } ) {
            $qualifiers{ $_ } = 1 for @type_quals;
        }

        my $null = defined $qualifiers{'not_null'}
                   ? $qualifiers{'not_null'} : 1;
        delete $qualifiers{'not_null'};

        my @comments = ( @{ $item[1] }, (exists $qualifiers{comment} ? delete $qualifiers{comment} : ()) , @{ $item[7] } );

        $return = {
            supertype   => 'field',
            name        => $item{'field_name'},
            data_type   => $item{'data_type'}{'type'},
            size        => $item{'data_type'}{'size'},
            list        => $item{'data_type'}{'list'},
            null        => $null,
            constraints => $item{'reference_definition(?)'},
            comments    => [ @comments ],
            %qualifiers,
        }
    }
    | <error>

field_qualifier : not_null
    {
        $return = {
             null => $item{'not_null'},
        }
    }

field_qualifier : default_val
    {
        $return = {
             default => $item{'default_val'},
        }
    }

field_qualifier : auto_inc
    {
        $return = {
             is_auto_inc => $item{'auto_inc'},
        }
    }

field_qualifier : primary_key
    {
        $return = {
             is_primary_key => $item{'primary_key'},
        }
    }

field_qualifier : unsigned
    {
        $return = {
             is_unsigned => $item{'unsigned'},
        }
    }

field_qualifier : /character set/i WORD
    {
        $return = {
            'CHARACTER SET' => $item[2],
        }
    }

field_qualifier : /collate/i WORD
    {
        $return = {
            COLLATE => $item[2],
        }
    }

field_qualifier : /on update/i CURRENT_TIMESTAMP
    {
        $return = {
            'ON UPDATE' => $item[2],
        }
    }

field_qualifier : /unique/i KEY(?)
    {
        $return = {
            is_unique => 1,
        }
    }

field_qualifier : KEY
    {
        $return = {
            has_index => 1,
        }
    }

field_qualifier : /comment/i string
    {
        $return = {
            comment => $item[2],
        }
    }

reference_definition : /references/i table_name parens_field_list(?) match_type(?) on_delete(?) on_update(?)
    {
        $return = {
            type             => 'foreign_key',
            reference_table  => $item[2],
            reference_fields => $item[3][0],
            match_type       => $item[4][0],
            on_delete        => $item[5][0],
            on_update        => $item[6][0],
        }
    }

match_type : /match full/i { 'full' }
    |
    /match partial/i { 'partial' }

on_delete : /on delete/i reference_option
    { $item[2] }

on_update :
    /on update/i CURRENT_TIMESTAMP
    { $item[2] }
    |
    /on update/i reference_option
    { $item[2] }

reference_option: /restrict/i |
    /cascade/i   |
    /set null/i  |
    /no action/i |
    /set default/i
    { $item[1] }

index : normal_index
    | fulltext_index
    | spatial_index
    | <error>

table_name   : NAME

field_name   : NAME

index_name   : NAME

data_type    : WORD parens_value_list(s?) type_qualifier(s?)
    {
        my $type = $item[1];
        my $size; # field size, applicable only to non-set fields
        my $list; # set list, applicable only to sets (duh)

        if ( uc($type) =~ /^(SET|ENUM)$/ ) {
            $size = undef;
            $list = $item[2][0];
        }
        else {
            $size = $item[2][0];
            $list = [];
        }


        $return        = {
            type       => $type,
            size       => $size,
            list       => $list,
            qualifiers => $item[3],
        }
    }

parens_field_list : '(' field_name(s /,/) ')'
    { $item[2] }

parens_value_list : '(' VALUE(s /,/) ')'
    { $item[2] }

type_qualifier : /(BINARY|UNSIGNED|ZEROFILL)/i
    { lc $item[1] }

field_type   : WORD

create_index : /create/i /index/i

not_null     : /not/i /null/i
    { $return = 0 }
    |
    /null/i
    { $return = 1 }

unsigned     : /unsigned/i { $return = 0 }

default_val :
    /default/i CURRENT_TIMESTAMP
    {
        $return =  $item[2];
    }
    |
    /default/i VALUE
    {
        $return  =  $item[2];
    }
    |
    /default/i bit
    {
        $item[2] =~ s/b['"]([01]+)['"]/$1/g;
        $return  =  $item[2];
    }
    |
    /default/i /[\w\d:.-]+/
    {
        $return  =  $item[2];
    }
    |
    /default/i NAME # column value, allowed in MariaDB
    {
        $return  =  $item[2];
    }

auto_inc : /auto_increment/i { 1 }

primary_key : /primary/i /key/i { 1 }

constraint : primary_key_def
    | unique_key_def
    | foreign_key_def
    | check_def
    | <error>

expr : /[^)]* \( [^)]+ \) [^)]*/x # parens, balanced one deep
    | /[^)]+/

check_def : check_def_begin '(' expr ')'
    {
        $return              =  {
            supertype        => 'constraint',
            type             => 'check',
            name             => $item[1],
            expression       => $item[3],
        }
    }

check_def_begin : /constraint/i /check/i NAME
    { $return = $item[3] }
    |
    /constraint/i NAME /check/i
    { $return = $item[2] }
    |
    /constraint/i /check/i
    { $return = '' }

foreign_key_def : foreign_key_def_begin parens_field_list reference_definition
    {
        $return              =  {
            supertype        => 'constraint',
            type             => 'foreign_key',
            name             => $item[1],
            fields           => $item[2],
            %{ $item{'reference_definition'} },
        }
    }

foreign_key_def_begin : /constraint/i /foreign key/i NAME
    { $return = $item[3] }
    |
    /constraint/i NAME /foreign key/i
    { $return = $item[2] }
    |
    /constraint/i /foreign key/i
    { $return = '' }
    |
    /foreign key/i NAME
    { $return = $item[2] }
    |
    /foreign key/i
    { $return = '' }

primary_key_def : primary_key index_type(?) '(' name_with_opt_paren(s /,/) ')' index_type(?)
    {
        $return       = {
            supertype => 'constraint',
            type      => 'primary_key',
            fields    => $item[4],
            options   => $item[2][0] || $item[6][0],
        };
    }
    # In theory, and according to the doc, names should not be allowed here, but
    # MySQL accept (and ignores) them, so we are not going to be less :)
    | primary_key index_name_not_using(?) '(' name_with_opt_paren(s /,/) ')' index_type(?)
    {
        $return       = {
            supertype => 'constraint',
            type      => 'primary_key',
            fields    => $item[4],
            options   => $item[6][0],
        };
    }

unique_key_def : UNIQUE KEY(?) index_name_not_using(?) index_type(?) '(' name_with_opt_paren(s /,/) ')' index_type(?)
    {
        $return       = {
            supertype => 'constraint',
            name      => $item[3][0],
            type      => 'unique',
            fields    => $item[6],
            options   => $item[4][0] || $item[8][0],
        }
    }

normal_index : KEY index_name_not_using(?) index_type(?) '(' name_with_opt_paren(s /,/) ')' index_type(?)
    {
        $return       = {
            supertype => 'index',
            type      => 'normal',
            name      => $item[2][0],
            fields    => $item[5],
            options   => $item[3][0] || $item[7][0],
        }
    }

index_name_not_using : QUOTED_NAME
    | /(\b(?!using)\w+\b)/ { $return = ($1 =~ /^using/i) ? undef : $1 }

index_type : /using (btree|hash|rtree)/i { $return = uc $1 }

fulltext_index : /fulltext/i KEY(?) index_name(?) '(' name_with_opt_paren(s /,/) ')'
    {
        $return       = {
            supertype => 'index',
            type      => 'fulltext',
            name      => $item{'index_name(?)'}[0],
            fields    => $item[5],
        }
    }

spatial_index : /spatial/i KEY(?) index_name(?) '(' name_with_opt_paren(s /,/) ')'
    {
        $return       = {
            supertype => 'index',
            type      => 'spatial',
            name      => $item{'index_name(?)'}[0],
            fields    => $item[5],
        }
    }

name_with_opt_paren : NAME parens_value_list(s?)
    { $item[2][0] ? "$item[1]($item[2][0][0])" : $item[1] }

UNIQUE : /unique/i

KEY : /key/i | /index/i

table_option : /comment/i /=/ string
    {
        $return     = { comment => $item[3] };
    }
    | /(default )?(charset|character set)/i /\s*=?\s*/ NAME
    {
        $return = { 'CHARACTER SET' => $item[3] };
    }
    | /collate/i NAME
    {
        $return = { 'COLLATE' => $item[2] }
    }
    | /union/i /\s*=\s*/ '(' table_name(s /,/) ')'
    {
        $return = { $item[1] => $item[4] };
    }
    | WORD /\s*=\s*/ table_option_value
    {
        $return = { $item[1] => $item[3] };
    }

table_option_value : VALUE
                   | NAME

default : /default/i

ADD : /add/i

ALTER : /alter/i

CREATE : /create/i

TEMPORARY : /temporary/i

TABLE : /table/i

WORD : /\w+/

DIGITS : /\d+/

COMMA : ','

BACKTICK : '`'

DOUBLE_QUOTE: '"'

SINGLE_QUOTE: "'"

QUOTED_NAME : BQSTRING
    | SQSTRING
    | DQSTRING

# MySQL strings, unlike common SQL strings, can have the delmiters
# escaped either by doubling or by backslashing.
BQSTRING: BACKTICK <skip: ''> /(?:[^\\`]|``|\\.)*/ BACKTICK
    { ($return = $item[3]) =~ s/(\\[\\`]|``)/substr($1,1)/ge }

DQSTRING: DOUBLE_QUOTE <skip: ''> /(?:[^\\"]|""|\\.)*/ DOUBLE_QUOTE
    { ($return = $item[3]) =~ s/(\\[\\"]|"")/substr($1,1)/ge }

SQSTRING: SINGLE_QUOTE <skip: ''> /(?:[^\\']|''|\\.)*/ SINGLE_QUOTE
    { ($return = $item[3]) =~ s/(\\[\\']|'')/substr($1,1)/ge }


NAME: QUOTED_NAME
    | /\w+/

VALUE : /[-+]?\d*\.?\d+(?:[eE]\d+)?/
    { $item[1] }
    | SQSTRING
    | DQSTRING
    | /NULL/i
    { 'NULL' }

# always a scalar-ref, so that it is treated as a function and not quoted by consumers
CURRENT_TIMESTAMP :
      /current_timestamp(\(\))?/i { \'CURRENT_TIMESTAMP' }
    | /now\(\)/i { \'CURRENT_TIMESTAMP' }

END_OF_GRAMMAR

sub parse {
  my ($translator, $data) = @_;

  # Enable warnings within the Parse::RecDescent module.
  # Make sure the parser dies when it encounters an error
  local $::RD_ERRORS = 1 unless defined $::RD_ERRORS;

  # Enable warnings. This will warn on unused rules &c.
  local $::RD_WARN = 1 unless defined $::RD_WARN;

  # Give out hints to help fix problems.
  local $::RD_HINT  = 1 unless defined $::RD_HINT;
  local $::RD_TRACE = $translator->trace ? 1 : undef;
  local $DEBUG      = $translator->debug;

  my $parser = ddl_parser_instance('MySQL');

  # Preprocess for MySQL-specific and not-before-version comments
  # from mysqldump
  my $parser_version = parse_mysql_version($translator->parser_args->{mysql_parser_version}, 'mysql')
      || DEFAULT_PARSER_VERSION;

  while ($data =~ s#/\*!(\d{5})?(.*?)\*/#($1 && $1 > $parser_version ? '' : $2)#es) {
    # do nothing; is there a better way to write this? -- ky
  }

  my $result = $parser->startrule($data);
  return $translator->error("Parse failed.") unless defined $result;
  warn "Parse result:" . Dumper($result) if $DEBUG;

  my $schema = $translator->schema;
  $schema->name($result->{'database_name'}) if $result->{'database_name'};

  my @tables
      = sort { $result->{'tables'}{$a}{'order'} <=> $result->{'tables'}{$b}{'order'} } keys %{ $result->{'tables'} };

  for my $table_name (@tables) {
    my $tdata = $result->{tables}{$table_name};
    my $table = $schema->add_table(name => $tdata->{'table_name'},)
        or die $schema->error;

    $table->comments($tdata->{'comments'});

    my @fields = sort { $tdata->{'fields'}->{$a}->{'order'} <=> $tdata->{'fields'}->{$b}->{'order'} }
        keys %{ $tdata->{'fields'} };

    for my $fname (@fields) {
      my $fdata = $tdata->{'fields'}{$fname};
      my $field = $table->add_field(
        name              => $fdata->{'name'},
        data_type         => $fdata->{'data_type'},
        size              => $fdata->{'size'},
        default_value     => $fdata->{'default'},
        is_auto_increment => $fdata->{'is_auto_inc'},
        is_nullable       => $fdata->{'null'},
        comments          => $fdata->{'comments'},
      ) or die $table->error;

      $table->primary_key($field->name) if $fdata->{'is_primary_key'};

      for my $qual (qw[ binary unsigned zerofill list collate ], 'character set', 'on update') {
        if (my $val = $fdata->{$qual} || $fdata->{ uc $qual }) {
          next if ref $val eq 'ARRAY' && !@$val;
          $field->extra($qual, $val);
        }
      }

      if ($fdata->{'has_index'}) {
        $table->add_index(
          name   => '',
          type   => 'NORMAL',
          fields => $fdata->{'name'},
        ) or die $table->error;
      }

      if ($fdata->{'is_unique'}) {
        $table->add_constraint(
          name   => '',
          type   => 'UNIQUE',
          fields => $fdata->{'name'},
        ) or die $table->error;
      }

      for my $cdata (@{ $fdata->{'constraints'} }) {
        next unless $cdata->{'type'} eq 'foreign_key';
        $cdata->{'fields'} ||= [ $field->name ];
        push @{ $tdata->{'constraints'} }, $cdata;
      }

    }

    for my $idata (@{ $tdata->{'indices'} || [] }) {
      my $index = $table->add_index(
        name   => $idata->{'name'},
        type   => uc $idata->{'type'},
        fields => $idata->{'fields'},
      ) or die $table->error;
    }

    if (my @options = @{ $tdata->{'table_options'} || [] }) {
      my @cleaned_options;
      my @ignore_opts
          = $translator->parser_args->{'ignore_opts'}
          ? split(/,/, $translator->parser_args->{'ignore_opts'})
          : ();
      if (@ignore_opts) {
        my $ignores = { map { $_ => 1 } @ignore_opts };
        foreach my $option (@options) {

          # make sure the option isn't in ignore list
          my ($option_key) = keys %$option;
          if (!exists $ignores->{$option_key}) {
            push @cleaned_options, $option;
          }
        }
      } else {
        @cleaned_options = @options;
      }
      $table->options(\@cleaned_options) or die $table->error;
    }

    for my $cdata (@{ $tdata->{'constraints'} || [] }) {
      my $constraint = $table->add_constraint(
        name             => $cdata->{'name'},
        type             => $cdata->{'type'},
        fields           => $cdata->{'fields'},
        expression       => $cdata->{'expression'},
        reference_table  => $cdata->{'reference_table'},
        reference_fields => $cdata->{'reference_fields'},
        match_type       => $cdata->{'match_type'} || '',
        on_delete        => $cdata->{'on_delete'}  || $cdata->{'on_delete_do'},
        on_update        => $cdata->{'on_update'}  || $cdata->{'on_update_do'},
      ) or die $table->error;
    }

    # After the constrains and PK/idxs have been created,
    # we normalize fields
    normalize_field($_) for $table->get_fields;
  }

  my @procedures = sort { $result->{procedures}->{$a}->{'order'} <=> $result->{procedures}->{$b}->{'order'} }
      keys %{ $result->{procedures} };

  for my $proc_name (@procedures) {
    $schema->add_procedure(
      name  => $proc_name,
      owner => $result->{procedures}->{$proc_name}->{owner},
      sql   => $result->{procedures}->{$proc_name}->{sql},
    );
  }

  my @views
      = sort { $result->{views}->{$a}->{'order'} <=> $result->{views}->{$b}->{'order'} } keys %{ $result->{views} };

  for my $view_name (@views) {
    my $view = $result->{'views'}{$view_name};
    my @flds = map { $_->{'alias'} || $_->{'name'} } @{ $view->{'select'}{'columns'} || [] };
    my @from = map { $_->{'alias'} || $_->{'name'} } @{ $view->{'from'}{'tables'}    || [] };

    $schema->add_view(
      name    => $view_name,
      sql     => $view->{'sql'},
      order   => $view->{'order'},
      fields  => \@flds,
      tables  => \@from,
      options => $view->{'options'}
    );
  }

  return 1;
}

# Takes a field, and returns
sub normalize_field {
  my ($field) = @_;
  my ($size, $type, $list, $unsigned, $changed);

  $size     = $field->size;
  $type     = $field->data_type;
  $list     = $field->extra->{list} || [];
  $unsigned = defined($field->extra->{unsigned});

  if (!ref $size && $size eq 0) {
    if (lc $type eq 'tinyint') {
      $changed = $size != 4 - $unsigned;
      $size    = 4 - $unsigned;
    } elsif (lc $type eq 'smallint') {
      $changed = $size != 6 - $unsigned;
      $size    = 6 - $unsigned;
    } elsif (lc $type eq 'mediumint') {
      $changed = $size != 9 - $unsigned;
      $size    = 9 - $unsigned;
    } elsif ($type =~ /^int(eger)?$/i) {
      $changed = $size != 11 - $unsigned || $type ne 'int';
      $type    = 'int';
      $size    = 11 - $unsigned;
    } elsif (lc $type eq 'bigint') {
      $changed = $size != 20;
      $size    = 20;
    } elsif (lc $type =~ /(float|double|decimal|numeric|real|fixed|dec)/) {
      my $old_size = (ref $size || '') eq 'ARRAY' ? $size : [];
      $changed
          = @$old_size != 2
          || $old_size->[0] != 8
          || $old_size->[1] != 2;
      $size = [ 8, 2 ];
    }
  }

  if ($type =~ /^tiny(text|blob)$/i) {
    $changed = $size != 255;
    $size    = 255;
  } elsif ($type =~ /^(blob|text)$/i) {
    $changed = $size != 65_535;
    $size    = 65_535;
  } elsif ($type =~ /^medium(blob|text)$/i) {
    $changed = $size != 16_777_215;
    $size    = 16_777_215;
  } elsif ($type =~ /^long(blob|text)$/i) {
    $changed = $size != 4_294_967_295;
    $size    = 4_294_967_295;
  }

  if ($field->data_type =~ /(set|enum)/i && !$field->size) {
    my %extra   = $field->extra;
    my $longest = 0;
    for my $len (map {length} @{ $extra{'list'} || [] }) {
      $longest = $len if $len > $longest;
    }
    $changed = 1;
    $size    = $longest if $longest;
  }

  if ($changed) {

    # We only want to clone the field, not *everything*
    {
      local $field->{table} = undef;
      $field->parsed_field(dclone($field));
      $field->parsed_field->{table} = $field->table;
    }
    $field->size($size);
    $field->data_type($type);
    $field->sql_data_type($type_mapping{ lc $type })
        if exists $type_mapping{ lc $type };
    $field->extra->{list} = $list if @$list;
  }
}

1;

# -------------------------------------------------------------------
# Where man is not nature is barren.
# William Blake
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>,
Chris Mungall E<lt>cjm@fruitfly.orgE<gt>.

=head1 SEE ALSO

Parse::RecDescent, SQL::Translator::Schema.

=cut
