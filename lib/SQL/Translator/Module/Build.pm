package SQL::Translator::Module::Build;

use strict;
use warnings;
use File::Find;

use base qw/Module::Build/;

# Copies contents of ./templates into blib/templates. These are then installed
# based on the install_paths setting given to the constructor.
# Called by Module::Build due to add_build_element call in Build.PL
sub process_template_files {
    my $build = shift;
    find({
        no_chdir => 1,
        wanted   => sub {
            return unless -f $_;
            $build->copy_if_modified( from => $_, to_dir => "blib", verbose => 1);
        },
    },'templates');
}

# Install the templates copied into blib above. Uses 
sub ACTION_install {
    my $build = shift;
    $build->SUPER::ACTION_install(@_);
    require ExtUtils::Install;
    my $install_to = $build->config_data( 'template_dir' );
    ExtUtils::Install::install(
        { 'templates' => $install_to }, 1, 0, $build->{args}{uninst} || 0 );
}

1;
