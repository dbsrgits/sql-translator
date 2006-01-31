# $Id: Build.PL,v 1.10 2006-01-31 03:28:07 kycl4rk Exp $

use strict;
use lib './lib';
use SQL::Translator::Module::Build;

my $builder = SQL::Translator::Module::Build->new(
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
        'Class::MakeMethods'       => 0,
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
    },
    build_requires    => {
        'File::Basename'          => 0,
        'File::Spec'              => 0,
        'Test::More'              => 0.6,
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

my $install_dir = $builder->args('install_dir');
print "SqlFairy needs to install some additional files such as templates.\n";
$install_dir = $builder->prompt( "Where should they go?", $install_dir );
print "\n";

# Add the install (and template) dir to the config data. They will then be
# available via the (Module::Build) generated SQL::Translator::ConfigData.
# During build time they are availiable from $builder->config_data( NAME )
my $template_dir = "$install_dir/template";
$builder->config_data( install_dir  => $install_dir );
$builder->config_data( template_dir => $template_dir );

# Add build element for templates, these are processed by
# SQL::Translator::Module::Build::process_template_files
$builder->add_build_element('template');
$builder->install_path->{template} = $template_dir;


$builder->create_build_script;
print "Now run './Build', './Build test', and './Build install'\n";
