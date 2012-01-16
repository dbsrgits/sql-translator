package SQL::Translator::Parser::Oracle;

=head1 NAME

SQL::Translator::Parser::Oracle - parser for Oracle

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::Oracle;

  my $translator = SQL::Translator->new;
  $translator->parser("SQL::Translator::Parser::Oracle");

=head1 DESCRIPTION

From http://www.ss64.com/ora/table_c.html:

 CREATE [GLOBAL TEMPORARY] TABLE [schema.]table (tbl_defs,...)
     [ON COMMIT {DELETE|PRESERVE} ROWS]
         [storage_options | CLUSTER cluster_name (col1, col2,... )
            | ORGANIZATION {HEAP [storage_options]
            | INDEX idx_organized_tbl_clause}]
               [LOB_storage_clause][varray_clause][nested_storage_clause]
                   partitioning_options
                      [[NO]CACHE] [[NO]MONITORING] [PARALLEL parallel_clause]
                         [ENABLE enable_clause | DISABLE disable_clause]
                             [AS subquery]

tbl_defs:
   column datatype [DEFAULT expr] [column_constraint(s)]
   table_ref_constraint

storage_options:
   PCTFREE int
   PCTUSED int
   INITTRANS int
   MAXTRANS int
   STORAGE storage_clause
   TABLESPACE tablespace
   [LOGGING|NOLOGGING]

idx_organized_tbl_clause:
   storage_option(s) [PCTTHRESHOLD int]
     [COMPRESS int|NOCOMPRESS]
         [ [INCLUDING column_name] OVERFLOW [storage_option(s)] ]

nested_storage_clause:
   NESTED TABLE nested_item STORE AS storage_table
      [RETURN AS {LOCATOR|VALUE} ]

partitioning_options:
   Partition_clause {ENABLE|DISABLE} ROW MOVEMENT

Column Constraints
(http://www.ss64.com/ora/clause_constraint_col.html)

   CONSTRAINT constrnt_name {UNIQUE|PRIMARY KEY} constrnt_state

   CONSTRAINT constrnt_name CHECK(condition) constrnt_state

   CONSTRAINT constrnt_name [NOT] NULL constrnt_state

   CONSTRAINT constrnt_name REFERENCES [schema.]table[(column)]
      [ON DELETE {CASCADE|SET NULL}] constrnt_state

constrnt_state
    [[NOT] DEFERRABLE] [INITIALLY {IMMEDIATE|DEFERRED}]
       [RELY | NORELY] [USING INDEX using_index_clause]
          [ENABLE|DISABLE] [VALIDATE|NOVALIDATE]
              [EXCEPTIONS INTO [schema.]table]

Note that probably not all of the above syntax is supported, but the grammar
was altered to better handle the syntax created by DDL::Oracle.

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

{ my ( %tables, %indices, %constraints, $table_order, @table_comments, %views, $view_order, %procedures, $proc_order ) }

#
# The "eofile" rule makes the parser fail if any "statement" rule
# fails.  Otherwise, the first successful match by a "statement"
# won't cause the failure needed to know that the parse, as a whole,
# failed. -ky
#
startrule : statement(s) eofile
    {
        $return = {
            tables      => \%tables,
            indices     => \%indices,
            constraints => \%constraints,
            views       => \%views,
            procedures  => \%procedures,
        };
    }

eofile : /^\Z/

statement : remark
   | run
    | prompt
    | create
    | table_comment
    | comment_on_table
    | comment_on_column
    | alter
    | drop
    | <error>

alter : /alter/i WORD /[^;]+/ ';'
    { @table_comments = () }

drop : /drop/i TABLE ';'

drop : /drop/i WORD(s) ';'
    { @table_comments = () }

create : create_table table_name '(' create_definition(s /,/) ')' table_option(s?) ';'
    {
        my $table_name                       = $item{'table_name'};
        $tables{ $table_name }{'order'}      = ++$table_order;
        $tables{ $table_name }{'table_name'} = $table_name;

        if ( @table_comments ) {
            $tables{ $table_name }{'comments'} = [ @table_comments ];
            @table_comments = ();
        }

        my $i = 1;
        my @constraints;
        for my $definition ( @{ $item[4] } ) {
            if ( $definition->{'type'} eq 'field' ) {
                my $field_name = $definition->{'name'};
                $tables{ $table_name }{'fields'}{ $field_name } =
                    { %$definition, order => $i };
                $i++;

                for my $constraint ( @{ $definition->{'constraints'} || [] } ) {
                    $constraint->{'fields'} = [ $field_name ];
                    push @{ $tables{ $table_name }{'constraints'} },
                        $constraint;
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
            push @{ $tables{ $table_name }{'table_options'} }, $option;
        }

        1;
    }

create : create_index index_name /on/i table_name index_expr table_option(?) ';'
    {
        my $table_name = $item[4];
        if ( $item[1] ) {
            push @{ $constraints{ $table_name } }, {
                name   => $item[2],
                type   => 'unique',
                fields => $item[5],
            };
        }
        else {
            push @{ $indices{ $table_name } }, {
                name   => $item[2],
                type   => 'normal',
                fields => $item[5],
            };
        }
    }

index_expr: parens_word_list
   { $item[1] }
   | '(' WORD parens_word_list ')'
   {
      my $arg_list = join(",", @{$item[3]});
      $return = "$item[2]($arg_list)";
   }

create : /create/i /or replace/i /procedure/i table_name not_end m#^/$#im
   {
      @table_comments = ();
        my $proc_name = $item[4];
        # Hack to strip owner from procedure name
        $proc_name =~ s#.*\.##;
        my $owner = '';
        my $sql = "$item[1] $item[2] $item[3] $item[4] $item[5]";

        $procedures{ $proc_name }{'order'}  = ++$proc_order;
        $procedures{ $proc_name }{'name'}   = $proc_name;
        $procedures{ $proc_name }{'owner'}  = $owner;
        $procedures{ $proc_name }{'sql'}    = $sql;
   }

not_end: m#.*?(?=^/$)#ism

create : /create/i /or replace/i /force/i /view/i table_name not_delimiter ';'
   {
      @table_comments = ();
        my $view_name = $item[5];
        # Hack to strip owner from view name
        $view_name =~ s#.*\.##;
        my $sql = "$item[1] $item[2] $item[3] $item[4] $item[5] $item[6] $item[7]";

        $views{ $view_name }{'order'}  = ++$view_order;
        $views{ $view_name }{'name'}   = $view_name;
        $views{ $view_name }{'sql'}    = $sql;
   }

not_delimiter: /.*?(?=;)/is

# Create anything else (e.g., domain, function, etc.)
create : ...!create_table ...!create_index /create/i WORD /[^;]+/ ';'
    { @table_comments = () }

create_index : /create/i UNIQUE(?) /index/i
   { $return = @{$item[2]} }

index_name : NAME '.' NAME
    { $item[3] }
    | NAME
    { $item[1] }

global_temporary: /global/i /temporary/i

table_name : NAME '.' NAME
    { $item[3] }
    | NAME
    { $item[1] }

create_definition : table_constraint
    | field
    | <error>

table_comment : comment
    {
        my $comment = $item[1];
        $return     = $comment;
        push @table_comments, $comment;
    }

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

remark : /^REM\s+.*\n/

run : /^(RUN|\/)\s+.*\n/

prompt : /prompt/i /(table|index|sequence|trigger)/i ';'

prompt : /prompt\s+create\s+.*\n/i

comment_on_table : /comment/i /on/i /table/i table_name /is/i comment_phrase ';'
    {
        push @{ $tables{ $item{'table_name'} }{'comments'} }, $item{'comment_phrase'};
    }

comment_on_column : /comment/i /on/i /column/i column_name /is/i comment_phrase ';'
    {
        my $table_name = $item[4]->{'table'};
        my $field_name = $item[4]->{'field'};
        push @{ $tables{ $table_name }{'fields'}{ $field_name }{'comments'} },
            $item{'comment_phrase'};
    }

column_name : NAME '.' NAME
    { $return = { table => $item[1], field => $item[3] } }

comment_phrase : /'.*?'/
    {
        my $val = $item[1];
        $val =~ s/^'|'$//g;
        $return = $val;
    }

field : comment(s?) field_name data_type field_meta(s?) comment(s?)
    {
        my ( $is_pk, $default, @constraints );
        my $null = 1;
        for my $meta ( @{ $item[4] } ) {
            if ( $meta->{'type'} eq 'default' ) {
                $default = $meta;
                next;
            }
            elsif ( $meta->{'type'} eq 'not_null' ) {
                $null = 0;
                next;
            }
            elsif ( $meta->{'type'} eq 'primary_key' ) {
                $is_pk = 1;
            }

            push @constraints, $meta if $meta->{'supertype'} eq 'constraint';
        }

        my @comments = ( @{ $item[1] }, @{ $item[5] } );

        $return = {
            type           => 'field',
            name           => $item{'field_name'},
            data_type      => $item{'data_type'}{'type'},
            size           => $item{'data_type'}{'size'},
            null           => $null,
            default        => $default->{'value'},
            is_primary_key => $is_pk,
            constraints    => [ @constraints ],
            comments       => [ @comments ],
        }
    }
    | <error>

field_name : NAME

data_type : ora_data_type data_size(?)
    {
        $return  = {
            type => $item[1],
            size => $item[2][0] || '',
        }
    }

data_size : '(' VALUE(s /,/) data_size_modifier(?) ')'
    { $item[2] }

data_size_modifier: /byte/i
   | /char/i

column_constraint : constraint_name(?) column_constraint_type constraint_state(s?)
    {
        my $desc       = $item{'column_constraint_type'};
        my $type       = $desc->{'type'};
        my $fields     = $desc->{'fields'}     || [];
        my $expression = $desc->{'expression'} || '';

        $return              =  {
            supertype        => 'constraint',
            name             => $item{'constraint_name(?)'}[0] || '',
            type             => $type,
            expression       => $type eq 'check' ? $expression : '',
            deferrable       => $desc->{'deferrable'},
            deferred         => $desc->{'deferred'},
            reference_table  => $desc->{'reference_table'},
            reference_fields => $desc->{'reference_fields'},
#            match_type       => $desc->{'match_type'},
#            on_update        => $desc->{'on_update'},
        }
    }

constraint_name : /constraint/i NAME { $item[2] }

column_constraint_type : /not\s+null/i { $return = { type => 'not_null' } }
    | /unique/i
        { $return = { type => 'unique' } }
    | /primary\s+key/i
        { $return = { type => 'primary_key' } }
    | /check/i check_expression
        {
            $return = {
                type       => 'check',
                expression => $item[2],
            };
        }
    | /references/i table_name parens_word_list(?) on_delete(?)
    {
        $return              =  {
            type             => 'foreign_key',
            reference_table  => $item[2],
            reference_fields => $item[3][0],
#            match_type       => $item[4][0],
            on_delete     => $item[5][0],
        }
    }

LPAREN : '('

RPAREN : ')'

check_condition_text : /.+\s+in\s+\([^)]+\)/i
    | /[^)]+/

check_expression : LPAREN check_condition_text RPAREN
    { $return = join( ' ', map { $_ || () }
        $item[1], $item[2], $item[3], $item[4][0] )
    }

constraint_state : deferrable { $return = { type => $item[1] } }
    | deferred { $return = { type => $item[1] } }
    | /(no)?rely/i { $return = { type => $item[1] } }
#    | /using/i /index/i using_index_clause
#        { $return = { type => 'using_index', index => $item[3] } }
    | /(dis|en)able/i { $return = { type => $item[1] } }
    | /(no)?validate/i { $return = { type => $item[1] } }
    | /exceptions/i /into/i table_name
        { $return = { type => 'exceptions_into', table => $item[3] } }

deferrable : /not/i /deferrable/i
    { $return = 'not_deferrable' }
    | /deferrable/i
    { $return = 'deferrable' }

deferred : /initially/i /(deferred|immediate)/i { $item[2] }

ora_data_type :
    /(n?varchar2|varchar)/i { $return = 'varchar2' }
    |
    /n?char/i { $return = 'character' }
    |
   /n?dec/i { $return = 'decimal' }
   |
    /number/i { $return = 'number' }
    |
    /integer/i { $return = 'integer' }
    |
    /(pls_integer|binary_integer)/i { $return = 'integer' }
    |
    /interval\s+day/i { $return = 'interval day' }
    |
    /interval\s+year/i { $return = 'interval year' }
    |
    /long\s+raw/i { $return = 'long raw' }
    |
    /(long|date|timestamp|raw|rowid|urowid|mlslabel|clob|nclob|blob|bfile|float|double)/i { $item[1] }

parens_value_list : '(' VALUE(s /,/) ')'
    { $item[2] }

parens_word_list : '(' WORD(s /,/) ')'
    { $item[2] }

field_meta : default_val
    | column_constraint

default_val  : /default/i /(?:')?[\w\d.-]*(?:')?/
    {
        my $val =  $item[2];
        $val    =~ s/'//g if defined $val;
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

create_table : /create/i global_temporary(?) /table/i

table_option : /organization/i WORD
    {
        $return = { 'ORGANIZATION' => $item[2] }
    }

table_option : /nomonitoring/i
    {
        $return = { 'NOMONITORING' => undef }
    }

table_option : /parallel/i '(' key_value(s) ')'
    {
        $return = { 'PARALLEL' => $item[3] }
    }

key_value : WORD VALUE
    {
        $return = { $item[1], $item[2] }
    }

table_option : /[^;]+/

table_constraint : comment(s?) constraint_name(?) table_constraint_type deferrable(?) deferred(?) constraint_state(s?) comment(s?)
    {
        my $desc       = $item{'table_constraint_type'};
        my $type       = $desc->{'type'};
        my $fields     = $desc->{'fields'};
        my $expression = $desc->{'expression'};
        my @comments   = ( @{ $item[1] }, @{ $item[-1] } );

        $return              =  {
            name             => $item{'constraint_name(?)'}[0] || '',
            type             => 'constraint',
            constraint_type  => $type,
            fields           => $type ne 'check' ? $fields : [],
            expression       => $type eq 'check' ? $expression : '',
            deferrable       => $item{'deferrable(?)'},
            deferred         => $item{'deferred(?)'},
            reference_table  => $desc->{'reference_table'},
            reference_fields => $desc->{'reference_fields'},
#            match_type       => $desc->{'match_type'}[0],
            on_delete        => $desc->{'on_delete'} || $desc->{'on_delete_do'},
            on_update        => $desc->{'on_update'} || $desc->{'on_update_do'},
            comments         => [ @comments ],
        }
    }

table_constraint_type : /primary key/i '(' NAME(s /,/) ')'
    {
        $return = {
            type   => 'primary_key',
            fields => $item[3],
        }
    }
    |
    /unique/i '(' NAME(s /,/) ')'
    {
        $return    =  {
            type   => 'unique',
            fields => $item[3],
        }
    }
    |
    /check/i check_expression /^(en|dis)able/i
    {
        $return        =  {
            type       => 'check',
            expression => join(' ', $item[2], $item[3]),
        }
    }
    |
    /foreign key/i '(' NAME(s /,/) ')' /references/i table_name parens_word_list(?) on_delete(?)
    {
        $return              =  {
            type             => 'foreign_key',
            fields           => $item[3],
            reference_table  => $item[6],
            reference_fields => $item[7][0],
#            match_type       => $item[8][0],
            on_delete     => $item[8][0],
#            on_update     => $item[9][0],
        }
    }

on_delete : /on delete/i WORD(s)
    { join(' ', @{$item[2]}) }

UNIQUE : /unique/i { $return = 1 }

WORD : /\w+/

NAME : /\w+/ { $item[1] }

TABLE : /table/i

VALUE   : /[-+]?\.?\d+(?:[eE]\d+)?/
    { $item[1] }
    | /'.*?'/   # XXX doesn't handle embedded quotes
    { $item[1] }
    | /NULL/
    { 'NULL' }

END_OF_GRAMMAR

sub parse {
    my ( $translator, $data ) = @_;

    # Enable warnings within the Parse::RecDescent module.
    local $::RD_ERRORS = 1 unless defined $::RD_ERRORS; # Make sure the parser dies when it encounters an error
    local $::RD_WARN   = 1 unless defined $::RD_WARN; # Enable warnings. This will warn on unused rules &c.
    local $::RD_HINT   = 1 unless defined $::RD_HINT; # Give out hints to help fix problems.

    local $::RD_TRACE  = $translator->trace ? 1 : undef;
    local $DEBUG       = $translator->debug;

    my $parser = ddl_parser_instance('Oracle');

    my $result = $parser->startrule( $data );
    die "Parse failed.\n" unless defined $result;
    if ( $DEBUG ) {
        warn "Parser results =\n", Dumper($result), "\n";
    }

    my $schema      = $translator->schema;
    my $indices     = $result->{'indices'};
    my $constraints = $result->{'constraints'};
    my @tables      = sort {
        $result->{'tables'}{ $a }{'order'}
        <=>
        $result->{'tables'}{ $b }{'order'}
    } keys %{ $result->{'tables'} };

    for my $table_name ( @tables ) {
        my $tdata    =  $result->{'tables'}{ $table_name };
        next unless $tdata->{'table_name'};
        my $table    =  $schema->add_table(
            name     => $tdata->{'table_name'},
            comments => $tdata->{'comments'},
        ) or die $schema->error;

        $table->options( $tdata->{'table_options'} );

        my @fields = sort {
            $tdata->{'fields'}->{$a}->{'order'}
            <=>
            $tdata->{'fields'}->{$b}->{'order'}
        } keys %{ $tdata->{'fields'} };

        for my $fname ( @fields ) {
            my $fdata = $tdata->{'fields'}{ $fname };
            my $field = $table->add_field(
                name              => $fdata->{'name'},
                data_type         => $fdata->{'data_type'},
                size              => $fdata->{'size'},
                default_value     => $fdata->{'default'},
                is_auto_increment => $fdata->{'is_auto_inc'},
                is_nullable       => $fdata->{'null'},
                comments          => $fdata->{'comments'},
            ) or die $table->error;
        }

        push @{ $tdata->{'indices'} }, @{ $indices->{ $table_name } || [] };
        push @{ $tdata->{'constraints'} },
             @{ $constraints->{ $table_name } || [] };

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
                expression       => $cdata->{'expression'},
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

    my @procedures = sort {
        $result->{procedures}->{ $a }->{'order'} <=> $result->{procedures}->{ $b }->{'order'}
    } keys %{ $result->{procedures} };
    foreach my $proc_name (@procedures) {
      $schema->add_procedure(
         name  => $proc_name,
         owner => $result->{procedures}->{$proc_name}->{owner},
         sql   => $result->{procedures}->{$proc_name}->{sql},
      );
    }

    my @views = sort {
        $result->{views}->{ $a }->{'order'} <=> $result->{views}->{ $b }->{'order'}
    } keys %{ $result->{views} };
    foreach my $view_name (keys %{ $result->{views} }) {
      $schema->add_view(
         name => $view_name,
         sql  => $result->{views}->{$view_name}->{sql},
      );
    }

    return 1;
}

1;

# -------------------------------------------------------------------
# Something there is that doesn't love a wall.
# Robert Frost
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

SQL::Translator, Parse::RecDescent, DDL::Oracle.

=cut
