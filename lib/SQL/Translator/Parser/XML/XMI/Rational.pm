package SQL::Translator::Parser::XML::XMI::Rational;

# -------------------------------------------------------------------
# $Id: Rational.pm,v 1.5 2003-10-06 15:05:17 grommit Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Mark Addison <mark.addison@itn.co.uk>,
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

SQL::Translator::Parser::XML::XMI::Rational - Create Schema using Rational's UML
Data Modeling Profile.

=cut

use strict;
use SQL::Translator::Parser::XML::XMI;
use SQL::Translator::Utils 'debug';

# Set the parg for the conversion sub then use the XMI parser
sub parse {
    my ( $translator ) = @_;
    my $pargs = $translator->parser_args;
	$pargs->{classes2schema} = \&classes2schema;
	return SQL::Translator::Parser::XML::XMI::parse(@_);
}

sub _parameters_in {
	my $params = shift;
	return grep {$_->{kind} ne "return"} @$params;
}

sub classes2schema {
	my ($schema, $classes) = @_;

	foreach my $class (@$classes) {
        next unless $class->{stereotype} eq "Table";

		# Add the table
        debug "Adding class: $class->{name}";
        my $table = $schema->add_table( name => $class->{name} )
            or die "Schema Error: ".$schema->error;

        #
        # Fields from Class attributes
        #
        foreach my $attr ( @{$class->{attributes}} ) {
			next unless $attr->{stereotype} eq "Column"
				or $attr->{stereotype} eq "PK"
				or $attr->{stereotype} eq "FK"
				or $attr->{stereotype} eq "PFK";

			my $ispk =
			    $attr->{stereotype} eq "PK" or $attr->{stereotype} eq "PFK"
				? 1 : 0;
			my %data = (
                name           => $attr->{name},
                data_type      => $attr->{datatype},
                is_primary_key => $ispk,
            );
			$data{default_value} = $attr->{initialValue}
				if exists $attr->{initialValue};
			$data{data_type} = $attr->{_map_taggedValues}{dataType}{dataValue}
				|| $attr->{datatype};
			$data{size} = $attr->{_map_taggedValues}{size}{dataValue};
			$data{is_nullable}=$attr->{_map_taggedValues}{nullable}{dataValue};

            my $field = $table->add_field( %data ) or die $schema->error;
            $table->primary_key( $field->name ) if $data{'is_primary_key'};
		}

		#
		# Constraints and indexes from Operations
		#
        foreach my $op ( @{$class->{operations}} ) {
			next unless my $stereo = $op->{stereotype};
			my @fields = map {$_->{name}} grep {$_->{kind} ne "return"} @{$op->{parameters}};
			my %data = (
                name      => $op->{name},
                type      => "",
				fields    => [@fields],
            );

			# Work out type and any other data
			if ( $stereo eq "Unique" ) {
				$data{type} = "UNIQUE";
			}
			elsif ( $stereo eq "PK" ) {
				$data{type} = "PRIMARY_KEY";
			}
			# Work out the ref table
			elsif ( $stereo eq "FK" ) {
				$data{type} = "FOREIGN_KEY";
				_add_fkey_refs($class,$op,\%data);
			}

			# Add the constraint or index
			if ( $data{type} ) {
				$table->add_constraint( %data ) or die $schema->error;
			}
			elsif ( $stereo eq "Index" ) {
            	$data{type} = "NORMAL";
				$table->add_index( %data ) or die $schema->error;
			}

		} # Ops loop

    } # Classes loop
}

use Data::Dumper;
sub _add_fkey_refs {
	my ($class,$op,$data) = @_;

	# Find the association ends
	my ($end) = grep { $_->{name} eq $op->{name} } @{$class->{associationEnds}};
	return unless $end;
	# Find the fkey op
	my ($refop) = grep { $_->{name} eq $end->{otherEnd}{name} }
		@{$end->{otherEnd}{participant}{operations}};
	return unless $refop;

	$data->{reference_table} = $end->{otherEnd}{participant}{name};
	$data->{reference_fields} = [ map("$_->{name}", _parameters_in($refop->{parameters})) ];
	return $data;
}

1; #---------------------------------------------------------------------------

__END__

=pod

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::XML::XMI;

  my $translator     = SQL::Translator->new(
      from           => 'XML-XMI-Rational',
      to             => 'MySQL',
      filename       => 'schema.xmi',
      show_warnings  => 1,
      add_drop_table => 1,
  );

  print $obj->translate;

=head1 DESCRIPTION

Translates Schema described using Rational Software's UML Data Modeling Profile.
Finding good information on this profile seems to be very difficult so this
is based on a vague white paper and notes in vendors docs!

Below is a summary of what this parser thinks the profile looks like.

B<Tables> Are classes marked with <<Table>> stereotype.

B<Fields> Attributes stereotyped with <<Column>> or one of the key stereotypes.
Additional info is added using tagged values of C<dataType>, C<size> and
C<nullable>. Default value is given using normal UML default value for the
attribute.

B<Keys> Key fields are marked with <<PK>>, <<FK>> or <<PFK>>. Note that this is
really to make it obvious on the diagram, you must still add the constraints.
(This parser will also automatically add the constraint for single field pkeys
for attributes marked with PK but I think this is out of spec.)

B<Constraints> Stereotyped operations, with the names of the parameters
indicating which fields it applies to. Can use <<PK>>, <<FK>>, <<Unique>> or
<<Index>>.

B<Relationships> You can model the relationships in the diagram and have the
translator add the foreign key constraints for you. The forign keys are defined
as <<FK>> operations as show above. To show which table they point to join the
class to the taget classwith an association where the role names are the names
of the constraints to join.

e.g.

 +------------------------------------------------------+
 |                      <<Table>>                       |
 |                         Foo                          |
 +------------------------------------------------------+
 | <<PK>>     fooID { dataType=INT size=10 nullable=0 } |
 | <<Column>> name { dataType=VARCHAR size=255 }        |
 | <<Column>> description { dataType=TEXT }             |
 +------------------------------------------------------+
 | <<PK>>     pkcon( fooID )                             |
 | <<Unique>> con2( name )                              |
 +------------------------------------------------------+
                           |
                           | pkcon
                           |
                           |
                           |
                           |
                           | fkcon
                           |
 +------------------------------------------------------+
 |                      <<Table>>                       |
 |                         Bar                          |
 +------------------------------------------------------+
 | <<PK>>     barID { dataType=INT size=10 nullable=0 } |
 | <<FK>>     fooID { dataType=INT size=10 nullable=0 } |
 | <<Column>> name  { dataType=VARCHAR size=255 }       |
 +------------------------------------------------------+
 | <<PK>>     pkcon( barID )                            |
 | <<FK>>     fkcon( fooID )                            |
 +------------------------------------------------------+

 CREATE TABLE Foo (
   fooID INT(10) NOT NULL,
   name VARCHAR(255),
   description TEXT,
   PRIMARY KEY (fooID),
   UNIQUE con2 (name)
 );

 CREATE TABLE Bar (
   barID INT(10) NOT NULL,
   fooID INT(10) NOT NULL,
   name VARCHAR(255),
   PRIMARY KEY (fooID),
   FOREIGN KEY fkcon (fooID) REFERENCES Foo (fooID)
 );

=head1 ARGS

=head1 BUGS

=head1 TODO

The Rational profile also defines ways to model stuff above tables such as the
actuall db.

=head1 AUTHOR

Mark D. Addison E<lt>mark.addison@itn.co.ukE<gt>.

=head1 SEE ALSO

perl(1), SQL::Translator::Parser::XML::XMI

=cut
