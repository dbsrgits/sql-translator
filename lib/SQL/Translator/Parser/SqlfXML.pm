package SQL::Translator::Parser::SqlfXML;

# -------------------------------------------------------------------
# $Id: SqlfXML.pm,v 1.2 2003-08-06 22:08:16 grommit Exp $
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

To see and example of the XML translate one of your schema :) e.g.

 $ sql_translator.pl --from MySQL --to SqftXML foo_schema.sql

==head1 default_value

Leave the tag out all together to use the default in Schema::Field. Use empty
tags or EMPTY_STRING for a zero lenth string. NULL for an explicit null 
(currently sets default_value to undef Schema::Field).

 <sqlf:default_value></sqlf:default_value>               <!-- Empty string -->
 <sqlf:default_value>EMPTY_STRING</sqlf:default_value>   <!-- Empty string -->
 <sqlf:default_value>NULL</sqlf:default_value>           <!-- NULL -->
 
=cut

use strict;
use warnings;

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/;
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
            sort { "".$xp->findvalue('sqlf:order',$a)
                   <=> "".$xp->findvalue('sqlf:order',$b) } @nodes
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
        my $path = (s/(^.*?:)// ? $1 : $ns).$_;
        $data{$_} = $xp->findvalue($path,$node) if $xp->exists($path,$node);
        debug "Got $_=".(defined $data{$_} ? $data{$_} : "UNDEF");
    }
    return wantarray ? %data : \%data;
}

1;

__END__

=pod

=head1 TODO

 * Support sqf:options.
 * Test forign keys are parsed ok.
 * Control over defaulting of non-existant tags.

=head1 AUTHOR

Mark D. Addison E<lt>mark.addison@itn.co.ukE<gt>,

=head1 SEE ALSO

perl(1), SQL::Translator, SQL::Translator::Producer::SqlfXML,
SQL::Translator::Schema.

=cut
