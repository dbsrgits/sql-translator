use inc::Module::Install 1.06;
use strict;
use warnings;

# to deal wuth x.y.z versions properly
configure_requires 'ExtUtils::MakeMaker' => '6.54';

perl_version '5.008001';

my $deps = {
  requires => {
    'Class::Base'              => '0',
    'Class::Data::Inheritable' => '0.02',
    'Digest::SHA'              => '0',
    'Carp::Clan'               => '0',
    'IO::Scalar'               => '2.110',
    'Parse::RecDescent'        => '1.967009',
    'DBI'                      => '0',
    'File::ShareDir'           => '1.0',
    'File::Spec'               => '0',
    'XML::Writer'              => '0.500',
    'Moo'                      => '0.009007',
  },
  recommends => {
    'Template'                 => '2.20',
    'GD'                       => '0',
    'GraphViz'                 => '0',
    'Graph::Directed'          => '0',
    'Spreadsheet::ParseExcel'  => '0.41',
    'Text::ParseWords'         => '0',
    'Text::RecordParser'       => '0.02',
    'XML::LibXML'              => '1.69',
  },
  test_requires => {
    'YAML'                     => '0.66',
    'Test::More'               => '0.88',
    'Test::Differences'        => '0',
    'Test::Exception'          => '0.31',
  },
};


name        'SQL-Translator';
author      'Ken Youens-Clark <kclark@cpan.org>';
abstract    'SQL DDL transformations and more';
license     'gpl';
repository  'git://git.shadowcat.co.uk/dbsrgits/SQL-Translator.git';
bugtracker  'http://rt.cpan.org/NoAuth/Bugs.html?Dist=SQL-Translator';

resources Ratings => 'http://cpanratings.perl.org/d/SQL-Translator';

Meta->{values}{x_authority} = 'cpan:JROBINSON';

all_from    'lib/SQL/Translator.pm';

for my $type (qw/requires recommends test_requires/) {
  no strict qw/refs/;
  my $f = \&$type;
  for my $mod (keys %{$deps->{$type} || {} }) {
    $f->($mod, $deps->{$type}{$mod});
  }
}

no_index directory => $_ for (qw|
  lib/SQL/Translator/Schema/Graph
|);
no_index package => $_ for (qw|
  SQL::Translator::Schema::Graph
|);

install_script (qw|
  script/sqlt-diagram
  script/sqlt-diff
  script/sqlt-diff-old
  script/sqlt-dumper
  script/sqlt-graph
  script/sqlt
|);

install_share();

tests_recursive ();


# temporary(?) until I get around to fix M::I wrt xt/
# needs Module::Install::AuthorTests
eval {
  # this should not be necessary since the autoloader is supposed
  # to work, but there were reports of it failing
  require Module::Install::AuthorTests;
  recursive_author_tests (qw/xt/);
  1;
} || do {
  if ($Module::Install::AUTHOR) {
    my $err = $@;

    # better error message in case of missing dep
    eval { require Module::Install::AuthorTests }
      || die "\nYou need Module::Install::AuthorTests installed to run this Makefile.PL in author mode:\n\n$@\n";

    die $err;
  }
};

auto_install();

if ($Module::Install::AUTHOR) {
  _recompile_grammars();
  _recreate_rt_source();
}

WriteAll();

sub _recompile_grammars {
  return; # disabled until RT#74593 is resolved

  require File::Spec;

  my $compiled_parser_dir = File::Spec->catdir(qw/
    share PrecompiledParsers Parse RecDescent DDL SQLT
  /);

  # Currently consider only single-name parsers containing a grammar marker
  # This is somewhat fragile, but better than loading all kinds of parsers
  # to some of which we may not even have the deps
  my $parser_libdir = 'lib/SQL/Translator/Parser';
  for my $parser_fn (glob "$parser_libdir/*.pm") {
    die "$parser_fn does not look like a readable file\n"
      unless ( -f $parser_fn and -r $parser_fn );

    my ($type) = $parser_fn =~ /^\Q$parser_libdir\E\/(.+)\.pm$/i
      or die "$parser_fn not named in expected format\n";

    my $parser_source = do { local (@ARGV, $/) = $parser_fn; <> };
    next unless $parser_source =~ /\$GRAMMAR.+?END_OF_GRAMMAR/s;


    my $precomp_parser_fn = File::Spec->catfile($compiled_parser_dir, "$type.pm");

    next if (
      -f $precomp_parser_fn
        and
      (stat($parser_fn))[9] <= (stat($precomp_parser_fn))[9]
    );


    print "Precompiling parser for $type\n";

    require $parser_fn;
    require Parse::RecDescent;

    Parse::RecDescent->Precompile(
      do {
        no strict 'refs';
        ${"SQL::Translator::Parser::${type}::GRAMMAR"}
          || die "No \$GRAMMAR global found in SQL::Translator::Parser::$type ($parser_fn)\n"
      },
      "Parse::RecDescent::DDL::SQLT::$type"
    );

    rename( "$type.pm", $precomp_parser_fn )
      or die "Unable to move $type.pm to $compiled_parser_dir: $!\n";
  }

}

sub _recreate_rt_source {
  my $base_xml = "t/data/roundtrip.xml";
  my $autogen_yaml = "t/data/roundtrip_autogen.yaml";

  print "Updating $autogen_yaml\n";

  unlink $autogen_yaml;

  eval {

    use lib 'lib';

    require SQL::Translator;
    require SQL::Translator::Parser::XML;

    open (my $fh, '>', $autogen_yaml) or die "$autogen_yaml: $!\n";

    my $tr = SQL::Translator->new;
    my $yaml = $tr->translate (
      parser => 'XML',
      file => $base_xml,
      producer => 'YAML',
    ) or  die sprintf ("Unable to translate %s to YAML: %s\n",
              $base_xml,
              $tr->error || 'error unknown'
          );

    print $fh $yaml;
    close $fh;
  };

  if ($@) {
    warn <<EOE;

=========================================================================
===============              WARNING !!!                =================
=========================================================================

Unable to update the roundtrip schema (attempt triggered by AUTHOR mode).
We will still generate a Makefile, but be aware that if you build a dist
this way, it *WILL* be broken.

-------------------------------------------------------------------------
$@

Press Enter to continue.
EOE
  <>;
  }
}
