# $Id: Build.PL,v 1.13 2007-10-24 10:55:44 schiffbruechige Exp $

use strict;
use lib './lib';
use Module::Build;

my $builder = Module::Build->new(
    create_readme     => 0,
    dist_abstract     => 'SQL DDL transformations and more',
    dist_author       => 'Ken Y. Clark <kclark@cpan.org>',
    dist_version_from => 'lib/SQL/Translator.pm',
    license           => 'gpl',
    module_name       => 'SQL::Translator',
    sign              => 1,
    script_files      => [
        'bin/sqlt-diagram',
        'bin/sqlt-diff',
        'bin/sqlt-diff-old',
        'bin/sqlt-dumper',
        'bin/sqlt-graph',
        'bin/sqlt',
    ],
    requires          => {
        'Class::Base'              => 0,
        'Class::Data::Inheritable' => 0.02,
        'Class::MakeMethods'       => 0,
        'Digest::SHA1'             => 2.00,
        'IO::Dir'                  => 0,
        'Log::Log4perl'            => 0,
        'Parse::RecDescent'        => 1.94,
        'Pod::Usage'               => 0,
        'Class::Accessor::Fast'    => 0,
        'DBI'                      => 0,
    },
    recommends        => {
        'Template'                 => 2.10,
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
    build_requires    => {
        'File::Basename'          => 0,
        'File::Spec'              => 0,
        'Test::More'              => 0.6,
        'Test::Differences'       => 0,
        'Test::Exception'         => 0,
        'Test::Differences'       => 0,
        'YAML'                    => 0.39,
    },
    get_options => {
        # Where to store additional files such as templates.
        # TODO: Should be OS dependant. See Module::Build::os_type()
        install_dir => { type=>'=s', default=>'/usr/local/share/sqlfairy' },
    },
);

# Copy .tt2 files in lib into blib/lib
$builder->add_build_element('tt2');

$builder->create_build_script;
print "Now run './Build', './Build test', and './Build install'\n";
