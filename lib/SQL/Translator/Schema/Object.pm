package SQL::Translator::Schema::Object;

# ----------------------------------------------------------------------
# $Id: Object.pm,v 1.3 2004-11-05 15:03:10 grommit Exp $
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

SQL::Translator::Schema::Object - Base class SQL::Translator Schema objects.

=head1 SYNOPSIS

=head1 DESCSIPTION

Base class for Schema objects. Sub classes L<Class::Base> and adds the following
extra functionality. 

=cut

use strict;
use Class::Base;
use base 'Class::Data::Inheritable';
use base 'Class::Base';

use vars qw[ $VERSION ];

$VERSION = sprintf "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/;


=head1 Construction

Derived classes should decalare their attributes using the C<_attributes>
method. They can then inherit the C<init> method from here which will call
accessors of the same name for any values given in the hash passed to C<new>.
Note that you will have to impliment the accessors your self and we expect perl
style methods; call with no args to get and with arg to set.

e.g. If we setup our class as follows;

 package SQL::Translator::Schema::Table;
 use base qw/SQL::Translator::Schema::Object/;
 
 __PACKAGE__->_attributes( qw/schema name/ );

 sub name   { ... }
 sub schema { ... }

Then we can construct it with

 my $table  =  SQL::Translator::Schema::Table->new( 
     schema => $schema,
     name   => 'foo',
 );

and init will call C<< $table->name("foo") >> and C<< $table->schema($schema) >>
to set it up. Any undefined args will be ignored.

Multiple calls to C<_attributes> are cumulative and sub classes will inherit
their parents attribute names.

This is currently experimental, but will hopefull go on to form an introspection
API for the Schema objects.

=cut


__PACKAGE__->mk_classdata("__attributes");

# Define any global attributes here
__PACKAGE__->__attributes([qw/extra/]); 

# Set the classes attribute names. Multiple calls are cumulative.
# We need to be careful to create a new ref so that all classes don't end up
# with the same ref and hence the same attributes!
sub _attributes {
    my $class = shift;
    if (@_) { $class->__attributes( [ @{$class->__attributes}, @_ ] ); }
    return @{$class->__attributes};
}

# Call accessors for any args in hashref passed
sub init {
    my ( $self, $config ) = @_;
    
    for my $arg ( $self->_attributes ) {
        next unless defined $config->{$arg};
        defined $self->$arg( $config->{$arg} ) or return; 
    }

    return $self;
}

# ----------------------------------------------------------------------
sub extra {

=pod

=head1 Global Attributes

The following attributes are defined here, therefore all schema objects will
have them.

=head2 extra

Get or set the objects "extra" attibutes (e.g., "ZEROFILL" for MySQL fields).
Accepts a hash(ref) of name/value pairs to store;  returns a hash.

  $field->extra( qualifier => 'ZEROFILL' );
  my %extra = $field->extra;

=cut

    my $self = shift;
    my $args = ref $_[0] eq 'HASH' ? shift : { @_ };

    while ( my ( $key, $value ) = each %$args ) {
        $self->{'extra'}{ $key } = $value;
    }

    return %{ $self->{'extra'} || {} };
}

#=============================================================================

1;

=pod

=head1 SEE ALSO

=head1 TODO

=head1 BUGS

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cpan.orgE<gt>, Mark Addison E<lt>mark.addison@itn.co.ukE<gt> 

=cut
