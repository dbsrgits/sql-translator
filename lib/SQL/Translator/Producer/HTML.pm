package SQL::Translator::Producer::HTML;

use strict;
use warnings;
use Data::Dumper;

our $VERSION     = '1.66';
our $NAME        = __PACKAGE__;
our $NOWRAP      = 0 unless defined $NOWRAP;
our $NOLINKTABLE = 0 unless defined $NOLINKTABLE;

# Emit XHTML by default
$CGI::XHTML = $CGI::XHTML = 42;

use SQL::Translator::Schema::Constants;

# -------------------------------------------------------------------
# Main entry point.  Returns a string containing HTML.
# -------------------------------------------------------------------
sub produce {
  my $t           = shift;
  my $args        = $t->producer_args;
  my $schema      = $t->schema;
  my $schema_name = $schema->name    || 'Schema';
  my $title       = $args->{'title'} || "Description of $schema_name";
  my $wrap        = !(
    defined $args->{'nowrap'}
    ? $args->{'nowrap'}
    : $NOWRAP
  );
  my $linktable = !(
    defined $args->{'nolinktable'}
    ? $args->{'nolinktable'}
    : $NOLINKTABLE
  );
  my %stylesheet
      = defined $args->{'stylesheet'}
      ? (-style => { src => $args->{'stylesheet'} })
      : ();
  my @html;
  my $q = defined $args->{'pretty'}
      ? do {
        require CGI::Pretty;
        import CGI::Pretty;
        CGI::Pretty->new;
      }
      : do {
        require CGI;
        import CGI;
        CGI->new;
      };
  my ($table, @table_names);

  if ($wrap) {
    push @html,
        $q->start_html({
          -title => $title,
          %stylesheet,
          -meta => { generator => $NAME },
        }),
        $q->h1({ -class => 'SchemaDescription' }, $title),
        $q->hr;
  }

  @table_names = grep { length $_->name } $schema->get_tables;

  if ($linktable) {

    # Generate top menu, with links to full table information
    my $count = scalar(@table_names);
    $count = sprintf "%d table%s", $count, $count == 1 ? '' : 's';

    # Leading table of links
    push @html,
        $q->comment("Table listing ($count)"),
        $q->a({ -name => 'top' }),
        $q->start_table({ -width => '100%', -class => 'LinkTable' }),

        # XXX This needs to be colspan="$#{$table->fields}" class="LinkTableHeader"
        $q->Tr($q->td({ -class => 'LinkTableCell' }, $q->h2({ -class => 'LinkTableTitle' }, 'Tables'),),);

    for my $table (@table_names) {
      my $table_name = $table->name;
      push @html, $q->comment("Start link to table '$table_name'"),
          $q->Tr({ -class => 'LinkTableRow' },
            $q->td({ -class => 'LinkTableCell' }, qq[<a id="${table_name}-link" href="#$table_name">$table_name</a>])),
          $q->comment("End link to table '$table_name'");
    }
    push @html, $q->end_table;
  }

  for my $table ($schema->get_tables) {
    my $table_name = $table->name       or next;
    my @fields     = $table->get_fields or next;
    push @html, $q->comment("Starting table '$table_name'"), $q->a({ -name => $table_name }),
        $q->table(
          { -class => 'TableHeader', -width => '100%' },
          $q->Tr(
            { -class => 'TableHeaderRow' },
            $q->td({ -class => 'TableHeaderCell' }, $q->h3($table_name)),
            qq[<a name="$table_name">],
            $q->td({ -class => 'TableHeaderCell', -align => 'right' }, qq[<a href="#top">Top</a>])
          )
        );

    if (my @comments = map { $_ ? $_ : () } $table->comments) {
      push @html, $q->b("Comments:"), $q->br, $q->em(map { $q->br, $_ } @comments);
    }

    #
    # Fields
    #
    push @html, $q->start_table({ -border => 1 }),
        $q->Tr($q->th(
          { -class => 'FieldHeader' },
          [ 'Field Name', 'Data Type', 'Size', 'Default Value', 'Other', 'Foreign Key' ]
        ));

    my $i = 0;
    for my $field (@fields) {
      my $name = $field->name || '';
      $name = qq[<a name="$table_name-$name">$name</a>];
      my $data_type = $field->data_type || '';
      my $size      = defined $field->size          ? $field->size          : '';
      my $default   = defined $field->default_value ? $field->default_value : '';
      my $comment   = $field->comments || '';
      my $fk        = '';

      if ($field->is_foreign_key) {
        my $c         = $field->foreign_key_reference;
        my $ref_table = $c->reference_table       || '';
        my $ref_field = ($c->reference_fields)[0] || '';
        $fk = qq[<a href="#$ref_table-$ref_field">$ref_table.$ref_field</a>];
      }

      my @other = ();
      push @other, 'PRIMARY KEY' if $field->is_primary_key;
      push @other, 'UNIQUE'      if $field->is_unique;
      push @other, 'NOT NULL' unless $field->is_nullable;
      push @other, $comment if $comment;
      my $class = $i++ % 2 ? 'even' : 'odd';
      push @html,
          $q->Tr(
            { -class => "tr-$class" },
            $q->td({ -class => "FieldCellName" },    $name),
            $q->td({ -class => "FieldCellType" },    $data_type),
            $q->td({ -class => "FieldCellSize" },    $size),
            $q->td({ -class => "FieldCellDefault" }, $default),
            $q->td({ -class => "FieldCellOther" },   join(', ', @other)),
            $q->td({ -class => "FieldCellFK" },      $fk),
          );
    }
    push @html, $q->end_table;

    #
    # Indices
    #
    if (my @indices = $table->get_indices) {
      push @html,
          $q->h3('Indices'),
          $q->start_table({ -border => 1 }),
          $q->Tr({ -class => 'IndexRow' }, $q->th([ 'Name', 'Fields' ]));

      for my $index (@indices) {
        my $name   = $index->name               || '';
        my $fields = join(', ', $index->fields) || '';

        push @html, $q->Tr({ -class => 'IndexCell' }, $q->td([ $name, $fields ]));
      }

      push @html, $q->end_table;
    }

    #
    # Constraints
    #
    my @constraints = grep { $_->type ne PRIMARY_KEY } $table->get_constraints;
    if (@constraints) {
      push @html,
          $q->h3('Constraints'),
          $q->start_table({ -border => 1 }),
          $q->Tr({ -class => 'IndexRow' }, $q->th([ 'Type', 'Fields' ]));

      for my $c (@constraints) {
        my $type   = $c->type               || '';
        my $fields = join(', ', $c->fields) || '';

        push @html, $q->Tr({ -class => 'IndexCell' }, $q->td([ $type, $fields ]));
      }

      push @html, $q->end_table;
    }

    push @html, $q->hr;
  }

  my $sqlt_version = $t->version;
  if ($wrap) {
    push @html,
        qq[Created by <a href="http://sqlfairy.sourceforge.net">],
        qq[SQL::Translator $sqlt_version</a>],
        $q->end_html;
  }

  return join "\n", @html;
}

1;

# -------------------------------------------------------------------
# Always be ready to speak your mind,
# and a base man will avoid you.
# William Blake
# -------------------------------------------------------------------

=head1 NAME

SQL::Translator::Producer::HTML - HTML producer for SQL::Translator

=head1 SYNOPSIS

  use SQL::Translator::Producer::HTML;

=head1 DESCRIPTION

Creates an HTML document describing the tables.

The HTML produced is composed of a number of tables:

=over 4

=item Links

A link table sits at the top of the output, and contains anchored
links to elements in the rest of the document.

If the I<nolinktable> producer arg is present, then this table is not
produced.

=item Tables

Each table in the schema has its own HTML table.  The top row is a row
of E<lt>thE<gt> elements, with a class of B<FieldHeader>; these
elements are I<Field Name>, I<Data Type>, I<Size>, I<Default Value>,
I<Other> and I<Foreign Key>.  Each successive row describes one field
in the table, and has a class of B<FieldCell$item>, where $item id
corresponds to the label of the column.  For example:

    <tr>
        <td class="FieldCellName"><a name="random-id">id</a></td>
        <td class="FieldCellType">int</td>
        <td class="FieldCellSize">11</td>
        <td class="FieldCellDefault"></td>
        <td class="FieldCellOther">PRIMARY KEY, NOT NULL</td>
        <td class="FieldCellFK"></td>
    </tr>

    <tr>
        <td class="FieldCellName"><a name="random-foo">foo</a></td>
        <td class="FieldCellType">varchar</td>
        <td class="FieldCellSize">255</td>
        <td class="FieldCellDefault"></td>
        <td class="FieldCellOther">NOT NULL</td>
        <td class="FieldCellFK"></td>
    </tr>

    <tr>
        <td class="FieldCellName"><a name="random-updated">updated</a></td>
        <td class="FieldCellType">timestamp</td>
        <td class="FieldCellSize">0</td>
        <td class="FieldCellDefault"></td>
        <td class="FieldCellOther"></td>
        <td class="FieldCellFK"></td>
    </tr>

=back

Unless the I<nowrap> producer arg is present, the HTML will be
enclosed in a basic HTML header and footer.

If the I<pretty> producer arg is present, the generated HTML will be
nicely spaced and human-readable.  Otherwise, it will have very little
insignificant whitespace and be generally smaller.


=head1 AUTHORS

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>,
Darren Chamberlain E<lt>darren@cpan.orgE<gt>.

=cut
