package SQL::Translator::Parser::Oracle;

# -------------------------------------------------------------------
# $Id: Oracle.pm,v 1.1 2003-04-10 03:09:28 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>
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
   table_constraint
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

=cut

use strict;
use vars qw[ $DEBUG $VERSION $GRAMMAR @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;
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

my $parser; 

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
  | comment_on_table
  | comment_on_column
  | <error>

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

                for my $constraint ( @{ $definition->{'constraints'} || [] } ) {
                    $constraint->{'fields'} = [ $field_name ];
                    push @{ $tables{ $table_name }{'constraints'} }, 
                        $constraint;
                }
            }
            elsif ( $definition->{'type'} eq 'constraint' ) {
                $definition->{'type'} = $definition->{'constraint_type'};
                # group FKs at the field level
                if ( $definition->{'type'} eq 'foreign_key' ) {
                    for my $fld ( @{ $definition->{'fields'} || [] } ) {
                        push @{ 
                            $tables{$table_name}{'fields'}{$fld}{'constraints'}
                        }, $definition;
                    }
                }
                else {
                    push @{ $tables{ $table_name }{'constraints'} }, 
                        $definition;
                }
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

# Create anything else (e.g., domain, function, etc.)
create : /create/i WORD /[^;]+/ ';'

global_temporary: /global/i /temporary/i

table_name : NAME '.' NAME
    { $item[3] }
    | NAME 
    { $item[1] }

create_definition : field
    | table_constraint
    | <error>

comment : /^\s*(?:#|-{2}).*\n/

comment_on_table : /comment/i /on/i /table/i table_name /is/i phrase ';'
    {
        push @{ $tables{ $item{'table_name'} }{'comments'} }, $item[7];
    }

comment_on_column : /comment/i /on/i /column/i column_name /is/i phrase ';'
    {
        my $table_name = $item[4]->{'table'};
        my $field_name = $item[4]->{'field'};
        push @{ $tables{ $table_name }{'fields'}{ $field_name }{'comments'} }, 
            $item[7];
    }

column_name : NAME '.' NAME
    { $return = { table => $item[1], field => $item[3] } }

phrase : /'.*?'/ { $item[1] }

field : comment(s?) field_name data_type field_meta(s?) comment(s?)
    {
        my ( $default, @constraints );
        for my $meta ( @{ $item[4] } ) {
            $default = $meta if $meta->{'meta_type'} eq 'default';
            push @constraints, $meta if $meta->{'meta_type'} eq 'constraint';
        }

        my $null = ( grep { $_->{'type'} eq 'not_null' } @constraints ) ? 0 : 1;

        $return = { 
            type           => 'field',
            name           => $item{'field_name'}, 
            data_type      => $item{'data_type'}{'type'},
            size           => $item{'data_type'}{'size'},
            list           => $item{'data_type'}{'list'},
            null           => $null,
            default        => $default->{'value'},
            constraints    => [ @constraints ],
        } 
    }
    | <error>

field_name : NAME

data_type : ora_data_type parens_value_list(?)
    { 
        $return  = { 
            type => $item[1],
            size => $item[2][0] || '',
        } 
    }

column_constraint : constraint_name(?) column_constraint_type 
#constraint_state(s /,/)
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
#            match_type       => $desc->{'match_type'},
#            on_update_do     => $desc->{'on_update_do'},
        } 
    }

constraint_name : /constraint/i NAME { $item[2] }

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
    /references/i table_name parens_word_list(?) on_delete_do(?) 
    {
        $return              =  {
            type             => 'foreign_key',
            reference_table  => $item[2],
            reference_fields => $item[3][0],
#            match_type       => $item[4][0],
            on_delete_do     => $item[5][0],
        }
    }

#constraint_state : deferrable { $return = { type => $item[1] } }
#    | deferred { $return = { type => $item[1] } }
#    | /(no)?rely/ { $return = { type => $item[1] } }
#    | /using/i /index/i using_index_clause 
#        { $return = { type => 'using_index', index => $item[3] }
#    | (dis)?enable { $return = { type => $item[1] } }
#    | (no)?validate { $return = { type => $item[1] } }
#    | /exceptions/i /into/i table_name 
#        { $return = { type => 'exceptions_into', table => $item[3] } }

deferrable : /not/i /deferrable/i 
    { $return = 'not_deferrable' }
    | /deferrable/i 
    { $return = 'deferrable' }

deferred : /initially/i /(deferred|immediate)/i { $item[2] }

ora_data_type :
    /(n?varchar2|varchar)/i { $return = 'varchar' }
    |
    /n?char/i { $return = 'character' }
    |
    /number/i { $return = 'number' }
    |
    /(pls_integer|binary_integer)/i { $return = 'integer' }
    |
    /interval\s+day/i { $return = 'interval_day' }
    |
    /interval\s+year/i { $return = 'interval_year' }
    |
    /long\s+raw/i { $return = 'long_raw' }
    |
    /(long|date|timestamp|raw|rowid|urowid|mlslabel|clob|nclob|blob|bfile)/i { $item[1] }

parens_value_list : '(' VALUE(s /,/) ')'
    { $item[2] }

parens_word_list : '(' WORD(s /,/) ')'
    { $item[2] }

field_meta : default_val
    |
    column_constraint

default_val  : /default/i /(?:')?[\w\d.-]*(?:')?/ 
    { 
        my $val =  $item[2] || '';
        $val    =~ s/'//g; 
        $return =  {
            meta_type => 'default',
            value     => $val,
        }
    }

create_table : /create/i global_temporary(?) /table/i

table_option : /[^;]+/

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
#            match_type       => $desc->{'match_type'}[0],
            on_delete_do     => $desc->{'on_delete_do'},
            on_update_do     => $desc->{'on_update_do'},
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
    /check/ '(' /(.+)/ ')'
    {
        $return        =  {
            type       => 'check',
            expression => $item[3],
        }
    }
    |
    /foreign key/i '(' NAME(s /,/) ')' /references/i table_name parens_word_list(?) on_delete_do(?)
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

on_delete_do : /on delete/i WORD(s)
    { $item[2] }

WORD : /\w+/

NAME : /\w+/ { $item[1] }

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

    local $::RD_TRACE = $translator->trace ? 1 : undef;
    local $DEBUG      = $translator->debug;

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

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

perl(1), Parse::RecDescent.

=cut
