package SQL::Translator::Filter::Names;

# -------------------------------------------------------------------
# Copyright (C) 2002-2009 SQLFairy Authors
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

SQL::Translator::Filter::Names - Tweak the names of schema objects.

=head1 SYNOPSIS

  #! /usr/bin/perl -w
  use SQL::Translator;

  # Lowercase all table names and upper case the first letter of all field
  # names. (MySql style!)
  #
  my $sqlt = SQL::Translator->new(
      filename => \@ARGV,
      from     => 'MySQL',
      to       => 'MySQL',
      filters => [
        Names => {
            'tables' => 'lc',
            'fields' => 'ucfirst',
        },
      ],
  ) || die "SQLFairy error : ".SQL::Translator->error;
  print($sqlt->translate) || die "SQLFairy error : ".$sqlt->error;

=cut

use strict;
use vars qw/$VERSION/;
$VERSION = '1.59';

sub filter {
    my $schema = shift;
    my %args = %{$_[0]};

    # Tables
    #if ( my $func = $args{tables} ) {
    #    _filtername($_,$func) foreach ( $schema->get_tables );
    #}
    # ,
    foreach my $type ( qw/tables procedures triggers views/ ) {
        if ( my $func = $args{$type} ) {
            my $meth = "get_$type";
            _filtername($_,$func) foreach $schema->$meth;
        }
    }

    # Fields
    if ( my $func = $args{fields} ) {
        _filtername($_,$func)
        foreach map { $_->get_fields } $schema->get_tables ;
    }

}

# _filtername( OBJ, FUNC_NAME )
# Update the name attribute on the schema object given using the named filter.
# Objects with no name are skipped.
# Returns true if the name was changed. Dies if there is an error running func.
sub _filtername {
    my ($obj,$func) = @_;
    return unless my $name = $obj->name;
    $func = _getfunc($func);
    my $newname = eval { $func->($name) };
    die "$@" if $@; # TODO - Better message!
    return if $name eq $newname;
    $_->name($newname);
}

# _getfunc( NAME ) - Returns code ref to func NAME or dies.
sub _getfunc {
    my ($name) = @_;
    no strict 'refs';
    my $func = "SQL::Translator::Filter::Names::$name";
    die "Table name filter - unknown function '$name'\n" unless exists &$func;
    \&$func;
}



# The name munging functions
#=============================================================================
# Get called with name to munge as first arg and return the new name. Die on
# errors.

sub lc { lc shift; }
sub uc { uc shift; }
sub ucfirst { ucfirst shift; }

1; #==========================================================================

__END__

=head1 DESCRIPTION

=head1 SEE ALSO

L<perl(1)>, L<SQL::Translator>

=head1 BUGS

=head1 TODO

=over 4

=item Name Groups

Define a bunch of useful groups to run the name filters over. e.g. all, fkeys,
pkeys etc.

=item More Functions

e.g. camelcase, titlecase, single word etc.
Also a way to pass in a regexp.

May also want a way to pass in arguments for the func e.g. prefix.

=item Multiple Filters on the same name (filter order)?

Do we actually need this, you could just run lots of filters. Would make adding
func args to the interface easier.

    filters => [
        [ 'Names', { all => 'lc' } ],
        [ 'Names', {
            tables => 'lc',
            fields => 'ucfirst',
        } ],
    ],

Mind you if you could give the filter a list this wouldn't be a problem!

    filters => [
        [ 'Names',
            all    => 'lc'
            fields => 'ucfirst',
        ],
    ],

Which is nice. Might have to change the calling conventions for filters.
Would also provide an order to run the filters in rather than having to hard
code it into the filter it's self.

=back

=head1 AUTHOR

=cut
