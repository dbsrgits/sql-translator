package SQL::Translator::Parser::XML::XMI::SQLFairy;

# -------------------------------------------------------------------
# $Id: SQLFairy.pm,v 1.1 2003-10-10 20:03:24 grommit Exp $
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

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;
use Exporter;
use base qw(Exporter);
@EXPORT_OK = qw(parse);

use Data::Dumper;
use SQL::Translator::Parser::XML::XMI;
use SQL::Translator::Utils 'debug';

# Set the parg for the conversion sub then use the XMI parser
sub parse {
    my ( $translator ) = @_;
    local $DEBUG  = $translator->debug;
    my $pargs = $translator->parser_args;
	$pargs->{classes2schema} = \&classes2schema;
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
	my ($schema, $classes) = @_;

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

        #
        # Primary key
        #
        my @pkeys;
        @pkeys = map $_->{name},
            grep($_->{stereotype} eq "PK", @{$class->{attributes}});
        # if none set with steretype, use first attrib
        @pkeys = $class->{attributes}[0]{name} unless @pkeys;
        $table->add_constraint(
            type   => "PRIMARY KEY",
            fields => [@pkeys],
        ) or die $schema->error;
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
            warn "Sorry, 1:1 associations not yet implimented for xmi.id".$assoc->{"xmi.id"}."\n";
        }
        elsif (
            $end[0]->{multiplicity}{rangeUpper} == 1 
            || $end[1]->{multiplicity}{rangeUpper} == 1 
        ) {
            # 1:m or 0:m
            one2many($schema,$assoc);
        }
        else
        {
            # m:n
            warn "Sorry, n:m associations not yet implimented for xmi.id".$assoc->{"xmi.id"}."\n";
        }

    }    

}

sub attr2field {
    my $attr = shift;
    my $dataType = $attr->{dataType};

    my %data = ( name => $attr->{name} );

    $data{data_type}
        = _resolve_tag($TAGS{data_type},[$attr,$dataType])
        || $dataType->{name};

    $data{size} = _resolve_tag($TAGS{size},[$attr,$dataType]);

    $data{default_value} 
        = $attr->{initialValue}
        || _resolve_tag($TAGS{default_value},[$attr,$dataType]);

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

# Maps a 1:M association into the schema
sub one2many {
    my ($scma,$assoc) = @_;
    my @ends = @{$assoc->{associationEnds}};
    my ($end1) = grep $_->{multiplicity}{rangeUpper} == 1, @ends;
    my $endm = $end1->{otherEnd};
    my $table1 = $scma->get_table($end1->{participant}{name});
    my $tablem = $scma->get_table($endm->{participant}{name});

    #
    # Export 1end pkey to many end
    # 
    my $con = $table1->primary_key;
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

        $tablem->add_field(%data) or die $scma->error;
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
    ) or die $scma->error;
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
schema features that SQLFairy does.

=head2 Tables

Classes, all of them! (TODO More control over which tables to do.)

=head2 Fields

=head3 Datatypes 

Database datatypes are modeled using tagged values; sqlfDataType,
sqlfSize, sqlfIsNullable and sqlfIsAutoIncrement. These can be added either
to the UML datatype or directly on the attribute where they override the value
from the datatype. If no sqlfDataType is given then the name of the UMLDataType
is used. If no default value is found then the UML initialValue is used (even 
if a tag is set on the UMLDataType - do we want to do it this way?.

=head3 Primary Keys

Primary keys are attributes marked with <<PK>>. Add to multiple attribs to make
multi column keys. If none are marked will use the 1st attribute. 

=head2 Relationships

Modeled using UML associations. Currently only handles 0:m and 1:m joins. That
is associations where one ends multiplicty is '1' or '0..1' and the other end's
multplicity is '0..*' or '1..*' or >1 (e.g '0..3' '1..23' '4..42') etc. 

The pkey from the 1 end is added to the table for the class at the many end as
a foreign key. is_unique is forced to false for the new field. 

If the 1 end is multiplicity '0..1' (ie a 0:m join) then the the fkey is made
nullable, if its multiplicity '1' (1:m) then its made not nullable.

If the association is a composition then the created fkey is made part of the 
many ends pkey. ie It exports the pkey to create an identity join. 

=head1 ARGS

=head1 BUGS

=head1 TODO

=head1 AUTHOR

Mark D. Addison E<lt>mark.addison@itn.co.ukE<gt>.

=head1 SEE ALSO

perl(1), SQL::Translator::Parser::XML::XMI

=cut
