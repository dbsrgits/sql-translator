package SQL::Translator::Schema::View;

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

SQL::Translator::Schema::View - SQL::Translator view object

=head1 SYNOPSIS

  use SQL::Translator::Schema::View;
  my $view   = SQL::Translator::Schema::View->new(
      name   => 'foo',                      # name, required
      sql    => 'select id, name from foo', # SQL for view
      fields => 'id, name',                 # field names in view
  );

=head1 DESCRIPTION

C<SQL::Translator::Schema::View> is the view object.

=head1 METHODS

=cut

use strict;
use SQL::Translator::Utils 'parse_list_arg';

use base 'SQL::Translator::Schema::Object';

use vars qw($VERSION $TABLE_COUNT $VIEW_COUNT);

$VERSION = '1.59';

# ----------------------------------------------------------------------

__PACKAGE__->_attributes( qw/
    name sql fields schema order
/);

=pod

=head2 new

Object constructor.

  my $view = SQL::Translator::Schema::View->new;

=cut

# ----------------------------------------------------------------------
sub fields {

=pod

=head2 fields

Gets and set the fields the constraint is on.  Accepts a string, list or
arrayref; returns an array or array reference.  Will unique the field
names and keep them in order by the first occurrence of a field name.

  $view->fields('id');
  $view->fields('id', 'name');
  $view->fields( 'id, name' );
  $view->fields( [ 'id', 'name' ] );
  $view->fields( qw[ id name ] );

  my @fields = $view->fields;

=cut

    my $self   = shift;
    my $fields = parse_list_arg( @_ );

    if ( @$fields ) {
        my ( %unique, @unique );
        for my $f ( @$fields ) {
            next if $unique{ $f };
            $unique{ $f } = 1;
            push @unique, $f;
        }

        $self->{'fields'} = \@unique;
    }

    return wantarray ? @{ $self->{'fields'} || [] } : ($self->{'fields'} || '');
}

# ----------------------------------------------------------------------
sub is_valid {

=pod

=head2 is_valid

Determine whether the view is valid or not.

  my $ok = $view->is_valid;

=cut

    my $self = shift;

    return $self->error('No name') unless $self->name;
    return $self->error('No sql')  unless $self->sql;

    return 1;
}

# ----------------------------------------------------------------------
sub name {

=pod

=head2 name

Get or set the view's name.

  my $name = $view->name('foo');

=cut

    my $self        = shift;
    $self->{'name'} = shift if @_;
    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub order {

=pod

=head2 order

Get or set the view's order.

  my $order = $view->order(3);

=cut

    my ( $self, $arg ) = @_;

    if ( defined $arg && $arg =~ /^\d+$/ ) {
        $self->{'order'} = $arg;
    }

    return $self->{'order'} || 0;
}

# ----------------------------------------------------------------------
sub sql {

=pod

=head2 sql

Get or set the view's SQL.

  my $sql = $view->sql('select * from foo');

=cut

    my $self       = shift;
    $self->{'sql'} = shift if @_;
    return $self->{'sql'} || '';
}

# ----------------------------------------------------------------------
sub schema {

=pod

=head2 schema

Get or set the view's schema object.

  $view->schema( $schema );
  my $schema = $view->schema;

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

Determines if this view is the same as another

  my $isIdentical = $view1->equals( $view2 );

=cut

    my $self = shift;
    my $other = shift;
    my $case_insensitive = shift;
    my $ignore_sql = shift;
    
    return 0 unless $self->SUPER::equals($other);
    return 0 unless $case_insensitive ? uc($self->name) eq uc($other->name) : $self->name eq $other->name;
    #return 0 unless $self->is_valid eq $other->is_valid;
    
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
    
    my $selfFields = join(":", $self->fields);
    my $otherFields = join(":", $other->fields);
    return 0 unless $case_insensitive ? uc($selfFields) eq uc($otherFields) : $selfFields eq $otherFields;
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

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut
