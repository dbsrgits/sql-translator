package SQL::Translator;

use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => __PACKAGE__,
    'VERSION_FROM' => 'lib/SQL/Translator.pm',
    'EXE_FILES'    => [
        'bin/sqlt-diagram',
        'bin/sqlt-dumper',
        'bin/sqlt-graph',
        'bin/sqlt',
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
        'Template'                => 2.10,
        'Test::More'              => 0,
        'Test::Exception'         => 0,
        'Test::Differences'       => 0,
        'Text::ParseWords'        => 0,
        'Text::RecordParser'      => 0.02,
        'XML::Writer'             => 0,
        'XML::XPath'              => 1.13,
        'YAML'                    => 0,
    },
    'clean'        => {
        FILES => '$(DISTVNAME).tar$(SUFFIX)',
    },
);

package MY;
use File::Basename qw(basename);

sub libscan {
    my ($self, $file) = @_;
    my $bfile = basename($file);

    return if $bfile =~ /^\.(?:cvs)?ignore$/;
    return if $bfile =~ /\.swp$/;

    return $self->SUPER::libscan($file);
}
