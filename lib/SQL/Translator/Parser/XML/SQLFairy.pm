package SQL::Translator::Parser::XML::SQLFairy;

=head1 NAME

SQL::Translator::Parser::XML::SQLFairy - parser for SQL::Translator's XML.

=head1 SYNOPSIS

  use SQL::Translator;

  my $translator = SQL::Translator->new( show_warnings  => 1 );

  my $out = $obj->translate(
      from     => 'XML-SQLFairy',
      to       => 'MySQL',
      filename => 'schema.xml',
  ) or die $translator->error;

  print $out;

=head1 DESCRIPTION

This parser handles the flavor of XML used natively by the SQLFairy
project (L<SQL::Translator>).  The XML must be in the namespace
"http://sqlfairy.sourceforge.net/sqlfairy.xml."
See L<SQL::Translator::Producer::XML::SQLFairy> for details of this format.

You do not need to specify every attribute of the Schema objects as any missing
from the XML will be set to their default values. e.g. A field could be written
using only;

 <sqlf:field name="email" data_type="varchar" size="255" />

Instead of the full;

 <sqlf:field name="email" data_type="varchar" size="255" is_nullable="1"
   is_auto_increment="0" is_primary_key="0" is_foreign_key="0" order="4">
   <sqlf:comments></sqlf:comments>
 </sqlf:field>

If you do not explicitly set the order of items using order attributes on the
tags then the order the tags appear in the XML will be used.

=head2 default_value

Leave the attribute out all together to use the default in L<Schema::Field>.
Use empty quotes or 'EMPTY_STRING' for a zero lenth string. 'NULL' for an
explicit null (currently sets default_value to undef in the
Schema::Field obj).

  <sqlf:field default_value="" />                <!-- Empty string -->
  <sqlf:field default_value="EMPTY_STRING" />    <!-- Empty string -->
  <sqlf:field default_value="NULL" />            <!-- NULL -->

=head2 ARGS

Doesn't take any extra parser args at the moment.

=head1 LEGACY FORMAT

The previous version of the SQLFairy XML allowed the attributes of the the
schema objects to be written as either xml attributes or as data elements, in
any combination. While this allows for lots of flexibility in writing the XML
the result is a great many possible XML formats, not so good for DTD writing,
XPathing etc! So we have moved to a fixed version described in
L<SQL::Translator::Producer::XML::SQLFairy>.

This version of the parser will still parse the old formats and emmit warnings
when it sees them being used but they should be considered B<heavily
depreciated>.

To convert your old format files simply pass them through the translator :)

 $ sqlt -f XML-SQLFairy -t XML-SQLFairy schema-old.xml > schema-new.xml

=cut

use strict;
use warnings;

our ( $DEBUG, @EXPORT_OK );
our $VERSION = '1.59';
$DEBUG   = 0 unless defined $DEBUG;

use Data::Dumper;
use Carp::Clan qw/^SQL::Translator/;
use Exporter;
use base qw(Exporter);
@EXPORT_OK = qw(parse);

use base qw/SQL::Translator::Parser/;  # Doesnt do anything at the mo!
use SQL::Translator::Utils 'debug';
use XML::LibXML;
use XML::LibXML::XPathContext;

sub parse {
    my ( $translator, $data ) = @_;
    my $schema                = $translator->schema;
    local $DEBUG              = $translator->debug;
    my $doc                   = XML::LibXML->new->parse_string($data);
    my $xp                    = XML::LibXML::XPathContext->new($doc);

    $xp->registerNs("sqlf", "http://sqlfairy.sourceforge.net/sqlfairy.xml");

    #
    # Work our way through the tables
    #
    my @nodes = $xp->findnodes(
        '/sqlf:schema/sqlf:table|/sqlf:schema/sqlf:tables/sqlf:table'
    );
    for my $tblnode (
        sort {
            ("".$xp->findvalue('sqlf:order|@order',$a) || 0)
            <=>
            ("".$xp->findvalue('sqlf:order|@order',$b) || 0)
        } @nodes
    ) {
        debug "Adding table:".$xp->findvalue('sqlf:name',$tblnode);

        my $table = $schema->add_table(
            get_tagfields($xp, $tblnode, "sqlf:" => qw/name order extra/)
        ) or die $schema->error;

        #
        # Fields
        #
        my @nodes = $xp->findnodes('sqlf:fields/sqlf:field',$tblnode);
        foreach (
            sort {
                ("".$xp->findvalue('sqlf:order',$a) || 0)
                <=>
                ("".$xp->findvalue('sqlf:order',$b) || 0)
            } @nodes
        ) {
            my %fdata = get_tagfields($xp, $_, "sqlf:",
                qw/name data_type size default_value is_nullable extra
                is_auto_increment is_primary_key is_foreign_key comments/
            );

            if (
                exists $fdata{'default_value'} and
                defined $fdata{'default_value'}
            ) {
                if ( $fdata{'default_value'} =~ /^\s*NULL\s*$/ ) {
                    $fdata{'default_value'}= undef;
                }
                elsif ( $fdata{'default_value'} =~ /^\s*EMPTY_STRING\s*$/ ) {
                    $fdata{'default_value'} = "";
                }
            }

            my $field = $table->add_field( %fdata ) or die $table->error;

            $table->primary_key( $field->name ) if $fdata{'is_primary_key'};

            #
            # TODO:
            # - We should be able to make the table obj spot this when
            #   we use add_field.
            #
        }

        #
        # Constraints
        #
        @nodes = $xp->findnodes('sqlf:constraints/sqlf:constraint',$tblnode);
        foreach (@nodes) {
            my %data = get_tagfields($xp, $_, "sqlf:",
                qw/name type table fields reference_fields reference_table
                match_type on_delete on_update extra/
            );
            $table->add_constraint( %data ) or die $table->error;
        }

        #
        # Indexes
        #
        @nodes = $xp->findnodes('sqlf:indices/sqlf:index',$tblnode);
        foreach (@nodes) {
            my %data = get_tagfields($xp, $_, "sqlf:",
                qw/name type fields options extra/);
            $table->add_index( %data ) or die $table->error;
        }


        #
        # Comments
        #
        @nodes = $xp->findnodes('sqlf:comments/sqlf:comment',$tblnode);
        foreach (@nodes) {
            my $data = $_->string_value;
            $table->comments( $data );
        }

    } # tables loop

    #
    # Views
    #
    @nodes = $xp->findnodes(
        '/sqlf:schema/sqlf:view|/sqlf:schema/sqlf:views/sqlf:view'
    );
    foreach (@nodes) {
        my %data = get_tagfields($xp, $_, "sqlf:",
            qw/name sql fields order extra/
        );
        $schema->add_view( %data ) or die $schema->error;
    }

    #
    # Triggers
    #
    @nodes = $xp->findnodes(
        '/sqlf:schema/sqlf:trigger|/sqlf:schema/sqlf:triggers/sqlf:trigger'
    );
    foreach (@nodes) {
        my %data = get_tagfields($xp, $_, "sqlf:", qw/
            name perform_action_when database_event database_events fields
            on_table action order extra
        /);

        # back compat
        if (my $evt = $data{database_event} and $translator->{show_warnings}) {
          carp 'The database_event tag is deprecated - please use ' .
            'database_events (which can take one or more comma separated ' .
            'event names)';
          $data{database_events} = join (', ',
            $data{database_events} || (),
            $evt,
          );
        }

        # split into arrayref
        if (my $evts = $data{database_events}) {
          $data{database_events} = [split (/\s*,\s*/, $evts) ];
        }

        $schema->add_trigger( %data ) or die $schema->error;
    }

    #
    # Procedures
    #
    @nodes = $xp->findnodes(
       '/sqlf:schema/sqlf:procedure|/sqlf:schema/sqlf:procedures/sqlf:procedure'
    );
    foreach (@nodes) {
        my %data = get_tagfields($xp, $_, "sqlf:",
        qw/name sql parameters owner comments order extra/
        );
        $schema->add_procedure( %data ) or die $schema->error;
    }

    return 1;
}

sub get_tagfields {
#
# get_tagfields XP, NODE, NAMESPACE => qw/TAGNAMES/;
# get_tagfields $node, "sqlf:" => qw/name type fields reference/;
#
# Returns hash of data.
# TODO - Add handling of an explicit NULL value.
#

    my ($xp, $node, @names) = @_;
    my (%data, $ns);
    foreach (@names) {
        if ( m/:$/ ) { $ns = $_; next; }  # Set def namespace
        my $thisns = (s/(^.*?:)// ? $1 : $ns);

        my $is_attrib = m/^(sql|comments|action|extra)$/ ? 0 : 1;

        my $attrib_path = "\@$_";
        my $tag_path    = "$thisns$_";
        if ( my $found = $xp->find($attrib_path,$node) ) {
            $data{$_} = "".$found->to_literal;
            warn "Use of '$_' as an attribute is depricated."
                ." Use a child tag instead."
                ." To convert your file to the new version see the Docs.\n"
                unless $is_attrib;
            debug "Got $_=".( defined $data{ $_ } ? $data{ $_ } : 'UNDEF' );
        }
        elsif ( $found = $xp->find($tag_path,$node) ) {
            if ($_ eq "extra") {
                my %extra;
                foreach ( $found->pop->getAttributes ) {
                    $extra{$_->getName} = $_->getData;
                }
                $data{$_} = \%extra;
            }
            else {
                $data{$_} = "".$found->to_literal;
            }
            warn "Use of '$_' as a child tag is depricated."
                ." Use an attribute instead."
                ." To convert your file to the new version see the Docs.\n"
                if $is_attrib;
            debug "Got $_=".( defined $data{ $_ } ? $data{ $_ } : 'UNDEF' );
        }
    }

    return wantarray ? %data : \%data;
}

1;

=pod

=head1 BUGS

Ignores the order attribute for Constraints, Views, Indices, Views, Triggers
and Procedures, using the tag order instead. (This is the order output by the
SQLFairy XML producer).

=head1 SEE ALSO

L<perl>, L<SQL::Translator>, L<SQL::Translator::Producer::XML::SQLFairy>,
L<SQL::Translator::Schema>.

=head1 TODO

=over 4

=item *

Support options attribute.

=item *

Test foreign keys are parsed ok.

=item *

Control over defaulting.

=back

=head1 AUTHOR

Mark D. Addison E<lt>mark.addison@itn.co.ukE<gt>,
Jonathan Yu E<lt>frequency@cpan.orgE<gt>

=cut
