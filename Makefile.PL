package SQL::Translator;

use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => __PACKAGE__,
    'VERSION_FROM' => 'lib/SQL/Translator.pm',
    'EXE_FILES'    => [
        'bin/sqlt-diagram.pl',
        'bin/sqlt-graph.pl',
        'bin/sql_translator.pl',
    ],
    'PREREQ_PM'    => {
        'Class::Base'             => 0,
        'File::Basename'          => 0,
        'File::Spec'              => 0,
        'GD'                      => 0,
        'GraphViz'                => 0,
        'IO::Dir'                 => 0,
        'IO::File'                => 0,
        'IO::Scalar'              => 0,
        'Parse::RecDescent'       => 1.94,
        'Pod::Usage'              => 0,
        'Spreadsheet::ParseExcel' => 0,
        'Test::More'              => 0,
        'Text::ParseWords'        => 0,
        'Text::RecordParser'      => 0.02,
        'XML::Writer'             => 0,
    },
    clean => {
        FILES => '$(DISTNAME)-$(VERSION).tar.gz',
    },
);
