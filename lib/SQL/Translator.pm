package SQL::Translator;

# ----------------------------------------------------------------------
# $Id: Translator.pm,v 1.31 2003-06-16 20:58:10 kycl4rk Exp $
# ----------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>,
#                    darren chamberlain <darren@cpan.org>,
#                    Chris Mungall <cjm@fruitfly.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
# 02111-1307  USA
# -------------------------------------------------------------------

use strict;
use vars qw( $VERSION $REVISION $DEFAULT_SUB $DEBUG $ERROR );
use base 'Class::Base';

$VERSION  = '0.02';
$REVISION = sprintf "%d.%02d", q$Revision: 1.31 $ =~ /(\d+)\.(\d+)/;
$DEBUG    = 0 unless defined $DEBUG;
$ERROR    = "";

use Carp qw(carp);

use File::Spec::Functions qw(catfile);
use File::Basename qw(dirname);
use IO::Dir;
use SQL::Translator::Schema;

# ----------------------------------------------------------------------
# The default behavior is to "pass through" values (note that the
# SQL::Translator instance is the first value ($_[0]), and the stuff
# to be parsed is the second value ($_[1])
# ----------------------------------------------------------------------
$DEFAULT_SUB = sub { $_[1] } unless defined $DEFAULT_SUB;

# ----------------------------------------------------------------------
# init([ARGS])
#   The constructor.
#
#   new takes an optional hash of arguments.  These arguments may
#   include a parser, specified with the keys "parser" or "from",
#   and a producer, specified with the keys "producer" or "to".
#
#   The values that can be passed as the parser or producer are
#   given directly to the parser or producer methods, respectively.
#   See the appropriate method description below for details about
#   what each expects/accepts.
# ----------------------------------------------------------------------
sub init {
    my ( $self, $config ) = @_;

    #
    # Set the parser and producer.
    #
    # If a 'parser' or 'from' parameter is passed in, use that as the
    # parser; if a 'producer' or 'to' parameter is passed in, use that
    # as the producer; both default to $DEFAULT_SUB.
    #
    $self->parser  ($config->{'parser'}   || $config->{'from'} || $DEFAULT_SUB);
    $self->producer($config->{'producer'} || $config->{'to'}   || $DEFAULT_SUB);

	#
	# Set up callbacks for formatting of pk,fk,table,package names in producer
	#
	$self->format_table_name($config->{'format_table_name'});
	$self->format_package_name($config->{'format_package_name'});
	$self->format_fk_name($config->{'format_fk_name'});
	$self->format_pk_name($config->{'format_pk_name'});

    #
    # Set the parser_args and producer_args
    #
    for my $pargs ( qw[ parser_args producer_args ] ) {
        $self->$pargs( $config->{$pargs} ) if defined $config->{ $pargs };
    }

    #
    # Set the data source, if 'filename' or 'file' is provided.
    #
    $config->{'filename'} ||= $config->{'file'} || "";
    $self->filename( $config->{'filename'} ) if $config->{'filename'};

    #
    # Finally, if there is a 'data' parameter, use that in 
    # preference to filename and file
    #
    if ( my $data = $config->{'data'} ) {
        $self->data( $data );
    }

    #
    # Set various other options.
    #
    $self->{'debug'} = defined $config->{'debug'} ? $config->{'debug'} : $DEBUG;

    $self->add_drop_table( $config->{'add_drop_table'} );
    
    $self->no_comments( $config->{'no_comments'} );

    $self->show_warnings( $config->{'show_warnings'} );

    $self->trace( $config->{'trace'} );

    $self->validate( $config->{'validate'} );

    return $self;
}

# ----------------------------------------------------------------------
# add_drop_table([$bool])
# ----------------------------------------------------------------------
sub add_drop_table {
    my $self = shift;
    if ( defined (my $arg = shift) ) {
        $self->{'add_drop_table'} = $arg ? 1 : 0;
    }
    return $self->{'add_drop_table'} || 0;
}

# ----------------------------------------------------------------------
# no_comments([$bool])
# ----------------------------------------------------------------------
sub no_comments {
    my $self = shift;
    my $arg  = shift;
    if ( defined $arg ) {
        $self->{'no_comments'} = $arg ? 1 : 0;
    }
    return $self->{'no_comments'} || 0;
}


# ----------------------------------------------------------------------
# producer([$producer_spec])
#
# Get or set the producer for the current translator.
# ----------------------------------------------------------------------
sub producer {
    my $self = shift;

    # producer as a mutator
    if (@_) {
        my $producer = shift;

        # Passed a module name (string containing "::")
        if ($producer =~ /::/) {
            my $func_name;

            # Module name was passed directly
            # We try to load the name; if it doesn't load, there's
            # a possibility that it has a function name attached to
            # it.
            if (load($producer)) {
                $func_name = "produce";
            } 

            # Module::function was passed
            else {
                # Passed Module::Name::function; try to recover
                my @func_parts = split /::/, $producer;
                $func_name = pop @func_parts;
                $producer = join "::", @func_parts;

                # If this doesn't work, then we have a legitimate
                # problem.
                load($producer) or die "Can't load $producer: $@";
            }

            # get code reference and assign
            $self->{'producer'} = \&{ "$producer\::$func_name" };
            $self->{'producer_type'} = $producer;
            $self->debug("Got producer: $producer\::$func_name\n");
        } 

        # passed an anonymous subroutine reference
        elsif (isa($producer, 'CODE')) {
            $self->{'producer'} = $producer;
            $self->{'producer_type'} = "CODE";
            $self->debug("Got producer: code ref\n");
        } 

        # passed a string containing no "::"; relative package name
        else {
            my $Pp = sprintf "SQL::Translator::Producer::$producer";
            load($Pp) or die "Can't load $Pp: $@";
            $self->{'producer'} = \&{ "$Pp\::produce" };
            $self->{'producer_type'} = $Pp;
            $self->debug("Got producer: $Pp\n");
        }

        # At this point, $self->{'producer'} contains a subroutine
        # reference that is ready to run

        # Anything left?  If so, it's producer_args
        $self->producer_args(@_) if (@_);
    }

    return $self->{'producer'};
};

# ----------------------------------------------------------------------
# producer_type()
#
# producer_type is an accessor that allows producer subs to get
# information about their origin.  This is poptentially important;
# since all producer subs are called as subroutine references, there is
# no way for a producer to find out which package the sub lives in
# originally, for example.
# ----------------------------------------------------------------------
sub producer_type { $_[0]->{'producer_type'} }

# ----------------------------------------------------------------------
# producer_args([\%args])
#
# Arbitrary name => value pairs of paramters can be passed to a
# producer using this method.
#
# If the first argument passed in is undef, then the hash of arguments
# is cleared; all subsequent elements are added to the hash of name,
# value pairs stored as producer_args.
# ----------------------------------------------------------------------
sub producer_args {
    my $self = shift;
    return $self->_args("producer", @_);
}

# ----------------------------------------------------------------------
# parser([$parser_spec])
# ----------------------------------------------------------------------
sub parser {
    my $self = shift;

    # parser as a mutator
    if (@_) {
        my $parser = shift;

        # Passed a module name (string containing "::")
        if ($parser =~ /::/) {
            my $func_name;

            # Module name was passed directly
            # We try to load the name; if it doesn't load, there's
            # a possibility that it has a function name attached to
            # it.
            if (load($parser)) {
                $func_name = "parse";
            }

            # Module::function was passed
            else {
                # Passed Module::Name::function; try to recover
                my @func_parts = split /::/, $parser;
                $func_name = pop @func_parts;
                $parser = join "::", @func_parts;

                # If this doesn't work, then we have a legitimate
                # problem.
                load($parser) or die "Can't load $parser: $@";
            } 

            # get code reference and assign
            $self->{'parser'} = \&{ "$parser\::$func_name" };
            $self->{'parser_type'} = $parser;
            $self->debug("Got parser: $parser\::$func_name\n");
        }

        # passed an anonymous subroutine reference
        elsif ( isa( $parser, 'CODE' ) ) {
            $self->{'parser'}      = $parser;
            $self->{'parser_type'} = "CODE";
            $self->debug("Got parser: code ref\n");
        } 

        # passed a string containing no "::"; relative package name
        else {
            my $Pp = "SQL::Translator::Parser::$parser";
            load( $Pp ) or die "Can't load $Pp: $@";
            $self->{'parser'}      = \&{ "$Pp\::parse" };
            $self->{'parser_type'} = $Pp;
            $self->debug("Got parser: $Pp\n");
        } 

        #
        # At this point, $self->{'parser'} contains a subroutine
        # reference that is ready to run
        #
        $self->parser_args( @_ ) if (@_);
    }

    return $self->{'parser'};
}

# ----------------------------------------------------------------------
sub parser_type { $_[0]->{'parser_type'} }

sub parser_args {
    my $self = shift;
    return $self->_args("parser", @_);
}

sub show_warnings {
    my $self = shift;
    my $arg  = shift;
    if ( defined $arg ) {
        $self->{'show_warnings'} = $arg ? 1 : 0;
    }
    return $self->{'show_warnings'} || 0;
}


# filename - get or set the filename
sub filename {
    my $self = shift;
    if (@_) {
        my $filename = shift;
        if (-d $filename) {
            my $msg = "Cannot use directory '$filename' as input source";
            return $self->error($msg);
	} elsif (ref($filename) eq 'ARRAY') {
	    $self->{'filename'} = $filename;
	    $self->debug("Got array of files: ".join(', ',@$filename)."\n");
        } elsif (-f _ && -r _) {
            $self->{'filename'} = $filename;
            $self->debug("Got filename: '$self->{'filename'}'\n");
        } else {
            my $msg = "Cannot use '$filename' as input source: ".
                      "file does not exist or is not readable.";
            return $self->error($msg);
        }
    }

    $self->{'filename'};
}

# ----------------------------------------------------------------------
# data([$data])
#
# if $self->{'data'} is not set, but $self->{'filename'} is, then
# $self->{'filename'} is opened and read, with the results put into
# $self->{'data'}.
# ----------------------------------------------------------------------
sub data {
    my $self = shift;

    # Set $self->{'data'} based on what was passed in.  We will
    # accept a number of things; do our best to get it right.
    if (@_) {
        my $data = shift;
        if (isa($data, "SCALAR")) {
            $self->{'data'} =  $data;
        }
        else {
            if (isa($data, 'ARRAY')) {
                $data = join '', @$data;
            }
            elsif (isa($data, 'GLOB')) {
                local $/;
                $data = <$data>;
            }
            elsif (! ref $data && @_) {
                $data = join '', $data, @_;
            }
            $self->{'data'} = \$data;
        }
    }

    # If we have a filename but no data yet, populate.
    if (not $self->{'data'} and my $filename = $self->filename) {
        $self->debug("Opening '$filename' to get contents.\n");
        local *FH;
        local $/;
        my $data;

	my @files = ref($filename) eq 'ARRAY' ? @$filename : ($filename);

	foreach my $file (@files) {
	        unless (open FH, $file) {
	            return $self->error("Can't read file '$file': $!");
	        }

	        $data .= <FH>;

	        unless (close FH) {
	            return $self->error("Can't close file '$file': $!");
	        }
	}

	$self->{'data'} = \$data;
    }

    return $self->{'data'};
}

# ----------------------------------------------------------------------
sub schema {
#
# Returns the SQL::Translator::Schema object
#
    my $self = shift;

    unless ( defined $self->{'schema'} ) {
        $self->{'schema'} = SQL::Translator::Schema->new;
    }

    return $self->{'schema'};
}

# ----------------------------------------------------------------------
sub trace {
    my $self = shift;
    my $arg  = shift;
    if ( defined $arg ) {
        $self->{'trace'} = $arg ? 1 : 0;
    }
    return $self->{'trace'} || 0;
}

# ----------------------------------------------------------------------
# translate([source], [\%args])
#
# translate does the actual translation.  The main argument is the
# source of the data to be translated, which can be a filename, scalar
# reference, or glob reference.
#
# Alternatively, translate takes optional arguements, which are passed
# to the appropriate places.  Most notable of these arguments are
# parser and producer, which can be used to set the parser and
# producer, respectively.  This is the applications last chance to set
# these.
#
# translate returns a string.
# ----------------------------------------------------------------------
sub translate {
    my $self = shift;
    my ($args, $parser, $parser_type, $producer, $producer_type);
    my ($parser_output, $producer_output);

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
    unless (ref($data) eq 'SCALAR' and length $$data) {
        return $self->error("Empty data file!");
    }

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
    # Execute the parser, then execute the producer with that output.
    # Allowances are made for each piece to die, or fail to compile,
    # since the referenced subroutines could be almost anything.  In
    # the future, each of these might happen in a Safe environment,
    # depending on how paranoid we want to be.
    # ----------------------------------------------------------------
    eval { $parser_output = $parser->($self, $$data) };
    if ($@ || ! $parser_output) {
        my $msg = sprintf "translate: Error with parser '%s': %s",
            $parser_type, ($@) ? $@ : " no results";
        return $self->error($msg);
    }

    if ( $self->validate ) {
        my $schema = $self->schema;
        return $self->error('Invalid schema') unless $schema->is_valid;
    }

    eval { $producer_output = $producer->($self) };
    if ($@ || ! $producer_output) {
        my $msg = sprintf "translate: Error with producer '%s': %s",
            $producer_type, ($@) ? $@ : " no results";
        return $self->error($msg);
    }

    return $producer_output;
}

# ----------------------------------------------------------------------
# list_parsers()
#
# Hacky sort of method to list all available parsers.  This has
# several problems:
#
#   - Only finds things in the SQL::Translator::Parser namespace
#
#   - Only finds things that are located in the same directory
#     as SQL::Translator::Parser.  Yeck.
#
# This method will fail in several very likely cases:
#
#   - Parser modules in different namespaces
#
#   - Parser modules in the SQL::Translator::Parser namespace that
#     have any XS componenets will be installed in
#     arch_lib/SQL/Translator.
#
# ----------------------------------------------------------------------
sub list_parsers {
    return shift->_list("parser");
}

# ----------------------------------------------------------------------
# list_producers()
#
# See notes for list_parsers(), above; all the problems apply to
# list_producers as well.
# ----------------------------------------------------------------------
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
    my $type = shift;
    $type = "${type}_args" unless $type =~ /_args$/;

    unless (defined $self->{$type} && isa($self->{$type}, 'HASH')) {
        $self->{$type} = { };
    }

    if (@_) {
        # If the first argument is an explicit undef (remember, we
        # don't get here unless there is stuff in @_), then we clear
        # out the producer_args hash.
        if (! defined $_[0]) {
            shift @_;
            %{$self->{$type}} = ();
        }

        my $args = isa($_[0], 'HASH') ? shift : { @_ };
        %{$self->{$type}} = (%{$self->{$type}}, %$args);
    }

    $self->{$type};
}

# ----------------------------------------------------------------------
# _list($type)
# ----------------------------------------------------------------------
sub _list {
    my $self = shift;
    my $type = shift || return ();
    my $uctype = ucfirst lc $type;
    my %found;

    load("SQL::Translator::$uctype") or return ();
    my $path = catfile "SQL", "Translator", $uctype;
    for (@INC) {
        my $dir = catfile $_, $path;
        $self->debug("_list_${type}s searching $dir");
        next unless -d $dir;

        my $dh = IO::Dir->new($dir);
        for (grep /\.pm$/, $dh->read) {
            s/\.pm$//;
            $found{ join "::", "SQL::Translator::$uctype", $_ } = 1;
        }
    }

    return keys %found;
}

# ----------------------------------------------------------------------
# load($module)
#
# Loads a Perl module.  Short circuits if a module is already loaded.
# ----------------------------------------------------------------------
sub load {
    my $module = do { my $m = shift; $m =~ s[::][/]g; "$m.pm" };
    return 1 if $INC{$module};

    eval {
        require $module;
        $module->import(@_);
    };

    return __PACKAGE__->error($@) if ($@);
    return 1;
}

# ----------------------------------------------------------------------
sub format_table_name {
    my $self = shift;
    my $sub  = shift;
    $self->{'_format_table_name'} = $sub if ref $sub eq 'CODE';
    return $self->{'_format_table_name'}->( $sub, @_ ) 
        if defined $self->{'_format_table_name'};
    return $sub;
}

# ----------------------------------------------------------------------
sub format_package_name {
    my $self = shift;
    my $sub  = shift;
    $self->{'_format_package_name'} = $sub if ref $sub eq 'CODE';
    return $self->{'_format_package_name'}->( $sub, @_ ) 
        if defined $self->{'_format_package_name'};
    return $sub;
}

# ----------------------------------------------------------------------
sub format_fk_name {
    my $self = shift;
    my $sub  = shift;
    $self->{'_format_fk_name'} = $sub if ref $sub eq 'CODE';
    return $self->{'_format_fk_name'}->( $sub, @_ ) 
        if defined $self->{'_format_fk_name'};
    return $sub;
}

# ----------------------------------------------------------------------
sub format_pk_name {
    my $self = shift;
    my $sub  = shift;
    $self->{'_format_pk_name'} = $sub if ref $sub eq 'CODE';
    return $self->{'_format_pk_name'}->( $sub, @_ ) 
        if defined $self->{'_format_pk_name'};
    return $sub;
}

# ----------------------------------------------------------------------
# isa($ref, $type)
#
# Calls UNIVERSAL::isa($ref, $type).  I think UNIVERSAL::isa is ugly,
# but I like function overhead.
# ----------------------------------------------------------------------
sub isa($$) {
    my ($ref, $type) = @_;
    return UNIVERSAL::isa($ref, $type);
}

# ----------------------------------------------------------------------
sub validate {
    my ( $self, $arg ) = @_;
    if ( defined $arg ) {
        $self->{'validate'} = $arg ? 1 : 0;
    }
    return $self->{'validate'} || 0;
}

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

The SQLFairy project began with the idea of simplifying the task of
converting one database create syntax to another through the use of
Parsers (which understand the source format) and Producers (which
understand the destination format).  The idea is that any Parser can
be used with any Producer in the conversion process, so, if you
wanted Postgres-to-Oracle, you would use the Postgres parser and the
Oracle producer.  The project has since grown to include parsing
structured data files like Excel spreadsheets and delimited text files
and the production of various documentation aids, such as images,
graphs, POD, and HTML descriptions of the schema, as well as automatic
code generators through the use of Class::DBI.  Presently only the 
definition parts of SQL are handled (CREATE, ALTER), not the 
manipulation of data (INSERT, UPDATE, DELETE).

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

filename / file

=item *

data

=item *

debug

=item *

add_drop_table

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

=head2 no_comments

Toggles whether to print comments in the output.  Accepts a true or false
value, returns the current value.

=head2 producer

The C<producer> method is an accessor/mutator, used to retrieve or
define what subroutine is called to produce the output.  A subroutine
defined as a producer will be invoked as a function (I<not a method>)
and passed 2 parameters: its container C<SQL::Translator> instance and a
data structure.  It is expected that the function transform the data
structure to a string.  The C<SQL::Transformer> instance is provided for
informational purposes; for example, the type of the parser can be
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

=head2 show_warnings

Toggles whether to print warnings of name conflicts, identifier
mutations, etc.  Probably only generated by producers to let the user
know when something won't translate very smoothly (e.g., MySQL "enum"
fields into Oracle).  Accepts a true or false value, returns the
current value.

=head2 translate

The C<translate> method calls the subroutines referenced by the
C<parser> and C<producer> data members (described above).  It accepts
as arguments a number of things, in key => value format, including
(potentially) a parser and a producer (they are passed directly to the
C<parser> and C<producer> methods).

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

=head1 AUTHORS

Ken Y. Clark, E<lt>kclark@cpan.orgE<gt>,
darren chamberlain E<lt>darren@cpan.orgE<gt>, 
Chris Mungall E<lt>cjm@fruitfly.orgE<gt>, 
Allen Day E<lt>allenday@users.sourceforge.netE<gt>,
Sam Angiuoli E<lt>angiuoli@users.sourceforge.netE<gt>,
Ying Zhang E<lt>zyolive@yahoo.comE<gt>,
Mike Mellilo <mmelillo@users.sourceforge.net>.

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
USA

=head1 BUGS

Please use http://rt.cpan.org/ for reporting bugs.

=head1 SEE ALSO

L<perl>,
L<SQL::Translator::Parser>,
L<SQL::Translator::Producer>,
L<Parse::RecDescent>,
L<GD>,
L<GraphViz>,
L<Text::RecordParser>,
L<Class::DBI>
L<XML::Writer>.
