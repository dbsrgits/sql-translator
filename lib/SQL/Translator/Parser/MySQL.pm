package SQL::Translator::Parser::MySQL;

#-----------------------------------------------------
# $Id: MySQL.pm,v 1.2 2002-03-21 18:50:53 dlc Exp $
#-----------------------------------------------------
# Copyright (C) 2002 Ken Y. Clark <kycl4rk@users.sourceforge.net>,
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

use strict;
use vars qw($VERSION $GRAMMAR @EXPORT_OK);
$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;

#use SQL::Translator::Parser;  # This is not necessary!
use Parse::RecDescent;
use Exporter;
use base qw(Exporter);

@EXPORT_OK = qw(parse);

my $parser; # should we do this?  There's no programmic way to 
            # change the grammar, so I think this is safe.
sub parse {
    my ( $translator, $data ) = @_;
    $parser ||= Parse::RecDescent->new($GRAMMAR);

    unless (defined $parser) {
        $translator->error_out("Error instantiating Parse::RecDescent ".
            "instance: Bad grammer");
        return;
    }

    # Is this right?  It was $parser->parse before, but that didn't
    # work; Parse::RecDescent appears to need the name of a rule
    # with which to begin, so I chose the first rule in the grammar.
    return $parser->file($data);
}

$GRAMMAR =
    q!
        { our ( %tables ) }

        file         : statement(s) { \%tables }

        statement    : comment
                       | create
                       | <error>

        create       : create_table table_name '(' line(s /,/) ')' table_type(?) ';'
                    { 
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
                                    @{ $tables{ $item{'table_name'} }{'indeces'} },
                                    {
                                        type   => 'primary_key',
                                        fields => [ $field_name ],
                                    };
                                }
                            }
                            else {
                                push @{ $tables{ $item{'table_name'} }{'indeces'} },
                                    $line;
                            }
                            $tables{ $item{'table_name'} }{'type'} = 
                                $item{'table_type'}[0];
                        }
                    }
                       | <error>

        line         : index
                       | field
                       | <error>

        comment      : /^\s*#.*\n/

        blank        : /\s*/

        field        : field_name data_type not_null(?) default_val(?) auto_inc(?) primary_key(?)
                       { 
                            my $null = defined $item{'not_null'}[0] 
                                       ? $item{'not_null'}[0] : 1 ;
                            $return = { 
                                type           => 'field',
                                name           => $item{'field_name'}, 
                                data_type      => $item{'data_type'}{'type'},
                                size           => $item{'data_type'}{'size'},
                                null           => $null,
                                default        => $item{'default_val'}[0], 
                                is_auto_inc    => $item{'auto_inc'}[0], 
                                is_primary_key => $item{'primary_key'}[0], 
                           } 
                       }
                    | <error>

        index        : primary_key_index
                       | unique_index
                       | normal_index

        table_name   : WORD

        field_name   : WORD

        index_name   : WORD

        data_type    : WORD field_size(?) 
            { 
                $return = { 
                    type => $item[1], 
                    size => $item[2][0]
                } 
            }

        field_type   : WORD

        field_size   : '(' num_range ')' { $item{'num_range'} }

        num_range    : DIGITS ',' DIGITS
            { $return = $item[1].','.$item[3] }
                       | DIGITS
            { $return = $item[1] }


        create_table : /create/i /table/i

        not_null     : /not/i /null/i { $return = 0 }

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

        WORD         : /\w+/

        DIGITS       : /\d+/

        COMMA        : ','

    !;

1;

#-----------------------------------------------------
# Where man is not nature is barren.
# William Blake
#-----------------------------------------------------

=head1 NAME

SQL::Translator::Parser::MySQL - parser for MySQL

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::MySQL;

  my $translator = SQL::Translator->new;
  $translator->parser("SQL::Translator::Parser::MySQL");

=head1 DESCRIPTION

Blah blah blah.

=head1 AUTHOR

Ken Y. Clark, kclark@logsoft.com

=head1 SEE ALSO

perl(1).

=cut
