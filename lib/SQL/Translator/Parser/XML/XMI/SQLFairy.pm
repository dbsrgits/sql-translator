package SQL::Translator::Parser::XML::XMI::SQLFairy;

# -------------------------------------------------------------------
# $Id$
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

SQL::Translator::Parser::XML::XMI::SQLFairy - Create Schema from UML Models.

=cut

use strict;

use vars qw[ $DEBUG @EXPORT_OK ];
$DEBUG   = 0 unless defined $DEBUG;
use Exporter;
use base qw(Exporter);
@EXPORT_OK = qw(parse);

use Data::Dumper;
use SQL::Translator::Parser::XML::XMI;
use SQL::Translator::Utils 'debug';

# Globals for the subs to use, set in parse() and classes2schema()
#
# TODO Should we be giving classes2schema the schema or should they use their
# parse() to get it. Obj parsers maybe?
#our ($schema,$pargs);
use vars qw[ $schema $pargs ];

# Set the parg for the conversion sub then use the XMI parser
sub parse {
    my ( $translator ) = @_;
    local $DEBUG  = $translator->debug;
    local $pargs  = $translator->parser_args;
    #local $schema = $translator->schema;
	$pargs->{classes2schema} = \&classes2schema;
    $pargs->{derive_pkey} ||= "stereotype,auto,first";
    $pargs->{auto_pkey} ||= {
        name => sub {
            my $class = shift;
            $class->{name}."ID";
        },
        data_type => "INT",
        size => 10,
        is_nullable => 0,
        is_auto_increment => 1,
    };

    return SQL::Translator::Parser::XML::XMI::parse(@_);
}



# TODO We could make the tag names a parser arg so people can use their own.
my %TAGS;
$TAGS{data_type} = "sqlfDataType";
$TAGS{size} = "sqlfSize";
$TAGS{is_nullable} = "sqlfIsNullable";
$TAGS{required} = "sqlfRequired";
$TAGS{is_auto_increment} = "sqlfIsAutoIncrement";
$TAGS{default_value} = "sqlfDefaultValue";

sub _parameters_in {
	my $params = shift;
	return grep {$_->{kind} ne "return"} @$params;
}

sub _resolve_tag {
    my ($tag, $things) = @_;
    foreach (@$things) {
        return $_->{_map_taggedValues}{$tag}{dataValue}
        if exists $_->{_map_taggedValues}{$tag}{dataValue}; 
    }
    return;
}


sub classes2schema {
    local $schema = shift;
	my $classes = shift;

    #
    # Create tablles from Classes and collect their associations
    #
    my %associations;
	foreach my $class (@$classes) {
		# Add the table
        debug "Adding class: $class->{name}";
        my $table = $schema->add_table( name => $class->{name} )
            or die "Schema Error: ".$schema->error;

        # Only collect the associations for classes that are tables. Use a hash
        # so we only get them once
        $associations{$_->{"xmi.id"}} = $_
        foreach map $_->{association}, @{$class->{associationEnds}};

        #
        # Fields from Class attributes
        #
        my @flds;
        push @flds, attr2field($_) for @{$class->{attributes}};
            # TODO Filter this e.g no abstract attr or stereotype check
        foreach (@flds) {
            my $extra = delete $_->{extra};
            my $field = $table->add_field( %$_ ) or die $schema->error;
            $field->extra(%$extra) if $extra;
        }

        # Add a pkey
        add_pkey($class,$table);
    }

    #
    # Relationships from Associations
    #
    foreach my $assoc (values %associations) {
        my @end = @{$assoc->{associationEnds}};
        if (
            $end[0]->{multiplicity}{rangeUpper} == 1
            && $end[1]->{multiplicity}{rangeUpper} == 1
        ) {
            # 1:1 or 0:1
            warn "Sorry, 1:1 associations not yet implimented for xmi.id=".$assoc->{"xmi.id"}."\n";
        }
        elsif (
            $end[0]->{multiplicity}{rangeUpper} == 1
            || $end[1]->{multiplicity}{rangeUpper} == 1
        ) {
            one2many($assoc);
        }
        else
        {
            many2many($assoc);
        }

    }

}

# Take an attribute and return the field data for it
sub attr2field {
    my $attr = shift;
    my $dataType = $attr->{dataType};

    my %data = ( name => $attr->{name} );

    $data{data_type}
        = _resolve_tag($TAGS{data_type},[$attr,$dataType])
        || $dataType->{name};

    $data{size} = _resolve_tag($TAGS{size},[$attr,$dataType]);

    $data{default_value} 
        = _resolve_tag($TAGS{default_value},[$attr,$dataType])
        || $attr->{initialValue};

    my $is_nullable = _resolve_tag($TAGS{is_nullable},[$attr,$dataType]);
    my $required    = _resolve_tag($TAGS{required},[$attr,$dataType]);
    $data{is_nullable} 
        = defined $is_nullable ? $is_nullable 
        : ( defined $required ? ($required ? 0 : 1) : undef);

    $data{is_auto_increment}
        =  $attr->{_map_taggedValues}{$TAGS{is_auto_increment}}{dataValue}
        || $dataType->{_map_taggedValues}{$TAGS{is_auto_increment}}{dataValue}
        || undef;

    #
    # Extras
    # 
    my %tagnames;
    foreach ( keys %{$attr->{_map_taggedValues}} ) {$tagnames{$_}++; }
    delete @tagnames{@TAGS{qw/data_type size default_value is_nullable required is_auto_increment/}}; # Remove the tags we have already done
    my %extra = map { 
        my $val = $attr->{_map_taggedValues}{$_}{dataValue};
        s/^sqlf//;
        ($_,$val);
    } keys %tagnames;
    $data{extra} = \%extra;

    return \%data;
}

# Add a pkey to a table for the class
sub add_pkey {
    my ($class,$table) = @_;

    my @pkeys;
    foreach ( split(",", $pargs->{derive_pkey}) ) {
        if ( $_ eq "stereotype" ) {
            @pkeys = map $_->{name},
            grep($_->{stereotype} eq "PK", @{$class->{attributes}});
        }
        elsif( $_ eq "first" ) {
            @pkeys = $class->{attributes}[0]{name} unless @pkeys;
        }
        elsif( $_ eq "auto" ) {
            if ( my %data = %{$pargs->{auto_pkey}} ) {
                $data{name} = $data{name}->($class,$table);
                my $field = $table->add_field(%data) or die $table->error;
                @pkeys = $field->name;
            }
        }
        last if @pkeys;
    }

    $table->add_constraint(
        type   => "PRIMARY KEY",
        fields => [@pkeys],
    ) or die $table->error;
}

# Maps a 1:M association into the schema
sub one2many
{
    my ($assoc) = @_;
    my @ends = @{$assoc->{associationEnds}};
    my ($end1) = grep $_->{multiplicity}{rangeUpper} == 1, @ends;
    my $endm = $end1->{otherEnd};
    my $table1 = $schema->get_table($end1->{participant}{name});
    my $tablem = $schema->get_table($endm->{participant}{name});

    #
    # Export 1end pkey to many end
    #
    my $con  = $table1->primary_key;
    my @flds = $con->fields;
    foreach (@flds) {
        my $fld = $table1->get_field($_);
        my %data;
        $data{$_} = $fld->$_()
        foreach (qw/name size data_type default_value is_nullable/);
        $data{extra} = { $fld->extra }; # Copy extra hash
        $data{is_unique} = 0; # FKey on many join so not unique
        $data{is_nullable} = $end1->{multiplicity}{rangeLower} == 0 ? 1 : 0;
            # 0:m - allow nulluable on fkey
            # 1:m - dont allow nullable

        $tablem->add_field(%data) or die $tablem->error;
        # Export the pkey if full composite (ie identity) relationship
        $tablem->primary_key($_) if $end1->{aggregation} eq "composite";
    }

    #
    # Add fkey constraint to many end
    # 
    $tablem->add_constraint(
        type   => "FOREIGN_KEY",
        fields => [@flds],
        reference_table => $table1->{name},
        reference_fields => [@flds],
    ) or die $schema->error;
}

# Maps m:n into schema by building a link table.
sub many2many
{
    my ($assoc) = @_;
    my @end = @{$assoc->{associationEnds}};

    # Create the link table
    my $name = $end[0]->{participant}{name}."_".$end[1]->{participant}{name};
    my $link_table = $schema->add_table( name => $name )
    or die "Schema Error: ".$schema->error;

    # Export the pkey(s) from the ends into the link table
    my @pkeys;
    foreach (@end) {
        my $table = $schema->get_table($_->{participant}{name});
        my @fkeys = $table->primary_key->fields;
        push @pkeys,@fkeys;
        foreach ( @fkeys ) {
            my $fld = $table->get_field($_);
            my %data;
            $data{$_} = $fld->$_()
                foreach (
                qw/name size data_type default_value is_nullable is_unique/);
            $data{is_auto_increment} = 0;
            $data{extra} = { $fld->extra }; # Copy
            $link_table->add_field(%data) or die $table->error;
        }
        $link_table->add_constraint(
            type   => "FOREIGN_KEY",
            fields => [@fkeys],
            reference_table => $table->{name},
            reference_fields => [@fkeys],
        ) or die $schema->error;

    }
    # Add pkey constraint
    $link_table->add_constraint( type => "PRIMARY KEY", fields => [@pkeys] )
    or die $link_table->error;


    # Add fkeys to our participants
}
1; #---------------------------------------------------------------------------

__END__

=pod

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::XML::XMI;

  my $translator     = SQL::Translator->new(
      from           => 'XML-XMI-SQLFairy',
      to             => 'MySQL',
      filename       => 'schema.xmi',
  );

  print $obj->translate;

=head1 DESCRIPTION

Converts Class diagrams to Schema trying to use standard UML features as much
as possible, with the minimum use of extension mechanisms (tagged values and
stereotypes) for the database details. The idea is to treat the object model 
like a logical database model and map that to a physical model (the sql). Also
tries to make this mapping as configurable as possible and support all the
schema features of SQLFairy.

=head2 Tables

Classes, all of them! (TODO More control over which tables to do.)

=head2 Fields

The attributes of the class will be converted to fields of the same name.

=head3 Datatypes

Database datatypes are modeled using tagged values; sqlfDataType,
sqlfSize, sqlfIsNullable and sqlfIsAutoIncrement added to the attribute.
The default value is the UML initial value of the attribute or can be overridden
using a sqlfDefaultValue tagged value if you want to have a different default
in the database then the object uses.

For more advanced datatype modeling you can use UML data types by adding the
tagged values to the UML data types in your model and then giving your
attributes those datatypes. Any tagged values set on attributes will override
any they get from their datatype. This allows you to use UML datatypes like
domains.  If no sqlfDataType is given then the name of the UMLDataType is used.

=head3 Primary Keys

If no attribute is marked explicity on the Class as a pkey then one is added.
The default is an INT(10) auto number named after the class with ID on the end.
For many cases this is enough as you don't normally need to model pkeys
explicitly in your object models as its a database thing.

The pkey created can be controlled by setting the C<auto_pkey> parser arg to a
hash ref describing the field. The name key is a sub that gets given a ref to
the class (from the xmi) and the table it has been mapped to, and should return the pkey name. e.g. the defualt looks like;

 {
     name => sub {
         my $class = shift;
         $class->{name}."ID";
     },
     data_type => "INT",
     size => 10,
     is_nullable => 0,
     is_auto_increment => 1,
 }

NB You need to return a unique name for the key if it will be used to build
relationships as it will be exported to other tables (see Relationships).

You can also set them explicitly by marking attributes with a <<PK>> stereotype.
Add to multiple attribs to make multi column keys. Usefull when your object
contains an attribute that makes a good candidate for a pkey, e.g. email.

=head2 Relationships

=head2 1:m

Associations where one ends multiplicty is '1' or '0..1' and the other end's
multplicity is more than 1 e.g '*', '0..*', '1..*', '0..3', '4..42' etc.

The pkey field from the 1 end is added to the table for the class at the many
end as a foreign key with is_unique and auto number turned off.

If the 1 end is multiplicity '0..1' (ie a 0:m join) then the the fkey is made
nullable, if its multiplicity '1' (1:m) then its made not nullable.

If the association is a composition then the created fkey is made part of the
many ends pkey. ie It exports the pkey to create an identity join.

=head2 m:n

Model using a standard m:n association and the parser will automatically create
a link table for you in the Schema by exporting pkeys from the tables at 
each end.

=head1 EXAMPLE

TODO An example to help make sense of the above! Probably based on the test.

=head1 ARGS

=head1 BUGS

=head1 TODO

1:1 joins.

Use Role names from associations as field names for exported keys when building
relationships.

Generalizations.

Support for the format_X_name subs in the Translator and format subs for 
generating the link table name in m:n joins.

Lots more...

=head1 AUTHOR

Mark D. Addison E<lt>mark.addison@itn.co.ukE<gt>.

=head1 SEE ALSO

perl(1), SQL::Translator::Parser::XML::XMI

=cut
