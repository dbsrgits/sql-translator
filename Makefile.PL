use inc::Module::Install 0.89;
use strict;
use warnings;

my $deps = {
  requires => {
    'Class::Base'              => 0,
    'Class::Data::Inheritable' => 0.02,
    'Class::MakeMethods'       => 0,
    'Digest::SHA1'             => 2.00,
    'Carp::Clan',              => 0,
    'IO::Dir'                  => 0,
    'Parse::RecDescent'        => 1.096000,   # PBP ftw
    'Pod::Usage'               => 0,
    'Class::Accessor::Fast'    => 0,
    'DBI'                      => 0,
    'File::ShareDir'           => 1.0,
    'File::Spec'               => 0,
  },
  recommends => {
    'Template'                => 2.10,
    'GD'                      => 0,
    'GraphViz'                => 0,
    'Graph::Directed'         => 0,
    'IO::File'                => 0,
    'IO::Scalar'              => 0,
    'Spreadsheet::ParseExcel' => 0.41,
    'Text::ParseWords'        => 0,
    'Text::RecordParser'      => 0.02,
    'XML::Writer'             => 0.500,
    'XML::LibXML'             => 1.61,
  },
  test_requires => {
    'File::Basename'          => 0,
    'Test::More'              => 0.6,
    'Test::Differences'       => 0,
    'Test::Exception'         => 0,
    'YAML'                    => 0.39,
  },
};

perl_version '5.005';

name        'SQL-Translator';
author      'Ken Youens-Clark <kclark@cpan.org>';
abstract    'SQL DDL transformations and more';
license     'http://fsf.org/licensing/licenses/gpl.html';
repository  'https://sqlfairy.svn.sourceforge.net/svnroot/sqlfairy';
bugtracker  'http://rt.cpan.org/NoAuth/Bugs.html?Dist=SQL-Translator';

resources Ratings => 'http://cpanratings.perl.org/d/SQL-Translator';

all_from    'lib/SQL/Translator.pm';

for my $type (qw/requires recommends test_requires/) {
  no strict qw/refs/;
  my $f = \&$type;
  for my $mod (keys %{$deps->{$type} || {} }) {
    $f->($mod, $deps->{$type}{$mod});
  }
}

tests_recursive ();

install_script (qw|
  bin/sqlt-diagram
  bin/sqlt-diff
  bin/sqlt-diff-old
  bin/sqlt-dumper
  bin/sqlt-graph
  bin/sqlt
|);

install_share();

auto_provides();

auto_install();

WriteAll();
