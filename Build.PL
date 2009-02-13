use strict;
use lib './lib';
use Module::Build;

my $builder = Module::Build->new(
  module_name           => 'SQL::Translator',
  dist_author           => 'Ken Y. Clark <kclark@cpan.org>',
  dist_version_from     => 'lib/SQL/Translator.pm',
  dist_abstract         => 'SQL DDL transformations and more',
  license               => 'gpl',
  dynamic_config        => 0,
  create_readme         => 0,
  recursive_test_files  => 1,
  sign                  => 1,
  create_packlist       => 1,
  sign                  => 1,
  recursive_test_files  => 1,
  create_makefile_pl    => 'passthrough',

  requires => {
    'Class::Base'              => 0,
    'Class::Data::Inheritable' => 0.02,
    'Class::MakeMethods'       => 0,
    'Digest::SHA1'             => 2.00,
    'IO::Dir'                  => 0,
    'Parse::RecDescent'        => 1.94,
    'Pod::Usage'               => 0,
    'Class::Accessor::Fast'    => 0,
    'DBI'                      => 0,
  },
  recommends => {
    'Template'                => 2.10,
    'GD'                      => 0,
    'GraphViz'                => 0,
    'Graph::Directed'         => 0,
    'IO::File'                => 0,
    'IO::Scalar'              => 0,
    'Spreadsheet::ParseExcel' => '>= 0.2602, != 0.33',
    'Text::ParseWords'        => 0,
    'Text::RecordParser'      => 0.02,
    'XML::Writer'             => 0.500,
    'XML::XPath'              => 1.13,
  },
  build_requires => {
    'File::Basename'          => 0,
    'File::Spec'              => 0,
    'Test::More'              => 0.6,
    'Test::Differences'       => 0,
    'Test::Exception'         => 0,
    'Test::Differences'       => 0,
    'YAML'                    => 0.39,
  },

  add_to_cleanup => [ 'SQL-Translator-*' ],
  script_files => [
    'bin/sqlt-diagram',
    'bin/sqlt-diff',
    'bin/sqlt-diff-old',
    'bin/sqlt-dumper',
    'bin/sqlt-graph',
    'bin/sqlt',
  ],

  get_options => {
    # Where to store additional files such as templates.
    # TODO: Should be OS dependant. See Module::Build::os_type()
    install_dir => { type=>'=s', default=>'/usr/local/share/sqlfairy' },
  },
  meta_merge => {
    resources => {
      # Custom resources (must begin with an uppercase letter)
      Ratings      => 'http://cpanratings.perl.org/d/SQL-Translator',

      # Official keys (homepage, license, bugtracker)
      repository   => 'https://sqlfairy.svn.sourceforge.net/svnroot/sqlfairy',
      bugtracker   => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=SQL-Translator',
      license      => 'http://fsf.org/licensing/licenses/gpl.html',
    },
  },
);

# Copy .tt2 files in lib into blib/lib
$builder->add_build_element('tt2');

$builder->create_build_script;
print "Now run './Build', './Build test', and './Build install'\n";
