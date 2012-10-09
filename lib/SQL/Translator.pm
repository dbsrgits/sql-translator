package SQL::Translator;

use Moo;
our ( $DEFAULT_SUB, $DEBUG, $ERROR );

our $VERSION  = '0.11016';
$DEBUG    = 0 unless defined $DEBUG;
$ERROR    = "";

use Carp qw(carp croak);

use Data::Dumper;
use File::Find;
use File::Spec::Functions qw(catfile);
use File::Basename qw(dirname);
use IO::Dir;
use Sub::Quote qw(quote_sub);
use SQL::Translator::Producer;
use SQL::Translator::Schema;
use SQL::Translator::Utils qw(throw ex2err carp_ro);

$DEFAULT_SUB = sub { $_[0]->schema } unless defined $DEFAULT_SUB;

with qw(
    SQL::Translator::Role::Debug
    SQL::Translator::Role::Error
    SQL::Translator::Role::BuildArgs
);

around BUILDARGS => sub {
    my $orig = shift;
    my $self = shift;
    my $config = $self->$orig(@_);

    # If a 'parser' or 'from' parameter is passed in, use that as the
    # parser; if a 'producer' or 'to' parameter is passed in, use that
    # as the producer; both default to $DEFAULT_SUB.
    $config->{parser} ||= $config->{from} if defined $config->{from};
    $config->{producer} ||= $config->{to} if defined $config->{to};

    $config->{filename} ||= $config->{file} if defined $config->{file};

    my $quote;
    if (defined $config->{quote_identifiers}) {
      $quote = $config->{quote_identifiers};

      for (qw/quote_table_names quote_field_names/) {
        carp "Ignoring deprecated parameter '$_', since 'quote_identifiers' is supplied"
          if defined $config->{$_}
      }
    }
    # Legacy one set the other is not
    elsif (
      defined $config->{'quote_table_names'}
        xor
      defined $config->{'quote_field_names'}
    ) {
      if (defined $config->{'quote_table_names'}) {
        carp "Explicitly disabling the deprecated 'quote_table_names' implies disabling 'quote_identifiers' which in turn implies disabling 'quote_field_names'"
          unless $config->{'quote_table_names'};
        $quote = $config->{'quote_table_names'} ? 1 : 0;
      }
      else {
        carp "Explicitly disabling the deprecated 'quote_field_names' implies disabling 'quote_identifiers' which in turn implies disabling 'quote_table_names'"
          unless $config->{'quote_field_names'};
        $quote = $config->{'quote_field_names'} ? 1 : 0;
      }
    }
    # Legacy both are set
    elsif(defined $config->{'quote_table_names'}) {
      croak 'Setting quote_table_names and quote_field_names to conflicting values is no longer supported'
        if ($config->{'quote_table_names'} xor $config->{'quote_field_names'});

      $quote = $config->{'quote_table_names'} ? 1 : 0;
    }

    $config->{quote_identifiers} = $quote if defined $quote;

    return $config;
};

sub BUILD {
    my ($self) = @_;
    # Make sure all the tool-related stuff is set up
    foreach my $tool (qw(producer parser)) {
        $self->$tool($self->$tool);
    }
}

has $_ => (
    is => 'rw',
    default => quote_sub(q{ 0 }),
    coerce => quote_sub(q{ $_[0] ? 1 : 0 }),
) foreach qw(add_drop_table no_comments show_warnings trace validate);

# quote_identifiers is on by default, use a 0-but-true as indicator
# so we can allow individual producers to change the default
has quote_identifiers => (
    is => 'rw',
    default => quote_sub(q{ '0E0' }),
    coerce => quote_sub(q{ $_[0] || 0 }),
);

sub quote_table_names {
    (@_ > 1 and ($_[1] xor $_[0]->quote_identifiers) )
        ? croak 'Using quote_table_names as a setter is no longer supported'
        : $_[0]->quote_identifiers;
}

sub quote_field_names {
    (@_ > 1 and ($_[1] xor $_[0]->quote_identifiers) )
        ? croak 'Using quote_field_names as a setter is no longer supported'
        : $_[0]->quote_identifiers;
}

after quote_identifiers => sub {
    if (@_ > 1) {
        # synchronize for old code reaching directly into guts
        $_[0]->{quote_table_names}
            = $_[0]->{quote_field_names}
                = $_[1] ? 1 : 0;
    }
};

has producer => ( is => 'rw', default => sub { $DEFAULT_SUB } );

around producer => sub {
    my $orig = shift;
    shift->_tool({
        orig => $orig,
        name => 'producer',
        path => "SQL::Translator::Producer",
        default_sub => "produce",
    }, @_);
};

has producer_type => ( is => 'rwp', init_arg => undef );

around producer_type => carp_ro('producer_type');

has producer_args => ( is => 'rw', default => quote_sub(q{ +{} }) );

around producer_args => sub {
    my $orig = shift;
    shift->_args($orig, @_);
};

has parser => ( is => 'rw', default => sub { $DEFAULT_SUB }  );

around parser => sub {
    my $orig = shift;
    shift->_tool({
        orig => $orig,
        name => 'parser',
        path => "SQL::Translator::Parser",
        default_sub => "parse",
    }, @_);
};

has parser_type => ( is => 'rwp', init_arg => undef );

around parser_type => carp_ro('parser_type');

has parser_args => ( is => 'rw', default => quote_sub(q{ +{} }) );

around parser_args => sub {
    my $orig = shift;
    shift->_args($orig, @_);
};

has filters => (
    is => 'rw',
    default => quote_sub(q{ [] }),
    coerce => sub {
        my @filters;
        # Set. Convert args to list of [\&code,@args]
        foreach (@{$_[0]||[]}) {
            my ($filt,@args) = ref($_) eq "ARRAY" ? @$_ : $_;
            if ( isa($filt,"CODE") ) {
                push @filters, [$filt,@args];
                next;
            }
            else {
                __PACKAGE__->debug("Adding $filt filter. Args:".Dumper(\@args)."\n");
                $filt = _load_sub("$filt\::filter", "SQL::Translator::Filter")
                    || throw(__PACKAGE__->error);
                push @filters, [$filt,@args];
            }
        }
        return \@filters;
    },
);

around filters => sub {
    my $orig = shift;
    my $self = shift;
    return @{$self->$orig([@{$self->$orig}, @_])} if @_;
    return @{$self->$orig};
};

has filename => (
    is => 'rw',
    isa => sub {
        foreach my $filename (ref($_[0]) eq 'ARRAY' ? @{$_[0]} : $_[0]) {
            if (-d $filename) {
                throw("Cannot use directory '$filename' as input source");
            }
            elsif (not -f _ && -r _) {
                throw("Cannot use '$filename' as input source: ".
                      "file does not exist or is not readable.");
            }
        }
    },
);

around filename => \&ex2err;

has data => (
    is => 'rw',
    builder => 1,
    lazy => 1,
    coerce => sub {
        # Set $self->data based on what was passed in.  We will
        # accept a number of things; do our best to get it right.
        my $data = shift;
        if (isa($data, 'ARRAY')) {
            $data = join '', @$data;
        }
        elsif (isa($data, 'GLOB')) {
            seek ($data, 0, 0) if eof ($data);
            local $/;
            $data = <$data>;
        }
        return isa($data, 'SCALAR') ? $data : \$data;
    },
);

around data => sub {
    my $orig = shift;
    my $self = shift;

    if (@_ > 1 && !ref $_[0]) {
        return $self->$orig(\join('', @_));
    }
    elsif (@_) {
        return $self->$orig(@_);
    }
    return ex2err($orig, $self);
};

sub _build_data {
    my $self = shift;
    # If we have a filename but no data yet, populate.
    if (my $filename = $self->filename) {
        $self->debug("Opening '$filename' to get contents.\n");
        local $/;
        my $data;

        my @files = ref($filename) eq 'ARRAY' ? @$filename : ($filename);

        foreach my $file (@files) {
            open my $fh, '<', $file
               or throw("Can't read file '$file': $!");

            $data .= <$fh>;

            close $fh or throw("Can't close file '$file': $!");
        }

        return \$data;
    }
}

has schema => (
    is => 'lazy',
    init_arg => undef,
    clearer => 'reset',
    predicate => '_has_schema',
);

around schema => carp_ro('schema');

around reset => sub {
    my $orig = shift;
    my $self = shift;
    $self->$orig(@_);
    return 1
};

sub _build_schema { SQL::Translator::Schema->new(translator => shift) }

sub translate {
    my $self = shift;
    my ($args, $parser, $parser_type, $producer, $producer_type);
    my ($parser_output, $producer_output, @producer_output);

    # Parse arguments
    if (@_ == 1) {
        # Passed a reference to a hash?
        if (isa($_[0], 'HASH')) {
            # yep, a hashref
            $self->debug("translate: Got a hashref\n");
            $args = $_[0];
        }

        # Passed a GLOB reference, i.e., filehandle
        elsif (isa($_[0], 'GLOB')) {
            $self->debug("translate: Got a GLOB reference\n");
            $self->data($_[0]);
        }

        # Passed a reference to a string containing the data
        elsif (isa($_[0], 'SCALAR')) {
            # passed a ref to a string
            $self->debug("translate: Got a SCALAR reference (string)\n");
            $self->data($_[0]);
        }

        # Not a reference; treat it as a filename
        elsif (! ref $_[0]) {
            # Not a ref, it's a filename
            $self->debug("translate: Got a filename\n");
            $self->filename($_[0]);
        }

        # Passed something else entirely.
        else {
            # We're not impressed.  Take your empty string and leave.
            # return "";

            # Actually, if data, parser, and producer are set, then we
            # can continue.  Too bad, because I like my comment
            # (above)...
            return "" unless ($self->data     &&
                              $self->producer &&
                              $self->parser);
        }
    }
    else {
        # You must pass in a hash, or you get nothing.
        return "" if @_ % 2;
        $args = { @_ };
    }

    # ----------------------------------------------------------------------
    # Can specify the data to be transformed using "filename", "file",
    # "data", or "datasource".
    # ----------------------------------------------------------------------
    if (my $filename = ($args->{'filename'} || $args->{'file'})) {
        $self->filename($filename);
    }

    if (my $data = ($args->{'data'} || $args->{'datasource'})) {
        $self->data($data);
    }

    # ----------------------------------------------------------------
    # Get the data.
    # ----------------------------------------------------------------
    my $data = $self->data;

    # ----------------------------------------------------------------
    # Local reference to the parser subroutine
    # ----------------------------------------------------------------
    if ($parser = ($args->{'parser'} || $args->{'from'})) {
        $self->parser($parser);
    }
    $parser      = $self->parser;
    $parser_type = $self->parser_type;

    # ----------------------------------------------------------------
    # Local reference to the producer subroutine
    # ----------------------------------------------------------------
    if ($producer = ($args->{'producer'} || $args->{'to'})) {
        $self->producer($producer);
    }
    $producer      = $self->producer;
    $producer_type = $self->producer_type;

    # ----------------------------------------------------------------
    # Execute the parser, the filters and then execute the producer.
    # Allowances are made for each piece to die, or fail to compile,
    # since the referenced subroutines could be almost anything.  In
    # the future, each of these might happen in a Safe environment,
    # depending on how paranoid we want to be.
    # ----------------------------------------------------------------

    # Run parser
    unless ( $self->_has_schema ) {
        eval { $parser_output = $parser->($self, $$data) };
        if ($@ || ! $parser_output) {
            my $msg = sprintf "translate: Error with parser '%s': %s",
                $parser_type, ($@) ? $@ : " no results";
            return $self->error($msg);
        }
    }
    $self->debug("Schema =\n", Dumper($self->schema), "\n");

    # Validate the schema if asked to.
    if ($self->validate) {
        my $schema = $self->schema;
        return $self->error('Invalid schema') unless $schema->is_valid;
    }

    # Run filters
    my $filt_num = 0;
    foreach ($self->filters) {
        $filt_num++;
        my ($code,@args) = @$_;
        eval { $code->($self->schema, @args) };
        my $err = $@ || $self->error || 0;
        return $self->error("Error with filter $filt_num : $err") if $err;
    }

    # Run producer
    # Calling wantarray in the eval no work, wrong scope.
    my $wantarray = wantarray ? 1 : 0;
    eval {
        if ($wantarray) {
            @producer_output = $producer->($self);
        } else {
            $producer_output = $producer->($self);
        }
    };
    if ($@ || !( $producer_output || @producer_output)) {
        my $err = $@ || $self->error || "no results";
        my $msg = "translate: Error with producer '$producer_type': $err";
        return $self->error($msg);
    }

    return wantarray ? @producer_output : $producer_output;
}

sub list_parsers {
    return shift->_list("parser");
}

sub list_producers {
    return shift->_list("producer");
}


# ======================================================================
# Private Methods
# ======================================================================

# ----------------------------------------------------------------------
# _args($type, \%args);
#
# Gets or sets ${type}_args.  Called by parser_args and producer_args.
# ----------------------------------------------------------------------
sub _args {
    my $self = shift;
    my $orig = shift;

    if (@_) {
        # If the first argument is an explicit undef (remember, we
        # don't get here unless there is stuff in @_), then we clear
        # out the producer_args hash.
        if (! defined $_[0]) {
            shift @_;
            $self->$orig({});
        }

        my $args = isa($_[0], 'HASH') ? shift : { @_ };
        return $self->$orig({ %{$self->$orig}, %$args });
    }

    return $self->$orig;
}

# ----------------------------------------------------------------------
# Does the get/set work for parser and producer. e.g.
# return $self->_tool({
#   name => 'producer',
#   path => "SQL::Translator::Producer",
#   default_sub => "produce",
# }, @_);
# ----------------------------------------------------------------------
sub _tool {
    my ($self,$args) = (shift, shift);
    my $name = $args->{name};
    my $orig = $args->{orig};
    return $self->{$name} unless @_; # get accessor

    my $path = $args->{path};
    my $default_sub = $args->{default_sub};
    my $tool = shift;

    # passed an anonymous subroutine reference
    if (isa($tool, 'CODE')) {
        $self->$orig($tool);
        $self->${\"_set_${name}_type"}("CODE");
        $self->debug("Got $name: code ref\n");
    }

    # Module name was passed directly
    # We try to load the name; if it doesn't load, there's a
    # possibility that it has a function name attached to it,
    # so we give it a go.
    else {
        $tool =~ s/-/::/g if $tool !~ /::/;
        my ($code,$sub);
        ($code,$sub) = _load_sub("$tool\::$default_sub", $path);
        unless ($code) {
            if ( __PACKAGE__->error =~ m/Can't find module/ ) {
                # Mod not found so try sub
                ($code,$sub) = _load_sub("$tool", $path) unless $code;
                die "Can't load $name subroutine '$tool' : ".__PACKAGE__->error
                unless $code;
            }
            else {
                die "Can't load $name '$tool' : ".__PACKAGE__->error;
            }
        }

        # get code reference and assign
        my (undef,$module,undef) = $sub =~ m/((.*)::)?(\w+)$/;
        $self->$orig($code);
        $self->${\"_set_$name\_type"}($sub eq "CODE" ? "CODE" : $module);
        $self->debug("Got $name: $sub\n");
    }

    # At this point, $self->{$name} contains a subroutine
    # reference that is ready to run

    # Anything left?  If so, it's args
    my $meth = "$name\_args";
    $self->$meth(@_) if (@_);

    return $self->{$name};
}

# ----------------------------------------------------------------------
# _list($type)
# ----------------------------------------------------------------------
sub _list {
    my $self   = shift;
    my $type   = shift || return ();
    my $uctype = ucfirst lc $type;

    #
    # First find all the directories where SQL::Translator
    # parsers or producers (the "type") appear to live.
    #
    load("SQL::Translator::$uctype") or return ();
    my $path = catfile "SQL", "Translator", $uctype;
    my @dirs;
    for (@INC) {
        my $dir = catfile $_, $path;
        $self->debug("_list_${type}s searching $dir\n");
        next unless -d $dir;
        push @dirs, $dir;
    }

    #
    # Now use File::File::find to look recursively in those
    # directories for all the *.pm files, then present them
    # with the slashes turned into dashes.
    #
    my %found;
    find(
        sub {
            if ( -f && m/\.pm$/ ) {
                my $mod      =  $_;
                   $mod      =~ s/\.pm$//;
                my $cur_dir  = $File::Find::dir;
                my $base_dir = quotemeta catfile 'SQL', 'Translator', $uctype;

                #
                # See if the current directory is below the base directory.
                #
                if ( $cur_dir =~ m/$base_dir(.*)/ ) {
                    $cur_dir = $1;
                    $cur_dir =~ s!^/!!;  # kill leading slash
                    $cur_dir =~ s!/!-!g; # turn other slashes into dashes
                }
                else {
                    $cur_dir = '';
                }

                $found{ join '-', map { $_ || () } $cur_dir, $mod } = 1;
            }
        },
        @dirs
    );

    return sort { lc $a cmp lc $b } keys %found;
}

# ----------------------------------------------------------------------
# load(MODULE [,PATH[,PATH]...])
#
# Loads a Perl module.  Short circuits if a module is already loaded.
#
# MODULE - is the name of the module to load.
#
# PATH - optional list of 'package paths' to look for the module in. e.g
# If you called load('Super::Foo' => 'My', 'Other') it will
# try to load the mod Super::Foo then My::Super::Foo then Other::Super::Foo.
#
# Returns package name of the module actually loaded or false and sets error.
#
# Note, you can't load a name from the root namespace (ie one without '::' in
# it), therefore a single word name without a path fails.
# ----------------------------------------------------------------------
sub load {
    my $name = shift;
    my @path;
    push @path, "" if $name =~ /::/; # Empty path to check name on its own first
    push @path, @_ if @_;

    foreach (@path) {
        my $module = $_ ? "$_\::$name" : $name;
        my $file = $module; $file =~ s[::][/]g; $file .= ".pm";
        __PACKAGE__->debug("Loading $name as $file\n");
        return $module if $INC{$file}; # Already loaded

        eval { require $file };
        next if $@ =~ /Can't locate $file in \@INC/;
        eval { $module->import() } unless $@;
        return __PACKAGE__->error("Error loading $name as $module : $@")
        if $@ && $@ !~ /"SQL::Translator::Producer" is not exported/;

        return $module; # Module loaded ok
    }

    return __PACKAGE__->error("Can't find module $name. Path:".join(",",@path));
}

# ----------------------------------------------------------------------
# Load the sub name given (including package), optionally using a base package
# path. Returns code ref and name of sub loaded, including its package.
# (\&code, $sub) = load_sub( 'MySQL::produce', "SQL::Translator::Producer" );
# (\&code, $sub) = load_sub( 'MySQL::produce', @path );
# ----------------------------------------------------------------------
sub _load_sub {
    my ($tool, @path) = @_;

    my (undef,$module,$func_name) = $tool =~ m/((.*)::)?(\w+)$/;
    if ( my $module = load($module => @path) ) {
        my $sub = "$module\::$func_name";
        return wantarray ? ( \&{ $sub }, $sub ) : \&$sub;
    }
    return undef;
}

sub format_table_name {
    return shift->_format_name('_format_table_name', @_);
}

sub format_package_name {
    return shift->_format_name('_format_package_name', @_);
}

sub format_fk_name {
    return shift->_format_name('_format_fk_name', @_);
}

sub format_pk_name {
    return shift->_format_name('_format_pk_name', @_);
}

# ----------------------------------------------------------------------
# The other format_*_name methods rely on this one.  It optionally
# accepts a subroutine ref as the first argument (or uses an identity
# sub if one isn't provided or it doesn't already exist), and applies
# it to the rest of the arguments (if any).
# ----------------------------------------------------------------------
sub _format_name {
    my $self = shift;
    my $field = shift;
    my @args = @_;

    if (ref($args[0]) eq 'CODE') {
        $self->{$field} = shift @args;
    }
    elsif (! exists $self->{$field}) {
        $self->{$field} = sub { return shift };
    }

    return @args ? $self->{$field}->(@args) : $self->{$field};
}

sub isa($$) {
    my ($ref, $type) = @_;
    return UNIVERSAL::isa($ref, $type);
}

sub version {
    my $self = shift;
    return $VERSION;
}

# Must come after all 'has' declarations
around new => \&ex2err;

1;

# ----------------------------------------------------------------------
# Who killed the pork chops?
# What price bananas?
# Are you my Angel?
# Allen Ginsberg
# ----------------------------------------------------------------------

=pod

=head1 NAME

SQL::Translator - manipulate structured data definitions (SQL and more)

=head1 SYNOPSIS

  use SQL::Translator;

  my $translator          = SQL::Translator->new(
      # Print debug info
      debug               => 1,
      # Print Parse::RecDescent trace
      trace               => 0,
      # Don't include comments in output
      no_comments         => 0,
      # Print name mutations, conflicts
      show_warnings       => 0,
      # Add "drop table" statements
      add_drop_table      => 1,
      # to quote or not to quote, thats the question
      quote_identifiers     => 1,
      # Validate schema object
      validate            => 1,
      # Make all table names CAPS in producers which support this option
      format_table_name   => sub {my $tablename = shift; return uc($tablename)},
      # Null-op formatting, only here for documentation's sake
      format_package_name => sub {return shift},
      format_fk_name      => sub {return shift},
      format_pk_name      => sub {return shift},
  );

  my $output     = $translator->translate(
      from       => 'MySQL',
      to         => 'Oracle',
      # Or an arrayref of filenames, i.e. [ $file1, $file2, $file3 ]
      filename   => $file,
  ) or die $translator->error;

  print $output;

=head1 DESCRIPTION

This documentation covers the API for SQL::Translator.  For a more general
discussion of how to use the modules and scripts, please see
L<SQL::Translator::Manual>.

SQL::Translator is a group of Perl modules that converts
vendor-specific SQL table definitions into other formats, such as
other vendor-specific SQL, ER diagrams, documentation (POD and HTML),
XML, and Class::DBI classes.  The main focus of SQL::Translator is
SQL, but parsers exist for other structured data formats, including
Excel spreadsheets and arbitrarily delimited text files.  Through the
separation of the code into parsers and producers with an object model
in between, it's possible to combine any parser with any producer, to
plug in custom parsers or producers, or to manipulate the parsed data
via the built-in object model.  Presently only the definition parts of
SQL are handled (CREATE, ALTER), not the manipulation of data (INSERT,
UPDATE, DELETE).

=head1 CONSTRUCTOR

The constructor is called C<new>, and accepts a optional hash of options.
Valid options are:

=over 4

=item *

parser / from

=item *

parser_args

=item *

producer / to

=item *

producer_args

=item *

filters

=item *

filename / file

=item *

data

=item *

debug

=item *

add_drop_table

=item *

quote_identifiers

=item *

quote_table_names (DEPRECATED)

=item *

quote_field_names (DEPRECATED)

=item *

no_comments

=item *

trace

=item *

validate

=back

All options are, well, optional; these attributes can be set via
instance methods.  Internally, they are; no (non-syntactical)
advantage is gained by passing options to the constructor.

=head1 METHODS

=head2 add_drop_table

Toggles whether or not to add "DROP TABLE" statements just before the
create definitions.

=head2 quote_identifiers

Toggles whether or not to quote identifiers (table, column, constraint, etc.)
with a quoting mechanism suitable for the chosen Producer. The default (true)
is to quote them.

=head2 quote_table_names

DEPRECATED - A legacy proxy to L</quote_identifiers>

=head2 quote_field_names

DEPRECATED - A legacy proxy to L</quote_identifiers>

=head2 no_comments

Toggles whether to print comments in the output.  Accepts a true or false
value, returns the current value.

=head2 producer

The C<producer> method is an accessor/mutator, used to retrieve or
define what subroutine is called to produce the output.  A subroutine
defined as a producer will be invoked as a function (I<not a method>)
and passed its container C<SQL::Translator> instance, which it should
call the C<schema> method on, to get the C<SQL::Translator::Schema>
generated by the parser.  It is expected that the function transform the
schema structure to a string.  The C<SQL::Translator> instance is also useful
for informational purposes; for example, the type of the parser can be
retrieved using the C<parser_type> method, and the C<error> and
C<debug> methods can be called when needed.

When defining a producer, one of several things can be passed in:  A
module name (e.g., C<My::Groovy::Producer>), a module name relative to
the C<SQL::Translator::Producer> namespace (e.g., C<MySQL>), a module
name and function combination (C<My::Groovy::Producer::transmogrify>),
or a reference to an anonymous subroutine.  If a full module name is
passed in (for the purposes of this method, a string containing "::"
is considered to be a module name), it is treated as a package, and a
function called "produce" will be invoked: C<$modulename::produce>.
If $modulename cannot be loaded, the final portion is stripped off and
treated as a function.  In other words, if there is no file named
F<My/Groovy/Producer/transmogrify.pm>, C<SQL::Translator> will attempt
to load F<My/Groovy/Producer.pm> and use C<transmogrify> as the name of
the function, instead of the default C<produce>.

  my $tr = SQL::Translator->new;

  # This will invoke My::Groovy::Producer::produce($tr, $data)
  $tr->producer("My::Groovy::Producer");

  # This will invoke SQL::Translator::Producer::Sybase::produce($tr, $data)
  $tr->producer("Sybase");

  # This will invoke My::Groovy::Producer::transmogrify($tr, $data),
  # assuming that My::Groovy::Producer::transmogrify is not a module
  # on disk.
  $tr->producer("My::Groovy::Producer::transmogrify");

  # This will invoke the referenced subroutine directly, as
  # $subref->($tr, $data);
  $tr->producer(\&my_producer);

There is also a method named C<producer_type>, which is a string
containing the classname to which the above C<produce> function
belongs.  In the case of anonymous subroutines, this method returns
the string "CODE".

Finally, there is a method named C<producer_args>, which is both an
accessor and a mutator.  Arbitrary data may be stored in name => value
pairs for the producer subroutine to access:

  sub My::Random::producer {
      my ($tr, $data) = @_;
      my $pr_args = $tr->producer_args();

      # $pr_args is a hashref.

Extra data passed to the C<producer> method is passed to
C<producer_args>:

  $tr->producer("xSV", delimiter => ',\s*');

  # In SQL::Translator::Producer::xSV:
  my $args = $tr->producer_args;
  my $delimiter = $args->{'delimiter'}; # value is ,\s*

=head2 parser

The C<parser> method defines or retrieves a subroutine that will be
called to perform the parsing.  The basic idea is the same as that of
C<producer> (see above), except the default subroutine name is
"parse", and will be invoked as C<$module_name::parse($tr, $data)>.
Also, the parser subroutine will be passed a string containing the
entirety of the data to be parsed.

  # Invokes SQL::Translator::Parser::MySQL::parse()
  $tr->parser("MySQL");

  # Invokes My::Groovy::Parser::parse()
  $tr->parser("My::Groovy::Parser");

  # Invoke an anonymous subroutine directly
  $tr->parser(sub {
    my $dumper = Data::Dumper->new([ $_[1] ], [ "SQL" ]);
    $dumper->Purity(1)->Terse(1)->Deepcopy(1);
    return $dumper->Dump;
  });

There is also C<parser_type> and C<parser_args>, which perform
analogously to C<producer_type> and C<producer_args>

=head2 filters

Set or retreive the filters to run over the schema during the
translation, before the producer creates its output. Filters are sub
routines called, in order, with the schema object to filter as the 1st
arg and a hash of options (passed as a list) for the rest of the args.
They are free to do whatever they want to the schema object, which will be
handed to any following filters, then used by the producer.

Filters are set as an array, which gives the order they run in.
Like parsers and producers, they can be defined by a module name, a
module name relative to the SQL::Translator::Filter namespace, a module
name and function name together or a reference to an anonymous subroutine.
When using a module name a function called C<filter> will be invoked in
that package to do the work.

To pass args to the filter set it as an array ref with the 1st value giving
the filter (name or sub) and the rest its args. e.g.

 $tr->filters(
     sub {
        my $schema = shift;
        # Do stuff to schema here!
     },
     DropFKeys,
     [ "Names", table => 'lc' ],
     [ "Foo",   foo => "bar", hello => "world" ],
     [ "Filter5" ],
 );

Although you normally set them in the constructor, which calls
through to filters. i.e.

  my $translator  = SQL::Translator->new(
      ...
      filters => [
          sub { ... },
          [ "Names", table => 'lc' ],
      ],
      ...
  );

See F<t/36-filters.t> for more examples.

Multiple set calls to filters are cumulative with new filters added to
the end of the current list.

Returns the filters as a list of array refs, the 1st value being a
reference to the filter sub and the rest its args.

=head2 show_warnings

Toggles whether to print warnings of name conflicts, identifier
mutations, etc.  Probably only generated by producers to let the user
know when something won't translate very smoothly (e.g., MySQL "enum"
fields into Oracle).  Accepts a true or false value, returns the
current value.

=head2 translate

The C<translate> method calls the subroutine referenced by the
C<parser> data member, then calls any C<filters> and finally calls
the C<producer> sub routine (these members are described above).
It accepts as arguments a number of things, in key => value format,
including (potentially) a parser and a producer (they are passed
directly to the C<parser> and C<producer> methods).

Here is how the parameter list to C<translate> is parsed:

=over

=item *

1 argument means it's the data to be parsed; which could be a string
(filename) or a reference to a scalar (a string stored in memory), or a
reference to a hash, which is parsed as being more than one argument
(see next section).

  # Parse the file /path/to/datafile
  my $output = $tr->translate("/path/to/datafile");

  # Parse the data contained in the string $data
  my $output = $tr->translate(\$data);

=item *

More than 1 argument means its a hash of things, and it might be
setting a parser, producer, or datasource (this key is named
"filename" or "file" if it's a file, or "data" for a SCALAR reference.

  # As above, parse /path/to/datafile, but with different producers
  for my $prod ("MySQL", "XML", "Sybase") {
      print $tr->translate(
                producer => $prod,
                filename => "/path/to/datafile",
            );
  }

  # The filename hash key could also be:
      datasource => \$data,

You get the idea.

=back

=head2 filename, data

Using the C<filename> method, the filename of the data to be parsed
can be set. This method can be used in conjunction with the C<data>
method, below.  If both the C<filename> and C<data> methods are
invoked as mutators, the data set in the C<data> method is used.

    $tr->filename("/my/data/files/create.sql");

or:

    my $create_script = do {
        local $/;
        open CREATE, "/my/data/files/create.sql" or die $!;
        <CREATE>;
    };
    $tr->data(\$create_script);

C<filename> takes a string, which is interpreted as a filename.
C<data> takes a reference to a string, which is used as the data to be
parsed.  If a filename is set, then that file is opened and read when
the C<translate> method is called, as long as the data instance
variable is not set.

=head2 schema

Returns the SQL::Translator::Schema object.

=head2 trace

Turns on/off the tracing option of Parse::RecDescent.

=head2 validate

Whether or not to validate the schema object after parsing and before
producing.

=head2 version

Returns the version of the SQL::Translator release.

=head1 AUTHORS

See the included AUTHORS file:
L<http://search.cpan.org/dist/SQL-Translator/AUTHORS>

If you would like to contribute to the project, you can send patches
to the developers mailing list:

    sqlfairy-developers@lists.sourceforge.net

Or send us a message (with your Sourceforge username) asking to be
added to the project and what you'd like to contribute.


=head1 COPYRIGHT

Copyright 2012 the SQL::Translator authors, as listed in L</AUTHORS>.

=head1 LICENSE

This library is free software and may be distributed under the same terms as
Perl 5 itself.

=head1 BUGS

Please use L<http://rt.cpan.org/> for reporting bugs.

=head1 PRAISE

If you find this module useful, please use
L<http://cpanratings.perl.org/rate/?distribution=SQL-Translator> to rate it.

=head1 SEE ALSO

L<perl>,
L<SQL::Translator::Parser>,
L<SQL::Translator::Producer>,
L<Parse::RecDescent>,
L<GD>,
L<GraphViz>,
L<Text::RecordParser>,
L<Class::DBI>,
L<XML::Writer>.
