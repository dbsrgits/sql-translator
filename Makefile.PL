package SQL::Translator;

use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => __PACKAGE__,
    'VERSION_FROM' => "lib/SQL/Translator.pm",
    'EXE_FILES'    => [
        'bin/sql_translator.pl',
    ],
    'PREREQ_PM'    => {
        'Class::Base'        => 0,
        'File::Basename'     => 0,
        'File::Spec'         => 0,
        'IO::Dir'            => 0,
        'Parse::RecDescent'  => 0,  # Is a particular version needed?
        'Pod::Usage'         => 0,
        'Text::ParseWords'   => 0,
        'XML::Dumper'        => 0,
    },
    clean => {
        FILES => '$(DISTNAME)-$(VERSION).tar.gz',
    },
);


