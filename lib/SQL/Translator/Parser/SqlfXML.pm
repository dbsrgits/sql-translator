package SQL::Translator::Parser::SqlfXML;

# -------------------------------------------------------------------
# $Id: SqlfXML.pm,v 1.5 2003-08-15 15:08:08 grommit Exp $
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

SQL::Translator::Parser::SqlfXML - parser for the XML produced by
SQL::Translator::Producer::SqlfXML.

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::SqlfXML;

  my $translator = SQL::Translator->new(
      show_warnings  => 1,
      add_drop_table => 1,
  );
  print = $obj->translate(
      from     => "SqlfXML",
      to       =>"MySQL",
      filename => "fooschema.xml",
  );

=head1 DESCRIPTION

A SQL Translator parser to parse the XML files produced by its SqftXML producer.
The XML must be in the namespace http://sqlfairy.sourceforge.net/sqlfairy.xml.

To see an example of the XML translate one of your schema :) e.g.

 $ sql_translator.pl --from=MySQL --to=SqftXML foo_schema.sql

==head2 attrib_values

The parser will happily parse XML produced with the attrib_values arg set. If
it sees a value set as an attribute and a tag, the tag value will override
that of the attribute.

e.g. For the xml below the table would get the name 'bar'.

 <sqlf:table name="foo">
   <sqlf:name>foo</name>
 </sqlf:table>

==head2 default_value

Leave the tag out all together to use the default in Schema::Field. Use empty
tags or EMPTY_STRING for a zero lenth string. NULL for an explicit null
(currently sets default_value to undef in the Schema::Field obj).

 <sqlf:default_value></sqlf:default_value>               <!-- Empty string -->
 <sqlf:default_value>EMPTY_STRING</sqlf:default_value>   <!-- Empty string -->
 <sqlf:default_value>NULL</sqlf:default_value>           <!-- NULL -->

 <sqlf:default_value/>            <!-- Empty string BUT DON'T USE! See BUGS -->

==head2 ARGS

Doesn't take any extra parser args at the moment.

=cut

use strict;
use warnings;

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

use Data::Dumper;
use Exporter;
use base qw(Exporter);
@EXPORT_OK = qw(parse);

use base qw/SQL::Translator::Parser/;  # Doesnt do anything at the mo!
use XML::XPath;
use XML::XPath::XMLParser;

sub debug {
    warn @_,"\n" if $DEBUG;
}

sub parse {
    my ( $translator, $data ) = @_;
    my $schema   = $translator->schema;
    local $DEBUG = $translator->debug;
    #local $TRACE  = $translator->trace ? 1 : undef;
    # Nothing with trace option yet!

    my $xp = XML::XPath->new(xml => $data);
    $xp->set_namespace("sqlf", "http://sqlfairy.sourceforge.net/sqlfairy.xml");

    # Work our way through the tables
    #
    my @nodes = $xp->findnodes('/sqlf:schema/sqlf:table');
    for my $tblnode (
        sort { "".$xp->findvalue('sqlf:order',$a)
               <=> "".$xp->findvalue('sqlf:order',$b) } @nodes
    ) {
        debug "Adding table:".$xp->findvalue('sqlf:name',$tblnode);
        my $table = $schema->add_table(
            get_tagfields($xp, $tblnode, "sqlf:" => qw/name order/)
        ) or die $schema->error;

        # Fields
        #
        my @nodes = $xp->findnodes('sqlf:fields/sqlf:field',$tblnode);
        foreach (
            sort { ("".$xp->findvalue('sqlf:order',$a) || 0)
                   <=> ("".$xp->findvalue('sqlf:order',$b) || 0) } @nodes
        ) {
            my %fdata = get_tagfields($xp, $_, "sqlf:",
            qw/name data_type size default_value is_nullable is_auto_increment
               is_primary_key is_foreign_key comments/);
            if (exists $fdata{default_value} and defined $fdata{default_value}){
                if ( $fdata{default_value} =~ /^\s*NULL\s*$/ ) {
                    $fdata{default_value}= undef;
                }
                elsif ( $fdata{default_value} =~ /^\s*EMPTY_STRING\s*$/ ) {
                    $fdata{default_value} = "";
                }
            }
            my $field = $table->add_field(%fdata) or die $schema->error;
            $table->primary_key($field->name) if $fdata{'is_primary_key'};
                # TODO We should be able to make the table obj spot this when we
                # use add_field.
            # TODO Deal with $field->extra
        }

        # Constraints
        #
        @nodes = $xp->findnodes('sqlf:constraints/sqlf:constraint',$tblnode);
        foreach (@nodes) {
            my %data = get_tagfields($xp, $_, "sqlf:",
            qw/name type table fields reference_fields reference_table
               match_type on_delete_do on_update_do/);
            $table->add_constraint(%data) or die $schema->error;
        }

        # Indexes
        #
        @nodes = $xp->findnodes('sqlf:indices/sqlf:index',$tblnode);
        foreach (@nodes) {
            my %data = get_tagfields($xp, $_, "sqlf:",
            qw/name type fields options/);
            $table->add_index(%data) or die $schema->error;
        }

    } # tables loop

    return 1;
}

# get_tagfields XPNODE, NAMESPACE => qw/TAGNAMES/;
# get_tagfields $node, "sqlf:" => qw/name type fields reference/;
#
# Returns hash of data. If a tag isn't in the file it is not in this
# hash.
# TODO Add handling of and explicit NULL value.
sub get_tagfields {
    my ($xp, $node, @names) = @_;
    my (%data, $ns);
    foreach (@names) {
        if ( m/:$/ ) { $ns = $_; next; }  # Set def namespace
        my $thisns = (s/(^.*?:)// ? $1 : $ns);
        foreach my $path ( "\@$thisns$_","$thisns$_") {
            $data{$_} = $xp->findvalue($path,$node) if $xp->exists($path,$node);
            debug "Got $_=".(defined $data{$_} ? $data{$_} : "UNDEF");
        }
    }
    return wantarray ? %data : \%data;
}

1;

__END__

=pod

=head1 BUGS

B<Empty Tags> e.g. <sqlf:default_value/> Will be parsed as "" and hence also
false. This is a bit counter intuative for some tags as seeing
<sqlf:is_nullable /> you might think that it was set when it fact it wouldn't
be. So for now it is safest not to use them until their handling by the parser
is defined.

=head1 TODO

 * Support sqf:options.
 * Test forign keys are parsed ok.
 * Sort out sane handling of empty tags <foo/> vs tags with no content
   <foo></foo> vs it no tag being there.
 * Control over defaulting of non-existant tags.

=head1 AUTHOR

Mark D. Addison E<lt>mark.addison@itn.co.ukE<gt>,

=head1 SEE ALSO

perl(1), SQL::Translator, SQL::Translator::Producer::SqlfXML,
SQL::Translator::Schema.

=cut
