package SQL::Translator::Parser::SQLite;

=head1 NAME

SQL::Translator::Parser::SQLite - parser for SQLite

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::SQLite;

  my $translator = SQL::Translator->new;
  $translator->parser("SQL::Translator::Parser::SQLite");

=head1 DESCRIPTION

This is a grammar for parsing CREATE statements for SQLite as
described here:

    http://www.sqlite.org/lang.html

CREATE INDEX

sql-statement ::=
    CREATE [TEMP | TEMPORARY] [UNIQUE] INDEX index-name
     ON [database-name .] table-name ( column-name [, column-name]* )
     [ ON CONFLICT conflict-algorithm ]

column-name ::=
    name [ ASC | DESC ]

CREATE TABLE

sql-command ::=
    CREATE [TEMP | TEMPORARY] TABLE table-name (
        column-def [, column-def]*
        [, constraint]*
     )

sql-command ::=
    CREATE [TEMP | TEMPORARY] TABLE table-name AS select-statement

column-def ::=
    name [type] [[CONSTRAINT name] column-constraint]*

type ::=
    typename |
     typename ( number ) |
     typename ( number , number )

column-constraint ::=
    NOT NULL [ conflict-clause ] |
    PRIMARY KEY [sort-order] [ conflict-clause ] |
    UNIQUE [ conflict-clause ] |
    CHECK ( expr ) [ conflict-clause ] |
    DEFAULT value

constraint ::=
    PRIMARY KEY ( name [, name]* ) [ conflict-clause ]|
    UNIQUE ( name [, name]* ) [ conflict-clause ] |
    CHECK ( expr ) [ conflict-clause ]

conflict-clause ::=
    ON CONFLICT conflict-algorithm

CREATE TRIGGER

sql-statement ::=
    CREATE [TEMP | TEMPORARY] TRIGGER trigger-name [ BEFORE | AFTER ]
    database-event ON [database-name .] table-name
    trigger-action

sql-statement ::=
    CREATE [TEMP | TEMPORARY] TRIGGER trigger-name INSTEAD OF
    database-event ON [database-name .] view-name
    trigger-action

database-event ::=
    DELETE |
    INSERT |
    UPDATE |
    UPDATE OF column-list

trigger-action ::=
    [ FOR EACH ROW | FOR EACH STATEMENT ] [ WHEN expression ]
        BEGIN
            trigger-step ; [ trigger-step ; ]*
        END

trigger-step ::=
    update-statement | insert-statement |
    delete-statement | select-statement

CREATE VIEW

sql-command ::=
    CREATE [TEMP | TEMPORARY] VIEW view-name AS select-statement

ON CONFLICT clause

    conflict-clause ::=
    ON CONFLICT conflict-algorithm

    conflict-algorithm ::=
    ROLLBACK | ABORT | FAIL | IGNORE | REPLACE

expression

expr ::=
    expr binary-op expr |
    expr like-op expr |
    unary-op expr |
    ( expr ) |
    column-name |
    table-name . column-name |
    database-name . table-name . column-name |
    literal-value |
    function-name ( expr-list | * ) |
    expr (+) |
    expr ISNULL |
    expr NOTNULL |
    expr [NOT] BETWEEN expr AND expr |
    expr [NOT] IN ( value-list ) |
    expr [NOT] IN ( select-statement ) |
    ( select-statement ) |
    CASE [expr] ( WHEN expr THEN expr )+ [ELSE expr] END

like-op::=
    LIKE | GLOB | NOT LIKE | NOT GLOB

=cut

use strict;
use warnings;

our $VERSION = '1.59';

our $DEBUG;
$DEBUG   = 0 unless defined $DEBUG;

use Data::Dumper;
use SQL::Translator::Utils qw/ddl_parser_instance/;

use base qw(Exporter);
our @EXPORT_OK = qw(parse);

our $GRAMMAR = <<'END_OF_GRAMMAR';

{
    my ( %tables, $table_order, @table_comments, @views, @triggers );

    sub _err {
      my $max_lines = 5;
      my @up_to_N_lines = split (/\n/, $_[1], $max_lines + 1);
      die sprintf ("Unable to parse line %d:\n%s\n",
        $_[0],
        join "\n", (map { "'$_'" } @up_to_N_lines[0..$max_lines - 1 ]), @up_to_N_lines > $max_lines ? '...' : ()
      );
    }

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

statement : begin_transaction
    | commit
    | drop
    | comment
    | create
    | /^\Z/ | { _err ($thisline, $text) }

begin_transaction : /begin/i TRANSACTION(?) SEMICOLON

commit : /commit/i SEMICOLON

drop : /drop/i (tbl_drop | view_drop | trg_drop) SEMICOLON

tbl_drop: TABLE <commit> table_name

view_drop: VIEW if_exists(?) view_name

trg_drop: TRIGGER if_exists(?) trigger_name

comment : /^\s*(?:#|-{2}).*\n/
    {
        my $comment =  $item[1];
        $comment    =~ s/^\s*(#|-{2})\s*//;
        $comment    =~ s/\s*$//;
        $return     = $comment;
    }

comment : /\/\*/ /[^\*]+/ /\*\//
    {
        my $comment = $item[2];
        $comment    =~ s/^\s*|\s*$//g;
        $return = $comment;
    }

#
# Create Index
#
create : CREATE TEMPORARY(?) UNIQUE(?) INDEX NAME ON table_name parens_field_list conflict_clause(?) SEMICOLON
    {
        my $db_name    = $item[7]->{'db_name'} || '';
        my $table_name = $item[7]->{'name'};

        my $index        =  {
            name         => $item[5],
            fields       => $item[8],
            on_conflict  => $item[9][0],
            is_temporary => $item[2][0] ? 1 : 0,
        };

        my $is_unique = $item[3][0];

        if ( $is_unique ) {
            $index->{'type'} = 'unique';
            push @{ $tables{ $table_name }{'constraints'} }, $index;
        }
        else {
            push @{ $tables{ $table_name }{'indices'} }, $index;
        }
    }

#
# Create Table
#
create : CREATE TEMPORARY(?) TABLE table_name '(' definition(s /,/) ')' SEMICOLON
    {
        my $db_name    = $item[4]->{'db_name'} || '';
        my $table_name = $item[4]->{'name'};

        $tables{ $table_name }{'name'}         = $table_name;
        $tables{ $table_name }{'is_temporary'} = $item[2][0] ? 1 : 0;
        $tables{ $table_name }{'order'}        = ++$table_order;

        for my $def ( @{ $item[6] } ) {
            if ( $def->{'supertype'} eq 'column' ) {
                push @{ $tables{ $table_name }{'fields'} }, $def;
            }
            elsif ( $def->{'supertype'} eq 'constraint' ) {
                push @{ $tables{ $table_name }{'constraints'} }, $def;
            }
        }
    }

definition : constraint_def | column_def

column_def: comment(s?) NAME type(?) column_constraint_def(s?)
    {
        my $column = {
            supertype      => 'column',
            name           => $item[2],
            data_type      => $item[3][0]->{'type'},
            size           => $item[3][0]->{'size'},
            is_nullable    => 1,
            is_primary_key => 0,
            is_unique      => 0,
            check          => '',
            default        => undef,
            constraints    => $item[4],
            comments       => $item[1],
        };


        for my $c ( @{ $item[4] } ) {
            if ( $c->{'type'} eq 'not_null' ) {
                $column->{'is_nullable'} = 0;
            }
            elsif ( $c->{'type'} eq 'primary_key' ) {
                $column->{'is_primary_key'} = 1;
            }
            elsif ( $c->{'type'} eq 'unique' ) {
                $column->{'is_unique'} = 1;
            }
            elsif ( $c->{'type'} eq 'check' ) {
                $column->{'check'} = $c->{'expression'};
            }
            elsif ( $c->{'type'} eq 'default' ) {
                $column->{'default'} = $c->{'value'};
            }
            elsif ( $c->{'type'} eq 'autoincrement' ) {
                $column->{'is_auto_inc'} = 1;
            }
        }

        $column;
    }

type : WORD parens_value_list(?)
    {
        $return = {
            type => $item[1],
            size => $item[2][0],
        }
    }

column_constraint_def : CONSTRAINT constraint_name column_constraint
    {
        $return = {
            name => $item[2],
            %{ $item[3] },
        }
    }
    |
    column_constraint

column_constraint : NOT_NULL conflict_clause(?)
    {
        $return = {
            type => 'not_null',
        }
    }
    |
    PRIMARY_KEY sort_order(?) conflict_clause(?)
    {
        $return = {
            type        => 'primary_key',
            sort_order  => $item[2][0],
            on_conflict => $item[2][0],
        }
    }
    |
    UNIQUE conflict_clause(?)
    {
        $return = {
            type        => 'unique',
            on_conflict => $item[2][0],
        }
    }
    |
    CHECK_C '(' expr ')' conflict_clause(?)
    {
        $return = {
            type        => 'check',
            expression  => $item[3],
            on_conflict => $item[5][0],
        }
    }
    |
    DEFAULT VALUE
    {
        $return   = {
            type  => 'default',
            value => $item[2],
        }
    }
    |
    REFERENCES ref_def cascade_def(?)
    {
        $return   = {
            type             => 'foreign_key',
            reference_table  => $item[2]{'reference_table'},
            reference_fields => $item[2]{'reference_fields'},
            on_delete        => $item[3][0]{'on_delete'},
            on_update        => $item[3][0]{'on_update'},
        }
    }
    |
    AUTOINCREMENT
    {
        $return = {
            type => 'autoincrement',
        }
    }

constraint_def : comment(s?) CONSTRAINT constraint_name table_constraint
    {
        $return = {
            comments => $item[1],
            name => $item[3],
            %{ $item[4] },
        }
    }
    |
    comment(s?) table_constraint
    {
        $return = {
            comments => $item[1],
            %{ $item[2] },
        }
    }

table_constraint : PRIMARY_KEY parens_field_list conflict_clause(?)
    {
        $return         = {
            supertype   => 'constraint',
            type        => 'primary_key',
            fields      => $item[2],
            on_conflict => $item[3][0],
        }
    }
    |
    UNIQUE parens_field_list conflict_clause(?)
    {
        $return         = {
            supertype   => 'constraint',
            type        => 'unique',
            fields      => $item[2],
            on_conflict => $item[3][0],
        }
    }
    |
    CHECK_C '(' expr ')' conflict_clause(?)
    {
        $return         = {
            supertype   => 'constraint',
            type        => 'check',
            expression  => $item[3],
            on_conflict => $item[5][0],
        }
    }
    |
    FOREIGN_KEY parens_field_list REFERENCES ref_def cascade_def(?)
    {
      $return = {
        supertype        => 'constraint',
        type             => 'foreign_key',
        fields           => $item[2],
        reference_table  => $item[4]{'reference_table'},
        reference_fields => $item[4]{'reference_fields'},
        on_delete        => $item[5][0]{'on_delete'},
        on_update        => $item[5][0]{'on_update'},
      }
    }

ref_def : table_name parens_field_list
    { $return = { reference_table => $item[1]{name}, reference_fields => $item[2] } }

cascade_def : cascade_update_def cascade_delete_def(?)
    { $return = {  on_update => $item[1], on_delete => $item[2][0] } }
    |
    cascade_delete_def cascade_update_def(?)
    { $return = {  on_delete => $item[1], on_update => $item[2][0] } }

cascade_delete_def : /on\s+delete\s+(\w+)/i
    { $return = $1}

cascade_update_def : /on\s+update\s+(\w+)/i
    { $return = $1}

table_name : qualified_name

qualified_name : NAME
    { $return = { name => $item[1] } }

qualified_name : /(\w+)\.(\w+)/
    { $return = { db_name => $1, name => $2 } }

field_name : NAME

constraint_name : NAME

conflict_clause : /on conflict/i conflict_algorigthm

conflict_algorigthm : /(rollback|abort|fail|ignore|replace)/i

parens_field_list : '(' column_list ')'
    { $item[2] }

column_list : field_name(s /,/)

parens_value_list : '(' VALUE(s /,/) ')'
    { $item[2] }

expr : /[^)]+/

sort_order : /(ASC|DESC)/i

#
# Create Trigger

create : CREATE TEMPORARY(?) TRIGGER NAME before_or_after(?) database_event ON table_name trigger_action SEMICOLON
    {
        my $table_name = $item[8]->{'name'};
        push @triggers, {
            name         => $item[4],
            is_temporary => $item[2][0] ? 1 : 0,
            when         => $item[5][0],
            instead_of   => 0,
            db_events    => [ $item[6] ],
            action       => $item[9],
            on_table     => $table_name,
        }
    }

create : CREATE TEMPORARY(?) TRIGGER NAME instead_of database_event ON view_name trigger_action
    {
        my $table_name = $item[8]->{'name'};
        push @triggers, {
            name         => $item[4],
            is_temporary => $item[2][0] ? 1 : 0,
            when         => undef,
            instead_of   => 1,
            db_events    => [ $item[6] ],
            action       => $item[9],
            on_table     => $table_name,
        }
    }

database_event : /(delete|insert|update)/i

database_event : /update of/i column_list

trigger_action : for_each(?) when(?) BEGIN_C trigger_step(s) END_C
    {
        $return = {
            for_each => $item[1][0],
            when     => $item[2][0],
            steps    => $item[4],
        }
    }

for_each : /FOR EACH ROW/i

when : WHEN expr { $item[2] }

string :
   /'(\.|''|[^\\'])*'/

nonstring : /[^;\'"]+/

statement_body : string | nonstring

trigger_step : /(select|delete|insert|update)/i statement_body(s?) SEMICOLON
    {
        $return = join( ' ', $item[1], join ' ', @{ $item[2] || [] } )
    }

before_or_after : /(before|after)/i { $return = lc $1 }

instead_of : /instead of/i

if_exists : /if exists/i

view_name : qualified_name

trigger_name : qualified_name

#
# Create View
#
create : CREATE TEMPORARY(?) VIEW view_name AS select_statement
    {
        push @views, {
            name         => $item[4]->{'name'},
            sql          => $item[6],
            is_temporary => $item[2][0] ? 1 : 0,
        }
    }

select_statement : SELECT /[^;]+/ SEMICOLON
    {
        $return = join( ' ', $item[1], $item[2] );
    }

#
# Tokens
#
BEGIN_C : /begin/i

END_C : /end/i

TRANSACTION: /transaction/i

CREATE : /create/i

TEMPORARY : /temp(orary)?/i { 1 }

TABLE : /table/i

INDEX : /index/i

NOT_NULL : /not null/i

PRIMARY_KEY : /primary key/i

FOREIGN_KEY : /foreign key/i

CHECK_C : /check/i

DEFAULT : /default/i

TRIGGER : /trigger/i

VIEW : /view/i

SELECT : /select/i

ON : /on/i

AS : /as/i

WORD : /\w+/

WHEN : /when/i

REFERENCES : /references/i

CONSTRAINT : /constraint/i

AUTOINCREMENT : /autoincrement/i

UNIQUE : /unique/i { 1 }

SEMICOLON : ';'

NAME : /["']?(\w+)["']?/ { $return = $1 }

VALUE : /[-+]?\.?\d+(?:[eE]\d+)?/
    { $item[1] }
    | /'.*?'/
    {
        # remove leading/trailing quotes
        my $val = $item[1];
        $val    =~ s/^['"]|['"]$//g;
        $return = $val;
    }
    | /NULL/
    { 'NULL' }
    | /CURRENT_TIMESTAMP/i
    { 'CURRENT_TIMESTAMP' }

END_OF_GRAMMAR


sub parse {
    my ( $translator, $data ) = @_;

    # Enable warnings within the Parse::RecDescent module.
    local $::RD_ERRORS = 1 unless defined $::RD_ERRORS; # Make sure the parser dies when it encounters an error
    local $::RD_WARN   = 1 unless defined $::RD_WARN; # Enable warnings. This will warn on unused rules &c.
    local $::RD_HINT   = 1 unless defined $::RD_HINT; # Give out hints to help fix problems.

    local $::RD_TRACE  = $translator->trace ? 1 : undef;
    local $DEBUG       = $translator->debug;

    my $parser = ddl_parser_instance('SQLite');

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
                type   => uc ($idata->{'type'}||''),
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
                on_delete        => $cdata->{'on_delete'}
                                 || $cdata->{'on_delete_do'},
                on_update        => $cdata->{'on_update'}
                                 || $cdata->{'on_update_do'},
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
        my $view                = $schema->add_trigger(
            name                => $def->{'name'},
            perform_action_when => $def->{'when'},
            database_events     => $def->{'db_events'},
            action              => $def->{'action'},
            on_table            => $def->{'on_table'},
        );
    }

    return 1;
}

1;

# -------------------------------------------------------------------
# All wholsome food is caught without a net or a trap.
# William Blake
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

perl(1), Parse::RecDescent, SQL::Translator::Schema.

=cut
