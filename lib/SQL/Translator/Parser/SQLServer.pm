package SQL::Translator::Parser::SQLServer;

=head1 NAME

SQL::Translator::Parser::SQLServer - parser for SQL Server

=head1 SYNOPSIS

  use SQL::Translator::Parser::SQLServer;

=head1 DESCRIPTION

Adapted from Parser::Sybase and mostly parses the output of
Producer::SQLServer.  The parsing is by no means complete and
should probably be considered a work in progress.

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
    my ( %tables, @table_comments, $table_order, %procedures, $proc_order, %views, $view_order );

    sub _err {
      my $max_lines = 5;
      my @up_to_N_lines = split (/\n/, $_[1], $max_lines + 1);
      die sprintf ("Unable to parse line %d:\n%s\n",
        $_[0],
        join "\n", (map { "'$_'" } @up_to_N_lines[0..$max_lines - 1 ]), @up_to_N_lines > $max_lines ? '...' : ()
      );
    }

}

startrule : statement(s) eofile
   {
      return {
         tables     => \%tables,
         procedures => \%procedures,
         views      => \%views,
      }
   }

eofile : /^\Z/

statement : create_table
    | create_procedure
    | create_view
    | create_index
    | create_constraint
    | comment
    | disable_constraints
    | drop
    | use
    | setuser
    | if
    | print
    | grant
    | exec
    | /^\Z/ | { _err ($thisline, $text) }

use : /use/i WORD GO
    { @table_comments = () }

setuser : /setuser/i NAME GO

if : /if/i object_not_null begin if_command end GO

if_command : grant
    | create_index
    | create_constraint

object_not_null : /object_id/i '(' ident ')' /is not null/i

field_not_null : /where/i field_name /is \s+ not \s+ null/ix

print : /\s*/ /print/i /.*/

else : /else/i /.*/

begin : /begin/i

end : /end/i

grant : /grant/i /[^\n]*/

exec : exec_statement(s) GO

exec_statement : /exec/i /[^\n]+/

comment : /^\s*(?:#|-{2}).*\n/
    {
        my $comment =  $item[1];
        $comment    =~ s/^\s*(#|--)\s*//;
        $comment    =~ s/\s*$//;
        $return     = $comment;
        push @table_comments, $comment;
    }

comment : comment_start comment_middle comment_end
    {
        my $comment = $item[2];
        $comment =~ s/^\s*|\s*$//mg;
        $comment =~ s/^\**\s*//mg;
        push @table_comments, $comment;
    }

comment_start : m#^\s*\/\*#

comment_end : m#\s*\*\/#

comment_middle : m{([^*]+|\*(?!/))*}

drop : if_exists(?) /drop/i tbl_drop END_STATEMENT

tbl_drop : /table/i ident

if_exists : /if exists/i '(' /select/i 'name' /from/i 'sysobjects' /[^\)]+/ ')'

#
# Create table.
#
create_table : /create/i /table/i ident '(' create_def(s /,/) ')' lock(?) on_system(?) END_STATEMENT
    {
        my $table_owner = $item[3]{'owner'};
        my $table_name  = $item[3]{'name'};

        if ( @table_comments ) {
            $tables{ $table_name }{'comments'} = [ @table_comments ];
            @table_comments = ();
        }

        $tables{ $table_name }{'order'}  = ++$table_order;
        $tables{ $table_name }{'name'}   = $table_name;
        $tables{ $table_name }{'owner'}  = $table_owner;
        $tables{ $table_name }{'system'} = $item[7];

        my $i = 0;
        for my $def ( @{ $item[5] } ) {
            if ( $def->{'supertype'} eq 'field' ) {
                my $field_name = $def->{'name'};
                $tables{ $table_name }{'fields'}{ $field_name } =
                    { %$def, order => $i };
                $i++;

                if ( $def->{'is_primary_key'} ) {
                    push @{ $tables{ $table_name }{'constraints'} }, {
                        type   => 'primary_key',
                        fields => [ $field_name ],
                    };
                }
            }
            elsif ( $def->{'supertype'} eq 'constraint' ) {
                push @{ $tables{ $table_name }{'constraints'} }, $def;
            }
            else {
                push @{ $tables{ $table_name }{'indices'} }, $def;
            }
        }
    }

disable_constraints : if_exists(?) /alter/i /table/i ident /nocheck/i /constraint/i /all/i END_STATEMENT

# this is for the normal case
create_constraint : /create/i constraint END_STATEMENT
    {
        @table_comments = ();
        push @{ $tables{ $item[2]{'table'} }{'constraints'} }, $item[2];
    }

# and this is for the BEGIN/END case
create_constraint : /create/i constraint
    {
        @table_comments = ();
        push @{ $tables{ $item[2]{'table'} }{'constraints'} }, $item[2];
    }


create_constraint : /alter/i /table/i ident /add/i foreign_key_constraint END_STATEMENT
    {
        push @{ $tables{ $item[3]{name} }{constraints} }, $item[5];
    }


create_index : /create/i index
    {
        @table_comments = ();
        push @{ $tables{ $item[2]{'table'} }{'indices'} }, $item[2];
    }

create_procedure : /create/i PROCEDURE WORD not_go GO
    {
        @table_comments = ();
        my $proc_name = $item[3];
        my $owner = '';
        my $sql = "$item[1] $item[2] $proc_name $item[4]";

        $procedures{ $proc_name }{'order'}  = ++$proc_order;
        $procedures{ $proc_name }{'name'}   = $proc_name;
        $procedures{ $proc_name }{'owner'}  = $owner;
        $procedures{ $proc_name }{'sql'}    = $sql;
    }

create_procedure : /create/i PROCEDURE '[' WORD '].' WORD not_go GO
    {
        @table_comments = ();
        my $proc_name = $item[6];
        my $owner = $item[4];
        my $sql = "$item[1] $item[2] [$owner].$proc_name $item[7]";

        $procedures{ $proc_name }{'order'}  = ++$proc_order;
        $procedures{ $proc_name }{'name'}   = $proc_name;
        $procedures{ $proc_name }{'owner'}  = $owner;
        $procedures{ $proc_name }{'sql'}    = $sql;
    }

PROCEDURE : /procedure/i
   | /function/i

create_view : /create/i /view/i WORD not_go GO
    {
        @table_comments = ();
        my $view_name = $item[3];
        my $sql = "$item[1] $item[2] $item[3] $item[4]";

        $views{ $view_name }{'order'}  = ++$view_order;
        $views{ $view_name }{'name'}   = $view_name;
        $views{ $view_name }{'sql'}    = $sql;
    }

not_go : /((?!\bgo\b).)*/is

create_def : constraint
    | index
    | field

blank : /\s*/

field : field_name data_type field_qualifier(s?)
    {
        my %qualifiers  = map { %$_ } @{ $item{'field_qualifier(s?)'} || [] };
        my $nullable = defined $qualifiers{'nullable'}
                   ? $qualifiers{'nullable'} : 1;
        $return = {
            supertype      => 'field',
            name           => $item{'field_name'},
            data_type      => $item{'data_type'}{'type'},
            size           => $item{'data_type'}{'size'},
            nullable       => $nullable,
            default        => $qualifiers{'default_val'},
            is_auto_inc    => $qualifiers{'is_auto_inc'},
#            is_primary_key => $item{'primary_key'}[0],
        }
    }

field_qualifier : nullable
    {
        $return = {
             nullable => $item{'nullable'},
        }
    }

field_qualifier : default_val
    {
        $return = {
             default_val => $item{'default_val'},
        }
    }

field_qualifier : auto_inc
    {
        $return = {
             is_auto_inc => $item{'auto_inc'},
        }
    }

constraint : primary_key_constraint
    | foreign_key_constraint
    | unique_constraint

field_name : WORD
   { $return = $item[1] }
   | LQUOTE WORD RQUOTE
   { $return = $item[2] }

index_name : WORD
   { $return = $item[1] }
   | LQUOTE WORD RQUOTE
   { $return = $item[2] }

table_name : WORD
 { $return = $item[1] }
 | LQUOTE WORD RQUOTE
 { $return = $item[2] }

data_type : WORD field_size(?)
    {
        $return = {
            type => $item[1],
            size => $item[2][0]
        }
    }

lock : /lock/i /datarows/i

field_type : WORD

field_size : '(' num_range ')' { $item{'num_range'} }

num_range : DIGITS ',' DIGITS
    { $return = $item[1].','.$item[3] }
               | DIGITS
    { $return = $item[1] }


nullable : /not/i /null/i
    { $return = 0 }
    | /null/i
    { $return = 1 }

default_val : /default/i /null/i
    { $return = 'null' }
   | /default/i /'[^']*'/
    { $item[2]=~ s/'//g; $return = $item[2] }
   | /default/i WORD
    { $return = $item[2] }

auto_inc : /identity/i { 1 }

primary_key_constraint : /constraint/i index_name(?) /primary/i /key/i parens_field_list
    {
        $return = {
            supertype => 'constraint',
            name      => $item[2][0],
            type      => 'primary_key',
            fields    => $item[5],
        }
    }

foreign_key_constraint : /constraint/i index_name(?) /foreign/i /key/i parens_field_list /references/i table_name parens_field_list(?) on_delete(?) on_update(?)
    {
        $return = {
            supertype        => 'constraint',
            name             => $item[2][0],
            type             => 'foreign_key',
            fields           => $item[5],
            reference_table  => $item[7],
            reference_fields => $item[8][0],
            on_delete        => $item[9][0],
            on_update        => $item[10][0],
        }
    }

unique_constraint : /constraint/i index_name(?) /unique/i parens_field_list
    {
        $return = {
            supertype => 'constraint',
            type      => 'unique',
            name      => $item[2][0],
            fields    => $item[4],
        }
    }

unique_constraint : /unique/i clustered(?) INDEX(?) index_name(?) on_table(?) parens_field_list field_not_null(?)
    {
        $return = {
            supertype => 'constraint',
            type      => 'unique',
            clustered => $item[2][0],
            name      => $item[4][0],
            table     => $item[5][0],
            fields    => $item[6],
        }
    }

on_delete : /on delete/i reference_option
    { $item[2] }

on_update : /on update/i reference_option
    { $item[2] }

reference_option: /cascade/i
    { $item[1] }
    | /no action/i
    { $item[1] }

clustered : /clustered/i
    { $return = 1 }
    | /nonclustered/i
    { $return = 0 }

INDEX : /index/i

on_table : /on/i table_name
    { $return = $item[2] }

on_system : /on/i /system/i
    { $return = 1 }

index : clustered(?) INDEX index_name(?) on_table(?) parens_field_list END_STATEMENT
    {
        $return = {
            supertype => 'index',
            type      => 'normal',
            clustered => $item[1][0],
            name      => $item[3][0],
            table     => $item[4][0],
            fields    => $item[5],
        }
    }

parens_field_list : '(' field_name(s /,/) ')'
    { $item[2] }

ident : QUOTE WORD '.' WORD QUOTE | LQUOTE WORD '.' WORD RQUOTE
    { $return = { owner => $item[2], name => $item[4] } }
    | LQUOTE WORD RQUOTE '.' LQUOTE WORD RQUOTE
    { $return = { owner => $item[2], name => $item[6] } }
    | LQUOTE WORD RQUOTE
    { $return = { name  => $item[2] } }
    | WORD '.' WORD
    { $return = { owner => $item[1], name => $item[3] } }
    | WORD
    { $return = { name  => $item[1] } }

END_STATEMENT : ';'
   | GO

GO : /^go/i

NAME : QUOTE(?) /\w+/ QUOTE(?)
    { $item[2] }

WORD : /[\w#]+/

DIGITS : /\d+/

COMMA : ','

QUOTE : /'/

LQUOTE : '['

RQUOTE : ']'

END_OF_GRAMMAR

sub parse {
    my ( $translator, $data ) = @_;

    # Enable warnings within the Parse::RecDescent module.
    local $::RD_ERRORS = 1 unless defined $::RD_ERRORS; # Make sure the parser dies when it encounters an error
    local $::RD_WARN   = 1 unless defined $::RD_WARN; # Enable warnings. This will warn on unused rules &c.
    local $::RD_HINT   = 1 unless defined $::RD_HINT; # Give out hints to help fix problems.

    local $::RD_TRACE  = $translator->trace ? 1 : undef;
    local $DEBUG       = $translator->debug;

    my $parser = ddl_parser_instance('SQLServer');

    my $result = $parser->startrule($data);
    return $translator->error( "Parse failed." ) unless defined $result;
    warn Dumper( $result ) if $DEBUG;

    my $schema = $translator->schema;
    my @tables = sort {
        $result->{tables}->{ $a }->{'order'} <=> $result->{tables}->{ $b }->{'order'}
    } keys %{ $result->{tables} };

    for my $table_name ( @tables ) {
        my $tdata = $result->{tables}->{ $table_name };
        my $table = $schema->add_table( name => $tdata->{'name'} )
                    or die "Can't create table '$table_name': ", $schema->error;

        $table->comments( $tdata->{'comments'} );

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
                is_nullable       => $fdata->{'nullable'},
                comments          => $fdata->{'comments'},
            ) or die $table->error;

            $table->primary_key( $field->name ) if $fdata->{'is_primary_key'};

            for my $qual ( qw[ binary unsigned zerofill list ] ) {
                if ( my $val = $fdata->{ $qual } || $fdata->{ uc $qual } ) {
                    next if ref $val eq 'ARRAY' && !@$val;
                    $field->extra( $qual, $val );
                }
            }

            if ( $field->data_type =~ /(set|enum)/i && !$field->size ) {
                my %extra = $field->extra;
                my $longest = 0;
                for my $len ( map { length } @{ $extra{'list'} || [] } ) {
                    $longest = $len if $len > $longest;
                }
                $field->size( $longest ) if $longest;
            }

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

    my @procedures = sort {
        $result->{procedures}->{ $a }->{'order'} <=> $result->{procedures}->{ $b }->{'order'}
    } keys %{ $result->{procedures} };
    for my $proc_name (@procedures) {
      $schema->add_procedure(
         name  => $proc_name,
         owner => $result->{procedures}->{$proc_name}->{owner},
         sql   => $result->{procedures}->{$proc_name}->{sql},
      );
    }

    my @views = sort {
        $result->{views}->{ $a }->{'order'} <=> $result->{views}->{ $b }->{'order'}
    } keys %{ $result->{views} };
    for my $view_name (keys %{ $result->{views} }) {
      $schema->add_view(
         name => $view_name,
         sql  => $result->{views}->{$view_name}->{sql},
      );
    }

    return 1;
}

1;

# -------------------------------------------------------------------
# Every hero becomes a bore at last.
# Ralph Waldo Emerson
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Chris Hilton E<lt>chris@dctank.comE<gt> - Bulk of code from
Sybase parser, I just tweaked it for SQLServer. Thanks.

=head1 SEE ALSO

SQL::Translator, SQL::Translator::Parser::DBI, L<http://www.midsomer.org/>.

=cut
