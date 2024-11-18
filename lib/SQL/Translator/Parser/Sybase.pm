package SQL::Translator::Parser::Sybase;

=head1 NAME

SQL::Translator::Parser::Sybase - parser for Sybase

=head1 SYNOPSIS

  use SQL::Translator::Parser::Sybase;

=head1 DESCRIPTION

Mostly parses the output of "dbschema.pl," a Perl script freely
available from http://www.midsomer.org.  The parsing is not complete,
however, and you would probably have much better luck using the
DBI-Sybase parser included with SQL::Translator.

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
    my ( %tables, @table_comments, $table_order );
}

startrule : statement(s) eofile { \%tables }

eofile : /^\Z/

statement : create_table
    | create_procedure
    | create_index
    | create_constraint
    | comment
    | use
    | setuser
    | if
    | print
    | grant
    | exec
    | <error>

use : /use/i WORD GO
    { @table_comments = () }

setuser : /setuser/i NAME GO

if : /if/i object_not_null begin if_command end GO

if_command : grant
    | create_index
    | create_constraint

object_not_null : /object_id/i '(' ident ')' /is not null/i

print : /\s*/ /print/i /.*/

else : /else/i /.*/

begin : /begin/i

end : /end/i

grant : /grant/i /[^\n]*/

exec : exec_statement(s) GO

exec_statement : /exec/i /[^\n]+/

comment : comment_start comment_middle comment_end
    {
        my $comment = $item[2];
        $comment =~ s/^\s*|\s*$//mg;
        $comment =~ s/^\**\s*//mg;
        push @table_comments, $comment;
    }

comment_start : /^\s*\/\*/

comment_end : /\s*\*\//

comment_middle : m{([^*]+|\*(?!/))*}

#
# Create table.
#
create_table : /create/i /table/i ident '(' create_def(s /,/) ')' lock(?) on_system(?) GO
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

create_constraint : /create/i constraint
    {
        @table_comments = ();
        push @{ $tables{ $item[2]{'table'} }{'constraints'} }, $item[2];
    }

create_index : /create/i index
    {
        @table_comments = ();
        push @{ $tables{ $item[2]{'table'} }{'indices'} }, $item[2];
    }

create_procedure : /create/i /procedure/i procedure_body GO
    {
        @table_comments = ();
    }

procedure_body : not_go(s)

not_go : /((?!go).)*/

create_def : field
    | index
    | constraint

blank : /\s*/

field : field_name data_type nullable(?)
    {
        $return = {
            supertype      => 'field',
            name           => $item{'field_name'},
            data_type      => $item{'data_type'}{'type'},
            size           => $item{'data_type'}{'size'},
            nullable       => $item[3][0],
#            default        => $item{'default_val'}[0],
#            is_auto_inc    => $item{'auto_inc'}[0],
#            is_primary_key => $item{'primary_key'}[0],
        }
    }

constraint : primary_key_constraint
    | unique_constraint

field_name : WORD

index_name : WORD

table_name : WORD

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

default_val : /default/i /(?:')?[\w\d.-]*(?:')?/
    { $item[2]=~s/'//g; $return=$item[2] }

auto_inc : /auto_increment/i { 1 }

primary_key_constraint : /primary/i /key/i index_name(?) parens_field_list
    {
        $return = {
            supertype => 'constraint',
            name      => $item{'index_name'}[0],
            type      => 'primary_key',
            fields    => $item[4],
        }
    }

unique_constraint : /unique/i clustered(?) INDEX(?) index_name(?) on_table(?) parens_field_list
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

clustered : /clustered/i
    { $return = 1 }
    | /nonclustered/i
    { $return = 0 }

INDEX : /index/i

on_table : /on/i table_name
    { $return = $item[2] }

on_system : /on/i /system/i
    { $return = 1 }

index : clustered(?) INDEX index_name(?) on_table(?) parens_field_list
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

ident : QUOTE(?) WORD '.' WORD QUOTE(?)
    { $return = { owner => $item[2], name => $item[4] } }
    | WORD
    { $return = { name  => $item[2] } }

GO : /^go/i

NAME : QUOTE(?) /\w+/ QUOTE(?)
    { $item[2] }

WORD : /[\w#]+/

DIGITS : /\d+/

COMMA : ','

QUOTE : /'/

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

  my $parser = ddl_parser_instance('Sybase');

  my $result = $parser->startrule($data);
  return $translator->error("Parse failed.") unless defined $result;
  warn Dumper($result) if $DEBUG;

  my $schema = $translator->schema;
  my @tables = sort { $result->{$a}->{'order'} <=> $result->{$b}->{'order'} }
      keys %{$result};

  for my $table_name (@tables) {
    my $tdata = $result->{$table_name};
    my $table = $schema->add_table(name => $tdata->{'name'})
        or die "Can't create table '$table_name': ", $schema->error;

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
        is_nullable       => $fdata->{'nullable'},
        comments          => $fdata->{'comments'},
      ) or die $table->error;

      $table->primary_key($field->name) if $fdata->{'is_primary_key'};

      for my $qual (qw[ binary unsigned zerofill list ]) {
        if (my $val = $fdata->{$qual} || $fdata->{ uc $qual }) {
          next if ref $val eq 'ARRAY' && !@$val;
          $field->extra($qual, $val);
        }
      }

      if ($field->data_type =~ /(set|enum)/i && !$field->size) {
        my %extra   = $field->extra;
        my $longest = 0;
        for my $len (map {length} @{ $extra{'list'} || [] }) {
          $longest = $len if $len > $longest;
        }
        $field->size($longest) if $longest;
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

    for my $cdata (@{ $tdata->{'constraints'} || [] }) {
      my $constraint = $table->add_constraint(
        name             => $cdata->{'name'},
        type             => $cdata->{'type'},
        fields           => $cdata->{'fields'},
        reference_table  => $cdata->{'reference_table'},
        reference_fields => $cdata->{'reference_fields'},
        match_type       => $cdata->{'match_type'} || '',
        on_delete        => $cdata->{'on_delete'}  || $cdata->{'on_delete_do'},
        on_update        => $cdata->{'on_update'}  || $cdata->{'on_update_do'},
      ) or die $table->error;
    }
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

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

SQL::Translator, SQL::Translator::Parser::DBI, L<http://www.midsomer.org/>.

=cut
