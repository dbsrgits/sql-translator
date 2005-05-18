# $Id: Build.PL,v 1.5 2005-05-18 16:17:41 grommit Exp $

use strict;
use Module::Build;

my $builder           =  Module::Build->new(
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
        'bin/sqlt-dumper',
        'bin/sqlt-graph',
        'bin/sqlt',
    ],
    requires          => {
        'Class::Base'              => 0,
        'Class::Data::Inheritable' => 0.02,
        'IO::Dir'                  => 0,
        'Log::Log4perl'            => 0,
        'Template'                 => 2.10,
        'Parse::RecDescent'        => 1.94,
        'Pod::Usage'               => 0,
    },
    recommends        => {
        'GD'                      => 0,
        'GraphViz'                => 0,
        'IO::File'                => 0,
        'IO::Scalar'              => 0,
        'Spreadsheet::ParseExcel' => 0.2602,
        'Text::ParseWords'        => 0,
        'Text::RecordParser'      => 0.02,
        'XML::Writer'             => 0.500,
        'XML::XPath'              => 1.13,
        'YAML'                    => 0.39,
    },
    build_requires    => {
        'File::Basename'          => 0,
        'File::Spec'              => 0,
        'Test::More'              => 0.6,
        'Test::Exception'         => 0,
        'Test::Differences'       => 0,
    }
);
$builder->create_build_script;
print "Now run './Build', './Build test', and './Build install'\n";
