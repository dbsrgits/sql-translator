package SQL::Translator;

use strict;
use ExtUtils::MakeMaker;
$|++;

my %PREREQ_PM;
my %missing = (
    optional => [ ],
    required => [ ],
);

print "Checking for required and recommended modules.\n";
#              Module Name              Version Optional?
check_version('Class::Base'             => 0    => 0);
check_version('File::Basename'          => 0    => 0);
check_version('File::Spec'              => 0    => 0);
check_version('GD'                      => 0    => 1);
check_version('GraphViz'                => 0    => 1);
check_version('IO::Dir'                 => 0    => 0);
check_version('IO::File'                => 0    => 0);
check_version('IO::Scalar'              => 0    => 0);
check_version('Parse::RecDescent'       => 1.94 => 0);
check_version('Pod::Usage'              => 0    => 0);
check_version('Spreadsheet::ParseExcel' => 0    => 1);
check_version('Test::More'              => 0    => 0);
check_version('Test::Exception'         => 0    => 0);
check_version('Text::ParseWords'        => 0    => 0);
check_version('Text::RecordParser'      => 0.02 => 0);
check_version('XML::Writer'             => 0    => 1);
check_version('XML::XPath'              => 0    => 1);

print "\n";

if (@{$missing{'optional'}} + @{$missing{'required'}}) {
    print "Some components might not work correctly:\n";
    my $count;
    if ($missing{'required'}) {
        $count = scalar(@{$missing{'required'}});
        printf "  You are missing %d required module%s: %s\n",
            $count,
            $count == 1 ? '' : 's',
            join ', ', @{$missing{'required'}};
    }
    if ($missing{'optional'}) {
        $count = scalar(@{$missing{'optional'}});
        printf "  You are missing %d optional module%s: %s\n",
            $count,
            $count == 1 ? '' : 's',
            join ', ', @{$missing{'optional'}};
    }

    print "\n";
}

WriteMakefile(
    'NAME'         => __PACKAGE__,
    'VERSION_FROM' => 'lib/SQL/Translator.pm',
    'EXE_FILES'    => [
        'bin/sqlt-diagram.pl',
        'bin/sqlt-dumper.pl',
        'bin/sqlt-graph.pl',
        'bin/sql_translator.pl',
    ],
    'PREREQ_PM' => \%PREREQ_PM,
    'clean' => {
        FILES => '$(DISTVNAME).tar$(SUFFIX)',
    },
);

# ----------------------------------------------------------------------
# check_version($module, $version, $optional)
#
# Takes a module name, optional version number, and a flag indicating
# whether the module is optional (default is no).
# ----------------------------------------------------------------------
sub check_version {
    my ($module, $version, $optional) = @_;
    my ($dots, $load);

    if ($version) {
        $load = "$module $version";
    }
    else {
        $load = $module;
    }

    $dots = '.' x (36 - length($load));

    eval "use $load;";
    if ($@) {
        if ($optional) {
            push @{$missing{'optional'}}, $module;
        }
        else {
            push @{$missing{'required'}}, $module;
        }
        print "$load $dots not found!";
        if ($optional) {
            print optional('not found!'), "\n";
            return;
        }
        print required('not found!');
        print "\n";
    }
    else {
        no strict qw(refs);
        my $version = ${"$module\::VERSION"};
        print "$load $dots $version";
        print $optional ? optional($version) : required($version);
        print "\n";
    }

    $PREREQ_PM{$module} = $version;
}

sub optional { return _message("[optional]", @_) }
sub required { return _message("", @_) }

sub _message {
    my ($message, $version) = @_;
    my $size = 24 - (length "$version");
    my $fmt = '%' . $size . 's';
    sprintf $fmt => $message;
}
