package SQL::Translator;

use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => __PACKAGE__,
    'VERSION'      => 0.01,
    'EXE_FILES'    => [
        'bin/auto-dia.pl',
        'bin/auto-graph.pl',
        'bin/sql_translator.pl',
    ],
    'PREREQ_PM'    => {
        'Class::Base'             => 0,
        'File::Basename'          => 0,
        'File::Spec'              => 0,     # Version!
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
        'XML::Writer'             => 0,
    },
    clean => {
        FILES => '$(DISTNAME)-$(VERSION).tar.gz',
    },
);


