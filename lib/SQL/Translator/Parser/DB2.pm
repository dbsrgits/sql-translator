package SQL::Translator::Parser::DB2;

=head1 NAME

SQL::Translator::Parser::DB2 - parser for DB2

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::DB2;

  my $translator = SQL::Translator->new;
  $translator->parser("SQL::Translator::Parser::DB2");

=head1 DESCRIPTION

This is a grammar for parsing CREATE statements for DB2

=cut

use warnings;
use strict;

use base qw(Exporter);
our @EXPORT_OK = qw(parse);

our $DEBUG;

use Data::Dumper;
use SQL::Translator::Utils qw/ddl_parser_instance/;

# !!!!!!
# THIS GRAMMAR IS INCOMPLETE!!!
# Khisanth is slowly working on a replacement
# !!!!!!
our $GRAMMAR = <<'END_OF_GRAMMAR';

{
    my ( %tables, $table_order, @table_comments, @views, @triggers );
}

#
# The "eofile" rule makes the parser fail if any "statement" rule
# fails.  Otherwise, the first successful match by a "statement"
# won't cause the failure needed to know that the parse, as a whole,
# failed. -ky
#
startrule : statement(s) eofile {
    $return      = {
        tables   => \%tables,
        views    => \@views,
        triggers => \@triggers,
    }
}

eofile : /^\Z/

statement :
    comment
    | create
    | <error>

comment : /^\s*-{2}.*\n/
    {
        my $comment =  $item[1];
        $comment    =~ s/^\s*(-{2})\s*//;
        $comment    =~ s/\s*$//;
        $return     = $comment;
    }


create: CREATE TRIGGER trigger_name before type /ON/i table_name reference_b(?) /FOR EACH ROW/i 'MODE DB2SQL' triggered_action
{
    my $table_name = $item{'table_name'}{'name'};
    $return =  {
        table      => $table_name,
        schema     => $item{'trigger_name'}{'schema'},
        name       => $item{'trigger_name'}{'name'},
        when       => 'before',
        db_event   => $item{'type'}->{'event'},
        fields     => $item{'type'}{'fields'},
        condition  => $item{'triggered_action'}{'condition'},
        reference  => $item{'reference_b'},
        granularity => $item[9],
        action     => $item{'triggered_action'}{'statement'}
    };

    push @triggers, $return;
}

create: CREATE TRIGGER trigger_name after type /ON/i table_name reference_a(?) /FOR EACH ROW|FOR EACH STATEMENT/i 'MODE DB2SQL' triggered_action
{
    my $table_name = $item{'table_name'}{'name'};
    $return = {
        table      => $table_name,
        schema     => $item{'trigger_name'}{'schema'},
        name       => $item{'trigger_name'}{'name'},
        when       => 'after',
        db_event   => $item{'type'}{'event'},
        fields     => $item{'type'}{'fields'},
        condition  => $item{'triggered_action'}{'condition'},
        reference  => $item{'reference_a'},
        granularity => $item[9],
        action     => $item{'triggered_action'}{'statement'}
    };

    push @triggers, $return;
}

create: CREATE /FEDERATED|/i VIEW view_name column_list(?) /AS/i with_expression(?) SQL_procedure_statement
{
    $return = {
        name   => $item{view_name}{name},
        sql    => $item{SQL_procedure_statement},
        with   => $item{'with_expression(?)'},
        fields => $item{'column_list(?)'}
    };
    push @views, $return;
}

# create: CREATE /FEDERATED/i VIEW view_name col_list_or_of(?) /AS/i with_expression(?) fullselect options(?)

# col_list_or_of: column_list | /OF/i ( root_view_definition | subview_definition )

with_expression: /WITH/i common_table_expression(s /,/)
{
    $return = $item{'common_table_expression'};
}

SQL_procedure_statement: /[^;]*/ /(;|\z)/ { $return = $item[1] . $item[2] }

column_list: '(' column_name(s /,/) ')'
{
    $return = join(' ', '(', @{$item[2]}, ')');
}

CREATE: /create/i

TRIGGER: /trigger/i

VIEW: /view/i

INNER: /inner/i

LEFT: /left/i

RIGHT: /right/i

FULL: /full/i

OUTER: /outer/i

WHERE: /where/i

trigger_name: SCHEMA '.' NAME
    { $return = { schema => $item[1], name => $item[3] } }
    | NAME
    { $return = { name => $item[1] } }

table_name: SCHEMA '.' NAME
    { $return = { schema => $item[1], name => $item[3] } }
    | NAME
    { $return = { name => $item[1] } }

view_name: SCHEMA '.' NAME
    { $return = { schema => $item[1], name => $item[3] } }
    | NAME
    { $return = { name => $item[1] } }

column_name: NAME

identifier: NAME

correlation_name: NAME

numeric_constant: /\d+/

SCHEMA: /\w+/

SCHEMA: /\w{1,128}/

NAME: /\w+/

NAME: /\w{1,18}/

options: /WITH/i ( /CASCADED/i | /LOCAL/i ) /CHECK\s+OPTION/i

# root_view_definition: /MODE\s+DB2SQL/i '(' oid_column ( /,/ with_options )(?) ')'

# subview_definition: /MODE\s+DB2SQL/i under_clause ( '(' with_options ')' )(?) /EXTEND/i(?)

# oid_column: /REF\s+IS/i oid_column_name /USER\s+GENERATED\s+UNCHECKED/i(?)

# with_options: ( column_name /WITH\s+OPTIONS/i ( /SCOPE/i ( typed_table_name | typed_view_name ) | /READ\s+ONLY/i )(s /,/) )(s /,/)

# under_clause: /UNDER/i superview_name /INHERIT\s+SELECT\s+PRIVILEGES/i

common_table_expression: table_name column_list /AS/i get_bracketed
{
    $return = { name  => $item{table_name}{name},
                query => $item[4]
                };
}

get_bracketed:
{
    extract_bracketed($text, '(');
}

common_table_expression: table_name column_list /AS/i '(' fullselect ')'

# fullselect: ( subselect | '(' fullselect ')' | values_clause ) ( ( /UNION/i | /UNION/i /ALL/i | /EXCEPT/i | /EXCEPT/i /ALL/i | /INTERSECT/i | /INTERSECT/i /ALL/i ) ( subselect | '(' fullselect ')' | values_clause ) )(s)

# values_clause: /VALUES/i values_row(s /,/)

# values_row: ( expression | /NULL/i ) | '(' ( expression | /NULL/i )(s /,/) ')'

# subselect:  select_clause from_clause where_clause(?) group_by_clause(?) having_clause(?)

# select_clause: SELECT ( /ALL/i | /DISTINCT )(?) ( '*' | ( expression ( /AS|/i new_column_name )(?) | exposed_name '.*' )(s /,/) )

# from_clause: /FROM/i table_name(s /,/)

# from_clause: /FROM/i table_reference(s /,/)

# table_reference:
#     (
#       ( nickname
#       | table_name
#       | view_name
#       )
#     | ( /ONLY/i
#       | /OUTER/i
#       ) '('
#       ( table_name
#       | view_name
#       ) ')'
#     ) correlation_clause(?)
#   | TABLE '(' function_name '(' expression(s? /,/) ')' ')'  correlation_clause
#   | TABLE(?) '(' fullselect ')' correlation_clause
#   | joined_table


# correlation_clause: /AS/i(?) correlation_name column_list(?)

# joined_table:
#    table_reference ( INNER
#                     | outer
#                     )(?) JOIN table_reference ON join_condition
#   | '(' joined_table ')'

# outer: ( LEFT | RIGHT | FULL ) OUTER(?)

where_clause: WHERE search_condition

# group_by_clause: /GROUP\s+BY/i ( grouping_expression
#                                | grouping_sets
#                                | super_groups
#                                )(s /,/)

# grouping_expression: expression

# orderby_clause: /ORDER\s+BY/i ( sort_key ( /ASC/i | /DESC/i)(?) )(s /,/)

# sort_key: simple_column_name | simple_integer | sort_key_expression

# # Name of one of the selected columns!
# simple_column_name: NAME

# simple_integer: /\d+/
#   { $item[1] <= $numberofcolumns && $item[1] > 1 }

# sort_key_expression: expression
#   { expression from select columns list, grouping_expression, column function.. }

# grouping_sets: /GROUPING\s+SETS/i '(' (
#                                         ( grouping_expression
#                                         | super_groups
#                                         )
#                                       | '(' ( grouping_expression
#                                             | super_groups
#                                             )(s /,/) ')'
#                                       )(s /,/) ')'

# super_groups: /ROLLUP/i '(' grouping_expression_list ')'
#            | /CUBE/i '(' grouping_expression_list ')'
#            | grand_total

# grouping_expression_list:  ( grouping_expression
#                            | '(' grouping_expression(s /,/) ')'
#                            )(s /,/)

# grand_total: '(' ')'

# having_clause: /HAVING/i search_condition

when_clause: /WHEN/i '(' search_condition ')' {$return = $item[3]}

triggered_action: when_clause(?) SQL_procedure_statement
{ $return = { 'condition' => $item[1][0],
              'statement' => $item{'SQL_procedure_statement'} };
}

before: /NO CASCADE BEFORE/i

after: /AFTER/i

type: /UPDATE/i /OF/i column_name(s /,/)
{ $return = { event  => 'update_on',
              fields => $item[3] }
}

type: ( /INSERT/i | /DELETE/i | /UPDATE/i )
{ $return = { event => $item[1] } }

reference_b: /REFERENCING/i old_new_corr(0..2)
{ $return = join(' ', $item[1], join(' ', @{$item[2]}) ) }

reference_a: /REFERENCING/i old_new_corr(0..2) old_new_table(0..2)
{ $return = join(' ', $item[1], join(' ', @{$item[2]}), join(' ', @{$item[3]})  ) }

old_new_corr: /OLD/i /(AS)?/i correlation_name
{ $return = join(' ', @item[1..3] ) }
| /NEW/i /(AS)?/i correlation_name
{ $return = join(' ', @item[1..3] ) }

old_new_table: /OLD_TABLE/i /(AS)?/i identifier
{ $return = join(' ', @item[1..3] ) }
| /NEW_TABLE/i /(AS)?/i identifier
{ $return = join(' ', @item[1..3] ) }

# Just parsing simple search conditions for now.
search_condition: /[^)]+/

expression: (
              ( '+'
              | '-'
              )(?)
              ( function
              | '(' expression ')'
              | constant
              | column_name
              | host_variable
              | special_register
              | '(' scalar_fullselect ')'
              | labeled_duration
              | case_expression
              | cast_specification
#              | dereference_operation
              | OLAP_function
              | method_invocation
              | subtype_treatment
              | sequence_reference
              )
            )(s /operator/)

operator: ( /CONCAT/i | '||' ) | '/' | '*' | '+' | '-'

function: ( /SYSIBM\.|/i sysibm_function
          | /SYSFUN\.|/i sysfun_function
          | userdefined_function
          ) '(' func_args(s /,/)  ')'

constant: int_const | float_const | dec_const | char_const | hex_const | grastr_const

func_args: expression

sysibm_function: ( /ABS/i | /ABSVAL/i )
                | /AVG/i
                | /BIGINT/i
                | /BLOB/i
                | /CHAR/i
                | /CLOB/i
                | /COALESCE/i
                | ( /CONCAT/ | '||' )
                | ( /CORRELATION/i | /CORR/ )
                | /COUNT/i
                | /COUNT_BIG/i
                | (/COVARIANCE/i | /COVAR/i )
                | /DATE/i
                | /DAY/i
                | /DAYS/i
                | /DBCLOB/i
                | ( /DECIMAL/i | /DEC/i )
                | /DECRYPT_BIN/i
                | /DECRYPT_CHAR/i
                | /DEREF/i
                | /DIGITS/i
                | /DLCOMMENT/i
                | /DLLINKTYPE/i
                | /DLURLCOMPLETE/i
                | /DLURLPATH/i
                | /DLURLPATHONLY/i
                | /DLURLSCHEME/i
                | /DLURLSERVER/i
                | /DLVALUE/i
                | ( /DOUBLE/i | /DOUBLE_PRECISION/i )
                | /ENCRYPT/i
                | /EVENT_MON_STATE/i
                | /FLOAT/i
                | /GETHINT/i
                | /GENERATE_UNIQUE/i
                | /GRAPHIC/i
                | /GROUPING/i
                | /HEX/i
                | /HOUR/i
                | /IDENTITY_VAL_LOCAL/i
                | ( /INTEGER/i | /INT/ )
                | ( /LCASE/i | /LOWER/ )
                | /LENGTH/i
                | /LONG_VARCHAR/i
                | /LONG_VARGRAPHIC/i
                | /LTRIM/i
                | /MAX/i
                | /MICROSECOND/i
                | /MIN/i
                | /MINUTE/i
                | /MONTH/i
                | /MULTIPLY_ACT/i
                | /NODENUMBER/i
                | /NULLIF/i
                | /PARTITON/i
                | /POSSTR/i
                | /RAISE_ERROR/i
                | /REAL/i
                | /REC2XML/i
                | /REGR_AVGX/i
                | /REGR_AVGY/i
                | /REGR_COUNT/i
                | ( /REGR_INTERCEPT/i | /REGR_ICPT/i )
                | /REGR_R2/i
                | /REGR_SLOPE/i
                | /REGR_SXX/i
                | /REGR_SXY/i
                | /REGR_SYY/i
                | /RTRIM/i
                | /SECOND/i
                | /SMALLINT/i
                | /STDDEV/i
                | /SUBSTR/i
                | /SUM/i
                | /TABLE_NAME/i
                | /TABLE_SCHEMA/i
                | /TIME/i
                | /TIMESTAMP/i
                | /TRANSLATE/i
                | /TYPE_ID/i
                | /TYPE_NAME/i
                | /TYPE_SCHEMA/i
                | ( /UCASE/i | /UPPER/i )
                | /VALUE/i
                | /VARCHAR/i
                | /VARGRAPHIC/i
                | ( /VARIANCE/i | /VAR/i )
                | /YEAR/i

sysfun: ( /ABS/i | /ABSVAL/i )
                | /ACOS/i
                | /ASCII/i
                | /ASIN/i
                | /ATAN/i
                | /ATAN2/i
                | ( /CEIL/i | /CEILING/i )
                | /CHAR/i
                | /CHR/i
                | /COS/i
                | /COT/i
                | /DAYNAME/i
                | /DAYOFWEEK/i
                | /DAYOFWEEK_ISO/i
                | /DAYOFYEAR/i
                | /DEGREES/i
                | /DIFFERENCE/i
                | /DOUBLE/i
                | /EXP/i
                | /FLOOR/i
                | /GET_ROUTINE_SAR/i
                | /INSERT/i
                | /JULIAN_DAY/i
                | /LCASE/i
                | /LEFT/i
                | /LN/i
                | /LOCATE/i
                | /LOG/i
                | /LOG10/i
                | /LTRIM/i
                | /MIDNIGHT_SECONDS/i
                | /MOD/i
                | /MONTHNAME/i
                | /POWER/i
                | /PUT_ROUTINE_SAR/i
                | /QUARTER/i
                | /RADIANS/i
                | /RAND/i
                | /REPEAT/i
                | /REPLACE/i
                | /RIGHT/i
                | /ROUND/i
                | /RTRIM/I
                | /SIGN/i
                | /SIN/i
                | /SOUNDEX/i
                | /SPACE/i
                | /SQLCACHE_SNAPSHOT/i
                | /SQRT/i
                | /TAN/i
                | /TIMESTAMP_ISO/i
                | /TIMESTAMPDIFF/i
                | ( /TRUNCATE/i | /TRUNC/i )
                | /UCASE/i
                | /WEEK/i
                | /WEEK_ISO/i

scalar_fullselect: '(' fullselect ')'

labeled_duration: ld_type ld_duration

ld_type: function
       | '(' expression ')'
       | constant
       | column_name
       | host_variable

ld_duration: /YEARS?/i
           | /MONTHS?/i
           | /DAYS?/i
           | /HOURS?/i
           | /MINUTES?/i
           | /SECONDS?/i
           | /MICROSECONDS?/i

case_expression: /CASE/i ( searched_when_clause
                         | simple_when_clause
                         )
                         ( /ELSE\s+NULL/i
                         | /ELSE/i result_expression
                         )(?) /END/i

searched_when_clause: ( /WHEN/i search_condition /THEN/i
                        ( result_expression
                        | /NULL/i
                        )
                      )(s)

simple_when_clause: expression ( /WHEN/i search_condition /THEN/i
                                 ( result_expression
                                 | /NULL/i
                                 )
                               )(s)

result_expression: expression

cast_specification: /CAST/i '(' ( expression
                                | /NULL/i
                                | parameter_marker
                                ) /AS/i data_type
                                  ( /SCOPE/ ( typed_table_name
                                            | typed_view_name
                                            )
                                  )(?) ')'

dereference_operation: scoped_reference_expression '->' name1
                      (  '(' expression(s) ')' )(?)
#                         ( '(' expression(s /,/) ')' )(?)



scoped_reference_expression: expression
{ # scoped, reference
}

name1: NAME

OLAP_function: ranking_function
             | numbering_function
             | aggregation_function

ranking_function: ( /RANK/ '()'
                  | /DENSE_RANK|DENSERANK/i '()'
                  ) /OVER/i '(' window_partition_clause(?) window_order_clause ')'

numbering_function: /ROW_NUMBER|ROWNUMBER/i '()' /OVER/i '(' window_partition_clause(?)
                      ( window_order_clause window_aggregation_group_clause(?)
                      )(?)
                      ( /RANGE\s+BETWEEN\s+UNBOUNDED\s+PRECEDING\s+AND\s+UNBBOUNDED\s+FOLLOWING/i
                      | window_aggregation_group_clause
                      )(?) ')'

window_partition_clause: /PARTITION\s+BY/i partitioning_expression(s /,/)

window_order_clause: /ORDER\s+BY/i
                      ( sort_key_expression
                        ( asc_option
                        | desc_option
                        )(?)
                      )(s /,/)

asc_option: /ASC/i ( /NULLS\s+FIRST/i | /NULLS\s+LAST/i )(?)

desc_option: /DESC/i ( /NULLS\s+FIRST/i | /NULLS\s+LAST/i )(?)

window_aggregation_group_clause: ( /ROWS/i
                                 | /RANGE/i
                                 )
                                 ( group_start
                                 | group_between
                                 | group_end
                                 )

group_start: /UNBOUNDED\s+PRECEDING/i
           | unsigned_constant /PRECEDING/i
           | /CURRENT\s+ROW/i

group_between: /BETWEEN/i group_bound1 /AND/i group_bound2

group_bound1: /UNBOUNDED\s+PRECEDING/i
           | unsigned_constant /PRECEDING/i
           | unsigned_constant /FOLLOWING/i
           | /CURRENT\s+ROW/i

group_bound2: /UNBOUNDED\s+PRECEDING/i
           | unsigned_constant /PRECEDING/i
           | unsigned_constant /FOLLOWING/i
           | /CURRENT\s+ROW/i

group_end: /UNBOUNDED\s+PRECEDING/i
           | unsigned_constant /FOLLOWING/i

method_invocation: subject_expression '..' method_name
                    ( '(' expression(s) ')'
#                    ( '(' expression(s /,/) ')'
                    )(?)

subject_expression: expression
{ # with static result type that is a used-defined struct type
}

method_name: NAME
{ # must be a method of subject_expression
}

subtype_treatment: /TREAT/i '(' expression /AS/i data_type ')'

sequence_reference: nextval_expression
                  | prevval_expression

nextval_expression: /NEXTVAL\s+FOR/i sequence_name

prevval_expression: /PREVVAL\s+FOR/i sequence_name

sequence_name: NAME


search_condition: /NOT|/i ( predicate ( /SELECTIVITY/i numeric_constant )(?) | '(' search_condition ')' ) cond(s?)

cond: ( /AND/i | /OR/i ) /NOT|/i ( predicate ( /SELECTIVITY/i numeric_constant )(?) | '(' search_condition ')' )

predicate: basic_p | quantified_p | between_p | exists_p | in_p | like_p | null_p | type_p

basic_p: expression /(=|<>|<|>|<=|=>|\^=|\^<|\^>|\!=)/ expression

quantified_p: expression1 /(=|<>|<|>|<=|=>|\^=|\^<|\^>|\!=)/ /SOME|ANY|ALL/i '(' fullselect ')'

END_OF_GRAMMAR

sub parse {
    my ( $translator, $data ) = @_;

    # Enable warnings within the Parse::RecDescent module.
    local $::RD_ERRORS = 1 unless defined $::RD_ERRORS; # Make sure the parser dies when it encounters an error
    local $::RD_WARN   = 1 unless defined $::RD_WARN; # Enable warnings. This will warn on unused rules &c.
    local $::RD_HINT   = 1 unless defined $::RD_HINT; # Give out hints to help fix problems.

    local $::RD_TRACE  = $translator->trace ? 1 : undef;
    local $DEBUG       = $translator->debug;

    my $parser = ddl_parser_instance('DB2');

    my $result = $parser->startrule($data);
    return $translator->error( "Parse failed." ) unless defined $result;
    warn Dumper( $result ) if $DEBUG;

    my $schema = $translator->schema;
    my @tables =
        map   { $_->[1] }
        sort  { $a->[0] <=> $b->[0] }
        map   { [ $result->{'tables'}{ $_ }->{'order'}, $_ ] }
        keys %{ $result->{'tables'} };

    for my $table_name ( @tables ) {
        my $tdata =  $result->{'tables'}{ $table_name };
        my $table =  $schema->add_table(
            name  => $tdata->{'name'},
        ) or die $schema->error;

        $table->comments( $tdata->{'comments'} );

        for my $fdata ( @{ $tdata->{'fields'} } ) {
            my $field = $table->add_field(
                name              => $fdata->{'name'},
                data_type         => $fdata->{'data_type'},
                size              => $fdata->{'size'},
                default_value     => $fdata->{'default'},
                is_auto_increment => $fdata->{'is_auto_inc'},
                is_nullable       => $fdata->{'is_nullable'},
                comments          => $fdata->{'comments'},
            ) or die $table->error;

            $table->primary_key( $field->name ) if $fdata->{'is_primary_key'};

            for my $cdata ( @{ $fdata->{'constraints'} } ) {
                next unless $cdata->{'type'} eq 'foreign_key';
                $cdata->{'fields'} ||= [ $field->name ];
                push @{ $tdata->{'constraints'} }, $cdata;
            }
        }

        for my $idata ( @{ $tdata->{'indices'} || [] } ) {
            my $index  =  $table->add_index(
                name   => $idata->{'name'},
                type   => uc $idata->{'type'},
                fields => $idata->{'fields'},
            ) or die $table->error;
        }

        for my $cdata ( @{ $tdata->{'constraints'} || [] } ) {
            my $constraint       =  $table->add_constraint(
                name             => $cdata->{'name'},
                type             => $cdata->{'type'},
                fields           => $cdata->{'fields'},
                reference_table  => $cdata->{'reference_table'},
                reference_fields => $cdata->{'reference_fields'},
                match_type       => $cdata->{'match_type'} || '',
                on_delete        => $cdata->{'on_delete'} || $cdata->{'on_delete_do'},
                on_update        => $cdata->{'on_update'} || $cdata->{'on_update_do'},
            ) or die $table->error;
        }
    }

    for my $def ( @{ $result->{'views'} || [] } ) {
        my $view = $schema->add_view(
            name => $def->{'name'},
            sql  => $def->{'sql'},
        );
    }

    for my $def ( @{ $result->{'triggers'} || [] } ) {
        my $trig                = $schema->add_trigger(
            name                => $def->{'name'},
            perform_action_when => $def->{'when'},
            database_event      => $def->{'db_event'},
            action              => $def->{'action'},
            fields              => $def->{'fields'},
            on_table            => $def->{'table'}
                                                       );
        $trig->extra( reference => $def->{'reference'},
                      condition => $def->{'condition'},
                      granularity => $def->{'granularity'} );
    }

    return 1;
}

1;

=pod

=head1 AUTHOR

Jess Robinson <cpan@desert-island.me.uk>

=head1 SEE ALSO

perl(1), Parse::RecDescent, SQL::Translator::Schema.

=cut
