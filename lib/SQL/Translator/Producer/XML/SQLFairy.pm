package SQL::Translator::Producer::XML::SQLFairy;

=pod

=head1 NAME

SQL::Translator::Producer::XML::SQLFairy - SQLFairy's default XML format

=head1 SYNOPSIS

  use SQL::Translator;

  my $t              = SQL::Translator->new(
      from           => 'MySQL',
      to             => 'XML-SQLFairy',
      filename       => 'schema.sql',
      show_warnings  => 1,
  );

  print $t->translate;

=head1 DESCRIPTION

Creates XML output of a schema, in the flavor of XML used natively by the
SQLFairy project (L<SQL::Translator>). This format is detailed here.

The XML lives in the C<http://sqlfairy.sourceforge.net/sqlfairy.xml> namespace.
With a root element of <schema>.

Objects in the schema are mapped to tags of the same name as the objects class
(all lowercase).

The attributes of the objects (e.g. $field->name) are mapped to attributes of
the tag, except for sql, comments and action, which get mapped to child data
elements.

List valued attributes (such as the list of fields in an index)
get mapped to comma separated lists of values in the attribute.

Child objects, such as a tables fields, get mapped to child tags wrapped in a
set of container tags using the plural of their contained classes name.

An objects' extra attribute (a hash of arbitrary data) is
mapped to a tag called extra, with the hash of data as attributes, sorted into
alphabetical order.

e.g.

    <schema name="" database=""
      xmlns="http://sqlfairy.sourceforge.net/sqlfairy.xml">

      <tables>
        <table name="Story" order="1">
          <fields>
            <field name="id" data_type="BIGINT" size="20"
              is_nullable="0" is_auto_increment="1" is_primary_key="1"
              is_foreign_key="0" order="3">
              <extra ZEROFILL="1" />
              <comments></comments>
            </field>
            <field name="created" data_type="datetime" size="0"
              is_nullable="1" is_auto_increment="0" is_primary_key="0"
              is_foreign_key="0" order="1">
              <extra />
              <comments></comments>
            </field>
            ...
          </fields>
          <indices>
            <index name="foobar" type="NORMAL" fields="foo,bar" options="" />
          </indices>
        </table>
      </tables>

      <views>
        <view name="email_list" fields="email" order="1">
          <sql>SELECT email FROM Basic WHERE email IS NOT NULL</sql>
        </view>
      </views>

    </schema>

To see a complete example of the XML translate one of your schema :)

  $ sqlt -f MySQL -t XML-SQLFairy schema.sql

=head1 ARGS

=over 4

=item add_prefix

Set to true to use the default namespace prefix of 'sqlf', instead of using
the default namespace for
C<http://sqlfairy.sourceforge.net/sqlfairy.xml namespace>

e.g.

 <!-- add_prefix=0 -->
 <field name="foo" />

 <!-- add_prefix=1 -->
 <sqlf:field name="foo" />

=item prefix

Set to the namespace prefix you want to use for the
C<http://sqlfairy.sourceforge.net/sqlfairy.xml namespace>

e.g.

 <!-- prefix='foo' -->
 <foo:field name="foo" />

=item newlines

If true (the default) inserts newlines around the XML, otherwise the schema is
written on one line.

=item indent

When using newlines the number of whitespace characters to use as the indent.
Default is 2, set to 0 to turn off indenting.

=back

=head1 LEGACY FORMAT

The previous version of the SQLFairy XML allowed the attributes of the the
schema objects to be written as either xml attributes or as data elements, in
any combination. The old producer could produce attribute only or data element
only versions. While this allowed for lots of flexibility in writing the XML
the result is a great many possible XML formats, not so good for DTD writing,
XPathing etc! So we have moved to a fixed version described above.

This version of the producer will now only produce the new style XML.
To convert your old format files simply pass them through the translator :)

 $ sqlt -f XML-SQLFairy -t XML-SQLFairy schema-old.xml > schema-new.xml

=cut

use strict;
use warnings;
our @EXPORT_OK;
our $VERSION = '1.59';

use Exporter;
use base qw(Exporter);
@EXPORT_OK = qw(produce);

use IO::Scalar;
use SQL::Translator::Utils qw(header_comment debug);
BEGIN {
    # Will someone fix XML::Writer already?
    local $^W = 0;
    require XML::Writer;
    import XML::Writer;
}

# Which schema object attributes (methods) to write as xml elements rather than
# as attributes. e.g. <comments>blah, blah...</comments>
my @MAP_AS_ELEMENTS = qw/sql comments action extra/;



my $Namespace = 'http://sqlfairy.sourceforge.net/sqlfairy.xml';
my $Name      = 'sqlf';
my $PArgs     = {};
my $no_comments;

sub produce {
    my $translator  = shift;
    my $schema      = $translator->schema;
    $no_comments    = $translator->no_comments;
    $PArgs          = $translator->producer_args;
    my $newlines    = defined $PArgs->{newlines} ? $PArgs->{newlines} : 1;
    my $indent      = defined $PArgs->{indent}   ? $PArgs->{indent}   : 2;
    my $io          = IO::Scalar->new;

    # Setup the XML::Writer and set the namespace
    my $prefix = "";
    $prefix    = $Name            if $PArgs->{add_prefix};
    $prefix    = $PArgs->{prefix} if $PArgs->{prefix};
    my $xml         = XML::Writer->new(
        OUTPUT      => $io,
        NAMESPACES  => 1,
        PREFIX_MAP  => { $Namespace => $prefix },
        DATA_MODE   => $newlines,
        DATA_INDENT => $indent,
    );

    # Start the document
    $xml->xmlDecl('UTF-8');

    $xml->comment(header_comment('', ''))
      unless $no_comments;

    xml_obj($xml, $schema,
        tag => "schema", methods => [qw/name database extra/], end_tag => 0 );

    #
    # Table
    #
    $xml->startTag( [ $Namespace => "tables" ] );
    for my $table ( $schema->get_tables ) {
        debug "Table:",$table->name;
        xml_obj($xml, $table,
             tag => "table",
             methods => [qw/name order extra/],
             end_tag => 0
         );

        #
        # Fields
        #
        xml_obj_children( $xml, $table,
            tag   => 'field',
            methods =>[qw/
                name data_type size is_nullable default_value is_auto_increment
                is_primary_key is_foreign_key extra comments order
            /],
        );

        #
        # Indices
        #
        xml_obj_children( $xml, $table,
            tag   => 'index',
            collection_tag => "indices",
            methods => [qw/name type fields options extra/],
        );

        #
        # Constraints
        #
        xml_obj_children( $xml, $table,
            tag   => 'constraint',
            methods => [qw/
                name type fields reference_table reference_fields
                on_delete on_update match_type expression options deferrable
                extra
            /],
        );

        #
        # Comments
        #
        xml_obj_children( $xml, $table,
            tag   => 'comment',
            collection_tag => "comments",
            methods => [qw/
                comments
            /],
        );

        $xml->endTag( [ $Namespace => 'table' ] );
    }
    $xml->endTag( [ $Namespace => 'tables' ] );

    #
    # Views
    #
    xml_obj_children( $xml, $schema,
        tag   => 'view',
        methods => [qw/name sql fields order extra/],
    );

    #
    # Tiggers
    #
    xml_obj_children( $xml, $schema,
        tag    => 'trigger',
        methods => [qw/name database_events action on_table perform_action_when
            fields order extra/],
    );

    #
    # Procedures
    #
    xml_obj_children( $xml, $schema,
        tag   => 'procedure',
        methods => [qw/name sql parameters owner comments order extra/],
    );

    $xml->endTag([ $Namespace => 'schema' ]);
    $xml->end;

    return $io;
}


#
# Takes and XML::Write object, Schema::* parent object, the tag name,
# the collection name and a list of methods (of the children) to write as XML.
# The collection name defaults to the name with an s on the end and is used to
# work out the method to get the children with. eg a name of 'foo' gives a
# collection of foos and gets the members using ->get_foos.
#
sub xml_obj_children {
    my ($xml,$parent) = (shift,shift);
    my %args = @_;
    my ($name,$collection_name,$methods)
        = @args{qw/tag collection_tag methods/};
    $collection_name ||= "${name}s";

    my $meth;
    if ( $collection_name eq 'comments' ) {
      $meth = 'comments';
    } else {
      $meth = "get_$collection_name";
    }

    my @kids = $parent->$meth;
    #@kids || return;
    $xml->startTag( [ $Namespace => $collection_name ] );

    for my $obj ( @kids ) {
        if ( $collection_name eq 'comments' ){
            $xml->dataElement( [ $Namespace => 'comment' ], $obj );
        } else {
            xml_obj($xml, $obj,
                tag     => "$name",
                end_tag => 1,
                methods => $methods,
            );
        }
    }
    $xml->endTag( [ $Namespace => $collection_name ] );
}

#
# Takes an XML::Writer, Schema::* object and list of method names
# and writes the obect out as XML. All methods values are written as attributes
# except for the methods listed in @MAP_AS_ELEMENTS which get written as child
# data elements.
#
# The attributes/tags are written in the same order as the method names are
# passed.
#
# TODO
# - Should the Namespace be passed in instead of global? Pass in the same
#   as Writer ie [ NS => TAGNAME ]
#
my $elements_re = join("|", @MAP_AS_ELEMENTS);
$elements_re = qr/^($elements_re)$/;
sub xml_obj {
    my ($xml, $obj, %args) = @_;
    my $tag                = $args{'tag'}              || '';
    my $end_tag            = $args{'end_tag'}          || '';
    my @meths              = @{ $args{'methods'} };
    my $empty_tag          = 0;

    # Use array to ensure consistant (ie not hash) ordering of attribs
    # The order comes from the meths list passed in.
    my @tags;
    my @attr;
    foreach ( grep { defined $obj->$_ } @meths ) {
        my $what = m/$elements_re/ ? \@tags : \@attr;
        my $val = $_ eq 'extra'
            ? { $obj->$_ }
            : $obj->$_;
        $val = ref $val eq 'ARRAY' ? join(',', @$val) : $val;
        push @$what, $_ => $val;
    };
    my $child_tags = @tags;
    $end_tag && !$child_tags
        ? $xml->emptyTag( [ $Namespace => $tag ], @attr )
        : $xml->startTag( [ $Namespace => $tag ], @attr );
    while ( my ($name,$val) = splice @tags,0,2 ) {
        if ( ref $val eq 'HASH' ) {
             $xml->emptyTag( [ $Namespace => $name ],
                 map { ($_, $val->{$_}) } sort keys %$val );
        }
        else {
            $xml->dataElement( [ $Namespace => $name ], $val );
        }
    }
    $xml->endTag( [ $Namespace => $tag ] ) if $child_tags && $end_tag;
}

1;

# -------------------------------------------------------------------
# The eyes of fire, the nostrils of air,
# The mouth of water, the beard of earth.
# William Blake
# -------------------------------------------------------------------

=pod

=head1 AUTHORS

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>,
Darren Chamberlain E<lt>darren@cpan.orgE<gt>,
Mark Addison E<lt>mark.addison@itn.co.ukE<gt>.

=head1 SEE ALSO

L<perl(1)>, L<SQL::Translator>, L<SQL::Translator::Parser::XML::SQLFairy>,
L<SQL::Translator::Schema>, L<XML::Writer>.

=cut
