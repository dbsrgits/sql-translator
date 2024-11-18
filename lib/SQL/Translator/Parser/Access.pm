package SQL::Translator::Parser::Access;

=head1 NAME

SQL::Translator::Parser::Access - parser for Access as produced by mdbtools

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::Access;

  my $translator = SQL::Translator->new;
  $translator->parser("SQL::Translator::Parser::Access");

=head1 DESCRIPTION

The grammar derived from the MySQL grammar.  The input is expected to be
something similar to the output of mdbtools (http://mdbtools.sourceforge.net/).

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

{
    my ( %tables, $table_order, @table_comments );
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
    | use
    | set
    | drop
    | create
    | <error>

use : /use/i WORD ';'
    { @table_comments = () }

set : /set/i /[^;]+/ ';'
    { @table_comments = () }

drop : /drop/i TABLE /[^;]+/ ';'

drop : /drop/i WORD(s) ';'
    { @table_comments = () }

create : CREATE /database/i WORD ';'
    { @table_comments = () }

create : CREATE TABLE table_name '(' create_definition(s /,/) ')' ';'
    {
        my $table_name                       = $item{'table_name'};
        $tables{ $table_name }{'order'}      = ++$table_order;
        $tables{ $table_name }{'table_name'} = $table_name;

        if ( @table_comments ) {
            $tables{ $table_name }{'comments'} = [ @table_comments ];
            @table_comments = ();
        }

        my $i = 1;
        for my $definition ( @{ $item[5] } ) {
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

        1;
    }

create : CREATE UNIQUE(?) /(index|key)/i index_name /on/i table_name '(' field_name(s /,/) ')' ';'
    {
        @table_comments = ();
        push @{ $tables{ $item{'table_name'} }{'indices'} },
            {
                name   => $item[4],
                type   => $item[2] ? 'unique' : 'normal',
                fields => $item[8],
            }
        ;
    }

create_definition : constraint
    | index
    | field
    | comment
    | <error>

comment : /^\s*--(.*)\n/
    {
        my $comment =  $1;
        $return     = $comment;
        push @table_comments, $comment;
    }

field : field_name data_type field_qualifier(s?) reference_definition(?)
    {
        $return = {
            supertype   => 'field',
            name        => $item{'field_name'},
            data_type   => $item{'data_type'}{'type'},
            size        => $item{'data_type'}{'size'},
            constraints => $item{'reference_definition(?)'},
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
            character_set => $item[2],
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

on_update : /on update/i reference_option
    { $item[2] }

reference_option: /restrict/i |
    /cascade/i   |
    /set null/i  |
    /no action/i |
    /set default/i
    { $item[1] }

index : normal_index
    | fulltext_index
    | <error>

table_name   : NAME

field_name   : NAME

index_name   : NAME

data_type    : access_data_type parens_value_list(s?) type_qualifier(s?)
    {
        $return        = {
            type       => $item[1],
            size       => $item[2][0],
            qualifiers => $item[3],
        }
    }

access_data_type : /long integer/i { $return = 'Long Integer' }
    | /text/i { $return = 'Text' }
    | /datetime (\(short\))?/i { $return = 'DateTime' }
    | /boolean/i { $return = 'Boolean' }
    | WORD

parens_field_list : '(' field_name(s /,/) ')'
    { $item[2] }

parens_value_list : '(' VALUE(s /,/) ')'
    { $item[2] }

type_qualifier : /(BINARY|UNSIGNED|ZEROFILL)/i
    { lc $item[1] }

field_type   : WORD

create_index : /create/i /index/i

not_null     : /not/i /null/i { $return = 0 }

unsigned     : /unsigned/i { $return = 0 }

default_val : /default/i /'(?:.*?\')*.*?'|(?:')?[\w\d:.-]*(?:')?/
    {
        $item[2] =~ s/^\s*'|'\s*$//g;
        $return  =  $item[2];
    }

auto_inc : /auto_increment/i { 1 }

primary_key : /primary/i /key/i { 1 }

constraint : primary_key_def
    | unique_key_def
    | foreign_key_def
    | <error>

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

foreign_key_def_begin : /constraint/i /foreign key/i
    { $return = '' }
    |
    /constraint/i WORD /foreign key/i
    { $return = $item[2] }
    |
    /foreign key/i
    { $return = '' }

primary_key_def : primary_key index_name(?) '(' name_with_opt_paren(s /,/) ')'
    {
        $return       = {
            supertype => 'constraint',
            name      => $item{'index_name(?)'}[0],
            type      => 'primary_key',
            fields    => $item[4],
        };
    }

unique_key_def : UNIQUE KEY(?) index_name(?) '(' name_with_opt_paren(s /,/) ')'
    {
        $return       = {
            supertype => 'constraint',
            name      => $item{'index_name(?)'}[0],
            type      => 'unique',
            fields    => $item[5],
        }
    }

normal_index : KEY index_name(?) '(' name_with_opt_paren(s /,/) ')'
    {
        $return       = {
            supertype => 'index',
            type      => 'normal',
            name      => $item{'index_name(?)'}[0],
            fields    => $item[4],
        }
    }

fulltext_index : /fulltext/i KEY(?) index_name(?) '(' name_with_opt_paren(s /,/) ')'
    {
        $return       = {
            supertype => 'index',
            type      => 'fulltext',
            name      => $item{'index_name(?)'}[0],
            fields    => $item[5],
        }
    }

name_with_opt_paren : NAME parens_value_list(s?)
    { $item[2][0] ? "$item[1]($item[2][0][0])" : $item[1] }

UNIQUE : /unique/i { 1 }

KEY : /key/i | /index/i

table_option : WORD /\s*=\s*/ WORD
    {
        $return = { $item[1] => $item[3] };
    }

CREATE : /create/i

TEMPORARY : /temporary/i

TABLE : /table/i

WORD : /\w+/

DIGITS : /\d+/

COMMA : ','

NAME    : "`" /\w+/ "`"
    { $item[2] }
    | /\w+/
    { $item[1] }

VALUE   : /[-+]?\.?\d+(?:[eE]\d+)?/
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

  my $parser = ddl_parser_instance('Access');

  my $result = $parser->startrule($data);
  return $translator->error("Parse failed.") unless defined $result;
  warn Dumper($result) if $DEBUG;

  my $schema = $translator->schema;
  my @tables = sort { $result->{$a}->{'order'} <=> $result->{$b}->{'order'} }
      keys %{$result};

  for my $table_name (@tables) {
    my $tdata = $result->{$table_name};
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
    }

    for my $idata (@{ $tdata->{'indices'} || [] }) {
      my $index = $table->add_index(
        name   => $idata->{'name'},
        type   => uc $idata->{'type'},
        fields => $idata->{'fields'},
      ) or die $table->error;
    }
  }

  return 1;
}

1;

# -------------------------------------------------------------------
# Where man is not nature is barren.
# William Blake
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

perl(1), Parse::RecDescent, SQL::Translator::Schema.

=cut
