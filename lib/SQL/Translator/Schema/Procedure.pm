package SQL::Translator::Schema::Procedure;

# ----------------------------------------------------------------------
# $Id: Procedure.pm,v 1.4 2004-11-05 13:19:31 grommit Exp $
# ----------------------------------------------------------------------
# Copyright (C) 2002-4 SQLFairy Authors
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

=pod

=head1 NAME

SQL::Translator::Schema::Procedure - SQL::Translator procedure object

=head1 SYNOPSIS

  use SQL::Translator::Schema::Procedure;
  my $procedure  = SQL::Translator::Schema::Procedure->new(
      name       => 'foo',
      sql        => 'CREATE PROC foo AS SELECT * FROM bar',
      parameters => 'foo,bar',
      owner      => 'nomar',
      comments   => 'blah blah blah',
      schema     => $schema,
  );

=head1 DESCRIPTION

C<SQL::Translator::Schema::Procedure> is a class for dealing with
stored procedures (and possibly other pieces of nameable SQL code?).

=head1 METHODS

=cut

use strict;
use SQL::Translator::Utils 'parse_list_arg';

use base 'SQL::Translator::Schema::Object';

use vars qw($VERSION);

$VERSION = sprintf "%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/;

# ----------------------------------------------------------------------

__PACKAGE__->_attributes( qw/
    name sql parameters comments owner sql schema order
/);

=pod

=head2 new

Object constructor.

  my $schema = SQL::Translator::Schema::Procedure->new;

=cut

# ----------------------------------------------------------------------
sub parameters {

=pod

=head2 parameters

Gets and set the parameters of the stored procedure.

  $procedure->parameters('id');
  $procedure->parameters('id', 'name');
  $procedure->parameters( 'id, name' );
  $procedure->parameters( [ 'id', 'name' ] );
  $procedure->parameters( qw[ id name ] );

  my @parameters = $procedure->parameters;

=cut

    my $self   = shift;
    my $parameters = parse_list_arg( @_ );

    if ( @$parameters ) {
        my ( %unique, @unique );
        for my $p ( @$parameters ) {
            next if $unique{ $p };
            $unique{ $p } = 1;
            push @unique, $p;
        }

        $self->{'parameters'} = \@unique;
    }

    return wantarray ? @{ $self->{'parameters'} || [] } : $self->{'parameters'};
}

# ----------------------------------------------------------------------
sub name {

=pod

=head2 name

Get or set the procedure's name.

  $procedure->name('foo');
  my $name = $procedure->name;

=cut

    my $self        = shift;
    $self->{'name'} = shift if @_;
    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub sql {

=pod

=head2 sql

Get or set the procedure's SQL.

  $procedure->sql('select * from foo');
  my $sql = $procedure->sql;

=cut

    my $self       = shift;
    $self->{'sql'} = shift if @_;
    return $self->{'sql'} || '';
}

# ----------------------------------------------------------------------
sub order {

=pod

=head2 order

Get or set the order of the procedure.

  $procedure->order( 3 );
  my $order = $procedure->order;

=cut

    my $self         = shift;
    $self->{'order'} = shift if @_;
    return $self->{'order'};
}

# ----------------------------------------------------------------------
sub owner {

=pod

=head2 owner

Get or set the owner of the procedure.

  $procedure->owner('nomar');
  my $sql = $procedure->owner;

=cut

    my $self         = shift;
    $self->{'owner'} = shift if @_;
    return $self->{'owner'} || '';
}

# ----------------------------------------------------------------------
sub comments {

=pod

=head2 comments

Get or set the comments on a procedure.

  $procedure->comments('foo');
  $procedure->comments('bar');
  print join( ', ', $procedure->comments ); # prints "foo, bar"

=cut

    my $self = shift;

    for my $arg ( @_ ) {
        $arg = $arg->[0] if ref $arg;
        push @{ $self->{'comments'} }, $arg if $arg;
    }

    if ( @{ $self->{'comments'} || [] } ) {
        return wantarray 
            ? @{ $self->{'comments'} || [] }
            : join( "\n", @{ $self->{'comments'} || [] } );
    }
    else {
        return wantarray ? () : '';
    }
}

# ----------------------------------------------------------------------
sub schema {

=pod

=head2 schema

Get or set the procedures's schema object.

  $procedure->schema( $schema );
  my $schema = $procedure->schema;

=cut

    my $self = shift;
    if ( my $arg = shift ) {
        return $self->error('Not a schema object') unless
            UNIVERSAL::isa( $arg, 'SQL::Translator::Schema' );
        $self->{'schema'} = $arg;
    }

    return $self->{'schema'};
}

# ----------------------------------------------------------------------
sub DESTROY {
    my $self = shift;
    undef $self->{'schema'}; # destroy cyclical reference
}

1;

# ----------------------------------------------------------------------

=pod

=head1 AUTHORS

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>,
Paul Harrington E<lt>Paul-Harrington@deshaw.comE<gt>.

=cut
