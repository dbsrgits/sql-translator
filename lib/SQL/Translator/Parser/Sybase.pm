package SQL::Translator::Parser::Sybase;

# -------------------------------------------------------------------
# $Id: Sybase.pm,v 1.3 2002-11-22 03:03:40 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2002 Ken Y. Clark <kclark@cpan.org>,
#                    darren chamberlain <darren@cpan.org>
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

SQL::Translator::Parser::Sybase - parser for Sybase

=head1 SYNOPSIS

  use SQL::Translator::Parser::Sybase;

=head1 DESCRIPTION

Parses the output of "dbschema.pl," a Perl script freely available from
www.midsomer.org.

=cut

my $grammar = q{

    { our ( %tables ) }

    file         : statement(s) { \%tables }
#        { print "statements: ", join("\n", @{$item[1]}), "\n" }
#                   | <error>

    statement    : create
                   | junk
#        { 
#            print "statement: ", join("\n", @{$item[1]}), "\n";
#            $return = @{$item[1]};
#            print "statement: '", $item[1], "'\n";
#            $return = $item[1];
#        }
                   | <error>

    junk         : comment 
                   | use
                   | setuser
                   | if
                   | print
                   | else
                   | begin
                   | end
                   | grant
                   | exec
                   | GO

    GO           : /go/
#        { print "GO: ", $item[1], "\n" }

    use          : /use/i /.*/
#        { print "USE: ", $item[2], "\n" }

    setuser      : /setuser/i /.*/
#        { print "SETUSER: ", $item[2], "\n" }

    if           : /if/i /.*/
#        { print "IF: ", $item[2], "\n" }

    print        : /\s*/ /print/i /.*/
#       { print "PRINT: ", $item[3], "\n" }

    else        : /else/i /.*/
#        { print "ELSE: ", $item[2], "\n" }

    begin       : /begin/i
#        { print "BEGIN\n" }

    end         : /end/i
#        { print "END\n" }

    grant       : /grant/i /.*/
#        { print "GRANT: ", $item[2], "\n" }

    exec        : /exec/i /.*/
#        { print "EXEC: ", $item[2], "\n" }

    comment      : /^\s*\/\*.*\*\//m
#        { print "COMMENT: ", $item[-1], "\n" }

    create       : create_table table_name '(' field(s /,/) ')' lock(?)
                { 
#                    print "TABLE $item[2]: ", 
#                        join(', ', map{$_->{'name'}}@{$item[4]}), "\n";
                    my $i = 0;
                    for my $line ( @{ $item[4] } ) {
                        if ( $line->{'type'} eq 'field' ) {
                            my $field_name = $line->{'name'};
                            $tables{ $item{'table_name'} }
                                {'fields'}{$field_name} = 
                                { %$line, order => $i };
                            $i++;
                    
                            if ( $line->{'is_primary_key'} ) {
                                push
                                @{ $tables{ $item{'table_name'} }{'indices'} },
                                {
                                    type   => 'primary_key',
                                    fields => [ $field_name ],
                                };
                            }
                        }
                        else {
                            push @{ $tables{ $item{'table_name'} }{'indices'} },
                                $line;
                        }
                        $tables{ $item{'table_name'} }{'type'} = 
                            $item{'table_type'}[0];
                    }
                }
                   | <error>

    blank        : /\s*/

    field        : field_name data_type null(?) 
                   { 
                        $return = { 
                            type           => 'field',
                            name           => $item{'field_name'}, 
                            data_type      => $item{'data_type'}{'type'},
                            size           => $item{'data_type'}{'size'},
                            null           => $item{'null'}[0], 
#                            default        => $item{'default_val'}[0], 
#                            is_auto_inc    => $item{'auto_inc'}[0], 
#                            is_primary_key => $item{'primary_key'}[0], 
                       } 
                   }
                | <error>

    index        : primary_key_index
                   | unique_index
                   | normal_index

    table_name   : WORD '.' WORD
        { $return = $item[3] }

    field_name   : WORD

    index_name   : WORD

    data_type    : WORD field_size(?) 
        { 
            $return = { 
                type => $item[1], 
                size => $item[2][0]
            } 
        }

    lock         : /lock/i /datarows/i

    field_type   : WORD

    field_size   : '(' num_range ')' { $item{'num_range'} }

    num_range    : DIGITS ',' DIGITS
        { $return = $item[1].','.$item[3] }
                   | DIGITS
        { $return = $item[1] }


    create_table : /create/i /table/i

    null         : /not/i /null/i
        { $return = 0 }
                   | /null/i
        { $return = 1 }

    default_val  : /default/i /(?:')?[\w\d.-]*(?:')?/ { $item[2]=~s/'//g; $return=$item[2] }

    auto_inc     : /auto_increment/i { 1 }

    primary_key  : /primary/i /key/i { 1 }

    primary_key_index : primary_key index_name(?) '(' field_name(s /,/) ')'
        { 
            $return = { 
                name   => $item{'index_name'}[0],
                type   => 'primary_key',
                fields => $item[4],
            } 
        }

    normal_index      : key index_name(?) '(' field_name(s /,/) ')'
        { 
            $return = { 
                name   => $item{'index_name'}[0],
                type   => 'normal',
                fields => $item[4],
            } 
        }

    unique_index      : /unique/i key index_name(?) '(' field_name(s /,/) ')'
        { 
            $return = { 
                name   => $item{'index_name'}[0],
                type   => 'unique',
                fields => $item[5],
            } 
        }

    key          : /key/i 
                   | /index/i

    table_type   : /TYPE=/i /\w+/ { $item[2] }

    WORD         : /[\w#]+/

    DIGITS       : /\d+/

    COMMA        : ','

};

1;

#-----------------------------------------------------
# Every hero becomes a bore at last.
# Ralph Waldo Emerson
#-----------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>

=head1 SEE ALSO

perl(1).

=cut
