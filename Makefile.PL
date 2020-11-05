use strict;
use warnings;
use ExtUtils::MakeMaker;
use File::ShareDir::Install;
do './maint/Makefile.PL.include' or die $@
  unless -f 'META.yml';
my $eumm_version = eval $ExtUtils::MakeMaker::VERSION;

my %eumm_args = (
  NAME => 'SQL::Translator',
  ABSTRACT => 'SQL DDL transformations and more',
  VERSION_FROM => 'lib/SQL/Translator.pm',
  LICENSE => 'perl',
  MIN_PERL_VERSION => '5.008001',
  CONFIGURE_REQUIRES => {
    'ExtUtils::MakeMaker' => '6.54', # to deal with x.y.z versions properly
    'File::ShareDir::Install' => '0',
  },
  TEST_REQUIRES => {
    'JSON::MaybeXS'            => '1.003003',
    'YAML'                     => '0.66',
    'XML::Writer'              => '0.500',
    'Test::More'               => '0.88',
    'Test::Differences'        => '0',
    'Test::Exception'          => '0.31',
    'Text::ParseWords'         => '0',
  },
  PREREQ_PM => {
    'Digest::SHA'              => '0',
    'Carp::Clan'               => '0',
    'Parse::RecDescent'        => '1.967009',
    'DBI'                      => '1.54',
    'File::ShareDir'           => '1.0',
    'Moo'                      => '1.000003',
    'Package::Variant'         => '1.001001',
    'Sub::Quote'               => '0',
    'Try::Tiny'                => '0.04',
    'Scalar::Util'             => '0',
  },
  realclean => {
      FILES => 't/data/roundtrip_autogen.yaml'
  },
  EXE_FILES => [ qw|
    script/sqlt-diagram
    script/sqlt-diff
    script/sqlt-diff-old
    script/sqlt-dumper
    script/sqlt-graph
    script/sqlt
  | ],
  META_MERGE => {
    "meta-spec" => { version => 2 },
    dynamic_config => 0,
    resources => {
      bugtracker => {
        web    =>  'https://rt.cpan.org/NoAuth/Bugs.html?Dist=SQL-Translator',
        mailto => 'bug-SQL-Translator@rt.cpan.org',
      },
      repository => {
        type => 'git',
        url  => 'git@github.com/dbsrgits/sql-translator.git',
        web  => 'https://github.com/dbsrgits/sql-translator/',
      },
      license => [ 'http://dev.perl.org/licenses/' ],
      x_IRC => 'irc://irc.perl.org/#sql-translator',
      x_Ratings => 'http://cpanratings.perl.org/d/SQL-Translator',
    },
    x_authority => 'cpan:JROBINSON',
    no_index => {
      directory => [qw(maint share xt)],
    },
    prereqs => {
      runtime => {
        recommends => {
          'Template'                 => '2.20',
          'GD'                       => '0',
          'GraphViz'                 => '0',
          'Graph::Directed'          => '0',
          'Spreadsheet::ParseExcel'  => '0.41',
          'Text::RecordParser'       => '0.02',
          'XML::LibXML'              => '1.69',
        },
      },
      develop => {
        requires => {
          'Template'                 => '2.20',
          'GD'                       => '0',
          'GraphViz'                 => '0',
          'Graph::Directed'          => '0',
          'Spreadsheet::ParseExcel'  => '0.41',
          'Text::RecordParser'       => '0.02',
          'XML::LibXML'              => '1.69',
          'Test::EOL'                => '1.1',
          'Test::NoTabs'             => '1.1',
          'Software::LicenseUtils'   => '0', # for Distar
        },
      },
    },
  },
);

install_share 'share';

sub _move_to {
  my ($hash, $fromkey, $tokey) = @_;
  $hash->{$tokey} = {
    %{ $hash->{$tokey} || {} },
    %{ delete($hash->{$fromkey}) || {} },
  };
}
delete $eumm_args{META_MERGE} if $eumm_version < 6.45_01;
delete $eumm_args{CONFIGURE_REQUIRES}
  if $eumm_version < 6.51_03; # too late to use so just delete
_move_to(\%eumm_args, 'TEST_REQUIRES', 'BUILD_REQUIRES')
  if $eumm_version < 6.63_03;
_move_to(\%eumm_args, 'BUILD_REQUIRES', 'PREREQ_PM')
  if $eumm_version < 6.55_01;
$eumm_args{NO_MYMETA} = 1
  if $eumm_version >= 6.57_02 and $eumm_version < 6.57_07;
WriteMakefile(%eumm_args);

package MY;
use File::ShareDir::Install qw(postamble);
