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
        'Parse::RecDescent'  => 0,  # Is a particular version needed?
        'XML::Writer'        => 0,
    },
);

# Blah, blah, blah --> To test syncmail!
