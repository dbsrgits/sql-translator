package SQL::Translator::Parser::MySQL;

# -------------------------------------------------------------------
# $Id: MySQL.pm,v 1.18 2003-05-09 19:51:04 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>,
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
  or      AUTO_INCREMENT = #
  or      AVG_ROW_LENGTH = #
  or      CHECKSUM = {0 | 1}
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

=cut

use strict;
use vars qw[ $DEBUG $VERSION $GRAMMAR @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.18 $ =~ /(\d+)\.(\d+)/;
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

{ 
    our ( %tables, $table_order );
}

#
# The "eofile" rule makes the parser fail if any "statement" rule
# fails.  Otherwise, the first successful match by a "statement" 
# won't cause the failure needed to know that the parse, as a whole,
# failed. -ky
#
startrule : statement(s) eofile { \%tables }

eofile : /^\Z/

statement : comment
    | drop
    | create
    | <error>

drop : /drop/i WORD(s) ';'

create : create_table table_name '(' create_definition(s /,/) ')' table_option(s?) ';'
    { 
        my $table_name                       = $item{'table_name'};
        $tables{ $table_name }{'order'}      = ++$table_order;
        $tables{ $table_name }{'table_name'} = $table_name;

        my $i = 1;
        for my $definition ( @{ $item[4] } ) {
            if ( $definition->{'type'} eq 'field' ) {
                my $field_name = $definition->{'name'};
                $tables{ $table_name }{'fields'}{ $field_name } = 
                    { %$definition, order => $i };
                $i++;
        
                if ( $definition->{'is_primary_key'} ) {
                    push @{ $tables{ $table_name }{'indices'} },
                        {
                            type   => 'primary_key',
                            fields => [ $field_name ],
                        }
                    ;
                }
            }
            else {
                push @{ $tables{ $table_name }{'indices'} },
                    $definition;
            }
        }

        for my $opt ( @{ $item{'table_option(s?)'} } ) {
            if ( my ( $key, $val ) = each %$opt ) {
                $tables{ $table_name }{'table_options'}{ $key } = $val;
            }
        }

        1;
    }

create : /CREATE/i unique(?) /(INDEX|KEY)/i index_name /on/i table_name '(' field_name(s /,/) ')' ';'
    {
        push @{ $tables{ $item{'table_name'} }{'indices'} },
            {
                name   => $item[4],
                type   => $item[2] ? 'unique' : 'normal',
                fields => $item[8],
            }
        ;
    }

create_definition : index
    | field
    | <error>

comment : /^\s*(?:#|-{2}).*\n/

blank : /\s*/

field : field_name data_type field_qualifier(s?) reference_definition(?)
    { 
        my %qualifiers = map { %$_ } @{ $item{'field_qualifier(s?)'} || [] };
        my $null = defined $item{'not_null'} ? $item{'not_null'} : 1;
        delete $qualifiers{'not_null'};
        if ( my @type_quals = @{ $item{'data_type'}{'qualifiers'} || [] } ) {
            $qualifiers{ $_ } = 1 for @type_quals;
        }

        $return = { 
            type           => 'field',
            name           => $item{'field_name'}, 
            data_type      => $item{'data_type'}{'type'},
            size           => $item{'data_type'}{'size'},
            list           => $item{'data_type'}{'list'},
            null           => $null,
            constraints    => $item{'reference_definition(?)'},
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

reference_definition : /references/i table_name parens_field_list(?) match_type(?) on_delete_do(?) on_update_do(?)
    {
        $return              =  {
            type             => 'foreign_key',
            reference_table  => $item[2],
            reference_fields => $item[3][0],
            match_type       => $item[4][0],
            on_delete_do     => $item[5][0],
            on_update_do     => $item[6][0],
        }
    }

match_type : /match full/i { 'match_full' }
    |
    /match partial/i { 'match_partial' }

on_delete_do : /on delete/i reference_option
    { $item[2] }

on_update_do : /on update/i reference_option
    { $item[2] }

reference_option: /restrict/i | 
    /cascade/i   | 
    /set null/i  | 
    /no action/i | 
    /set default/i
    { $item[1] }  

index : primary_key_index
    | unique_index
    | fulltext_index
    | normal_index
    | <error>

table_name   : WORD

field_name   : WORD

index_name   : WORD

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

field_size   : '(' num_range ')' { $item{'num_range'} }

num_range    : DIGITS ',' DIGITS
    { $return = $item[1].','.$item[3] }
    | DIGITS
    { $return = $item[1] }

create_table : /create/i /table/i

create_index : /create/i /index/i

not_null     : /not/i /null/i { $return = 0 }

unsigned     : /unsigned/i { $return = 0 }

default_val  : /default/i /(?:')?[\w\d:.-]*(?:')?/ 
    { 
        $item[2] =~ s/'//g; 
        $return  =  $item[2];
    }

auto_inc : /auto_increment/i { 1 }

primary_key : /primary/i /key/i { 1 }

primary_key_index : primary_key index_name(?) '(' field_name(s /,/) ')'
    { 
        $return    = { 
            name   => $item{'index_name(?)'}[0],
            type   => 'primary_key',
            fields => $item[4],
        };
    }

normal_index : key index_name(?) '(' name_with_opt_paren(s /,/) ')'
    { 
        $return    = { 
            name   => $item{'index_name(?)'}[0],
            type   => 'normal',
            fields => $item[4],
        } 
    }

unique_index : unique key(?) index_name(?) '(' name_with_opt_paren(s /,/) ')'
    { 
        $return    = { 
            name   => $item{'index_name(?)'}[0],
            type   => 'unique',
            fields => $item[5],
        } 
    }

fulltext_index : fulltext key(?) index_name(?) '(' name_with_opt_paren(s /,/) ')'
    { 
        $return    = { 
            name   => $item{'index_name(?)'}[0],
            type   => 'fulltext',
            fields => $item[5],
        } 
    }

name_with_opt_paren : NAME parens_value_list(s?)
    { $item[2][0] ? "$item[1]($item[2][0][0])" : $item[1] }

fulltext : /fulltext/i { 1 }

unique : /unique/i { 1 }

key : /key/i | /index/i

table_option : /[^\s;]*/ 
    { 
        $return = { split /=/, $item[1] }
    }

WORD : /\w+/

DIGITS : /\d+/

COMMA : ','

NAME    : "`" /\w+/ "`"
    { $item[2] }
    | /\w+/
    { $item[1] }

VALUE   : /[-+]?\.?\d+(?:[eE]\d+)?/
    { $item[1] }
    | /'.*?'/   # XXX doesn't handle embedded quotes
    { $item[1] }
    | /NULL/
    { 'NULL' }
#    {
#        {
#            value     => $item[1],
#            attribute => $item[2]
#        }
#    }

!;

# -------------------------------------------------------------------
sub parse {
    my ( $translator, $data ) = @_;
    $parser ||= Parse::RecDescent->new($GRAMMAR);

    local $::RD_TRACE  = $translator->trace ? 1 : undef;
    local $DEBUG       = $translator->debug;

    unless (defined $parser) {
        return $translator->error("Error instantiating Parse::RecDescent ".
            "instance: Bad grammer");
    }

    my $result = $parser->startrule($data);
    die "Parse failed.\n" unless defined $result;
    warn Dumper( $result ) if $DEBUG;

    my $schema = $translator->schema;
    for my $table_name ( keys %{ $result } ) {
        my $tdata =  $result->{ $table_name };
        my $table =  $schema->add_table( 
            name  => $tdata->{'table_name'},
        );

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
            );
        }
    }

    return $result;
}

1;

# ----------------------------------------------------
# Where man is not nature is barren.
# William Blake
# ----------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>,
Chris Mungall E<lt>cjm@fruitfly.orgE<gt>.

=head1 SEE ALSO

perl(1), Parse::RecDescent, SQL::Translator::Schema.

=cut
