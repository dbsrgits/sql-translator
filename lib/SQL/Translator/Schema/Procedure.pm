package SQL::Translator::Schema::Procedure;

# ----------------------------------------------------------------------
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

$VERSION = '1.59';

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

    return wantarray ? @{ $self->{'parameters'} || [] } : ($self->{'parameters'} || '');
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
sub equals {

=pod

=head2 equals

Determines if this procedure is the same as another

  my $isIdentical = $procedure1->equals( $procedure2 );

=cut

    my $self = shift;
    my $other = shift;
    my $case_insensitive = shift;
    my $ignore_sql = shift;
    
    return 0 unless $self->SUPER::equals($other);
    return 0 unless $case_insensitive ? uc($self->name) eq uc($other->name) : $self->name eq $other->name;
    
    unless ($ignore_sql) {
        my $selfSql = $self->sql;
        my $otherSql = $other->sql;
        # Remove comments
        $selfSql =~ s/--.*$//mg;
        $otherSql =~ s/--.*$//mg;
        # Collapse whitespace to space to avoid whitespace comparison issues
        $selfSql =~ s/\s+/ /sg;
        $otherSql =~ s/\s+/ /sg;
        return 0 unless $selfSql eq $otherSql;
    }
    
    return 0 unless $self->_compare_objects(scalar $self->parameters, scalar $other->parameters);
#    return 0 unless $self->comments eq $other->comments;
#    return 0 unless $case_insensitive ? uc($self->owner) eq uc($other->owner) : $self->owner eq $other->owner;
    return 0 unless $self->_compare_objects(scalar $self->extra, scalar $other->extra);
    return 1;
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

Ken Youens-Clark E<lt>kclark@cshl.orgE<gt>,
Paul Harrington E<lt>Paul-Harrington@deshaw.comE<gt>.

=cut
