package SQL::Translator::Producer::TTSchema;

=pod

=head1 NAME

SQL::Translator::Producer::TTSchema -
    Produces output using the Template Toolkit from a SQL schema

=head1 SYNOPSIS

  use SQL::Translator;
  my $translator     = SQL::Translator->new(
      from           => 'MySQL',
      filename       => 'foo_schema.sql',
      to             => 'TTSchema',
      producer_args  => {
          ttfile     => 'foo_template.tt',  # Template file to use

          # Extra template variables
          tt_vars     => {
              author => "Mr Foo",
          },

          # Template config options
          tt_conf     => {
              INCLUDE_PATH => '/foo/templates',
          },
      },
  );
  print $translator->translate;

=head1 DESCRIPTION

Produces schema output using a given Template Tookit template.

It needs one additional producer arg of C<ttfile> which is the file
name of the template to use.  This template will be passed a variable
called C<schema>, which is the C<SQL::Translator::Producer::Schema> object
created by the parser. You can then use it to walk the schema via the
methods documented in that module.

Here's a brief example of what the template could look like:

  database: [% schema.database %]
  tables:
  [% FOREACH table = schema.get_tables %]
      [% table.name %]
      ================
      [% FOREACH field = table.get_fields %]
          [% field.name %]   [% field.data_type %]([% field.size %])
      [% END -%]
  [% END %]

See F<t/data/template/basic.tt> for a more complete example.

The template will also get the set of extra variables given as a
hashref via the C<tt_vars> producer arg. (Note that the old style of
passing this config in the C<ttargs> producer arg has been
deprecated).

You can set any of the options used to initialize the Template object by
adding a C<tt_conf> producer arg. See Template Toolkit docs for details of
the options.
(Note that the old style of passing this config directly in the C<ttargs> producer args
has been deprecated).


  $translator          = SQL::Translator->new(
      to               => 'TT',
      producer_args    => {
          ttfile       => 'foo_template.tt',
          tt_vars      => {},
          tt_conf      => {
            INCLUDE_PATH => '/foo/templates/tt',
            INTERPOLATE  => 1,
          }
      },
  );

You can use this producer to create any type of text output you like,
even using it to create your own versions of what the other producers
make.  For example, you could create a template that translates the
schema into MySQL's syntax, your own HTML documentation, your own
Class::DBI classes (or some other code) -- the opportunities are
limitless!

=head2 Producer Args

=over 4

=item ttfile

The template file to generate the output with.

=item tt_vars

A hash ref of extra variables you want to add to the template.

=item tt_conf

A hash ref of configuration options to pass to the L<Template> object's
constructor.

=back

=cut

use strict;
use warnings;

our ($DEBUG, @EXPORT_OK);
our $VERSION = '1.66';
$DEBUG = 0 unless defined $DEBUG;

use Template;
use Data::Dumper;
use Exporter;
use base qw(Exporter);
@EXPORT_OK = qw(produce);

use SQL::Translator::Utils 'debug';

sub produce {
  my $translator = shift;
  local $DEBUG = $translator->debug;
  my $scma = $translator->schema;
  my $args = $translator->producer_args;
  my $file = delete $args->{'ttfile'} or die "No template file!";

  my $tt_vars = delete $args->{'tt_vars'} || {};
  if (exists $args->{ttargs}) {
    warn "Use of 'ttargs' producer arg is deprecated." . " Please use 'tt_vars' instead.\n";
    %$tt_vars = { %{ $args->{ttargs} }, %$tt_vars };
  }

  my %tt_conf = exists $args->{tt_conf} ? %{ $args->{tt_conf} } : ();

  # sqlt passes the producer args for _all_ producers in, so we use this
  # grep hack to test for the old usage.
  debug(Dumper(\%tt_conf)) if $DEBUG;
  if (grep /^[A-Z_]+$/, keys %$args) {
    warn "Template config directly in the producer args is deprecated." . " Please use 'tt_conf' instead.\n";
    %tt_conf = (%tt_conf, %$args);
  }

  debug "Processing template $file\n";
  my $out;
  my $tt = Template->new(
    DEBUG    => $DEBUG,
    ABSOLUTE => 1,        # Set so we can use from the command line sensibly
    RELATIVE => 1,        # Maybe the cmd line code should set it! Security!
    %tt_conf,
  );
  debug("Template ERROR: " . Template->error . "\n") if (!$tt);
  $tt || die "Failed to initialize Template object: " . Template->error;

  my $ttproc = $tt->process($file, { schema => $scma, %$tt_vars }, \$out);
  debug("ERROR: " . $tt->error . "\n") if (!$ttproc);
  $ttproc or die "Error processing template '$file': " . $tt->error;

  return $out;
}

1;

=pod

=head1 AUTHOR

Mark Addison E<lt>grommit@users.sourceforge.netE<gt>.

=head1 TODO

B<More template vars?> e.g. [% tables %] as a shortcut for
[% schema.get_tables %].

=head1 SEE ALSO

SQL::Translator.

=cut
