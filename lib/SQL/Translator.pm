package SQL::Translator;

# ----------------------------------------------------------------------
# $Id: Translator.pm,v 1.11 2002-11-21 17:45:17 dlc Exp $
# ----------------------------------------------------------------------
# Copyright (C) 2002 Ken Y. Clark <kycl4rk@users.sourceforge.net>,
#                    darren chamberlain <darren@cpan.org>
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

=head1 NAME

SQL::Translator - convert schema from one database to another

=head1 SYNOPSIS

  use SQL::Translator;
  my $translator = SQL::Translator->new;
  my $output     = $translator->translate(
      from       => "MySQL",
      to         => "Oracle",
      filename   => $file,
  ) or die $translator->error;
  print $output;

=head1 DESCRIPTION

This module attempts to simplify the task of converting one database
create syntax to another through the use of Parsers (which understand
the sourced format) and Producers (which understand the destination
format).  The idea is that any Parser can be used with any Producer in
the conversion process.  So, if you wanted PostgreSQL-to-Oracle, you
would use the PostgreSQL parser and the Oracle producer.

=cut

use strict;
use vars qw( $VERSION $DEFAULT_SUB $DEBUG $ERROR );
use base 'Class::Base';

$VERSION = sprintf "%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;
$ERROR   = "";

use Carp qw(carp);

use File::Spec::Functions qw(catfile);
use File::Basename qw(dirname);
use IO::Dir;

# ----------------------------------------------------------------------
# The default behavior is to "pass through" values (note that the
# SQL::Translator instance is the first value ($_[0]), and the stuff
# to be parsed is the second value ($_[1])
# ----------------------------------------------------------------------
$DEFAULT_SUB = sub { $_[1] } unless defined $DEFAULT_SUB;

=head1 CONSTRUCTOR

The constructor is called B<new>, and accepts a optional hash of options.
Valid options are:

=over 4

=item parser (aka from)

=item parser_args

=item producer (aka to)

=item producer_args

=item filename (aka file)

=item data

=item debug

=back

All options are, well, optional; these attributes can be set via
instance methods.  Internally, they are; no (non-syntactical)
advantage is gained by passing options to the constructor.

=cut

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

    $self->{'debug'} = defined $config->{'debug'} ? $config->{'debug'} : $DEBUG;

    return $self;
}

=head1 METHODS

=head2 B<producer>

The B<producer> method is an accessor/mutator, used to retrieve or
define what subroutine is called to produce the output.  A subroutine
defined as a producer will be invoked as a function (not a method) and
passed 2 parameters: its container SQL::Translator instance and a
data structure.  It is expected that the function transform the data
structure to a string.  The SQL::Transformer instance is provided for
informational purposes; for example, the type of the parser can be
retrieved using the B<parser_type> method, and the B<error> and
B<debug> methods can be called when needed.

When defining a producer, one of several things can be passed
in:  A module name (e.g., My::Groovy::Producer), a module name
relative to the SQL::Translator::Producer namespace (e.g., MySQL), a
module name and function combination (My::Groovy::Producer::transmogrify),
or a reference to an anonymous subroutine.  If a full module name is
passed in (for the purposes of this method, a string containing "::"
is considered to be a module name), it is treated as a package, and a
function called "produce" will be invoked: $modulename::produce.  If
$modulename cannot be loaded, the final portion is stripped off and
treated as a function.  In other words, if there is no file named
My/Groovy/Producer/transmogrify.pm, SQL::Translator will attempt to load
My/Groovy/Producer.pm and use transmogrify as the name of the function,
instead of the default "produce".

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

There is also a method named B<producer_type>, which is a string
containing the classname to which the above B<produce> function
belongs.  In the case of anonymous subroutines, this method returns
the string "CODE".

Finally, there is a method named B<producer_args>, which is both an
accessor and a mutator.  Arbitrary data may be stored in name => value
pairs for the producer subroutine to access:

  sub My::Random::producer {
      my ($tr, $data) = @_;
      my $pr_args = $tr->producer_args();

      # $pr_args is a hashref.

Extra data passed to the B<producer> method is passed to
B<producer_args>:

  $tr->producer("xSV", delimiter => ',\s*');

  # In SQL::Translator::Producer::xSV:
  my $args = $tr->producer_args;
  my $delimiter = $args->{'delimiter'}; # value is ,\s*

=cut

# producer and producer_type
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
# producer_type
#
# producer_type is an accessor that allows producer subs to get
# information about their origin.  This is poptentially important;
# since all producer subs are called as subroutine refernces, there is
# no way for a producer to find out which package the sub lives in
# originally, for example.
# ----------------------------------------------------------------------
sub producer_type { $_[0]->{'producer_type'} }

# ----------------------------------------------------------------------
# producer_args
#
# Arbitrary name => value pairs of paramters can be passed to a
# producer using this method.
# ----------------------------------------------------------------------
sub producer_args {
    my $self = shift;
    if (@_) {
        my $args = isa($_[0], 'HASH') ? shift : { @_ };
        $self->{'producer_args'} = $args;
    }
    $self->{'producer_args'};
}

=head2 B<parser>

The B<parser> method defines or retrieves a subroutine that will be
called to perform the parsing.  The basic idea is the same as that of
B<producer> (see above), except the default subroutine name is
"parse", and will be invoked as $module_name::parse($tr, $data).
Also, the parser subroutine will be passed a string containing the
entirety of the data to be parsed (or possibly a reference to a string?).

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

There is also B<parser_type> and B<parser_args>, which perform
analogously to B<producer_type> and B<producer_args>

=cut

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

sub parser_type { $_[0]->{'parser_type'} }

# parser_args
sub parser_args {
    my $self = shift;
    if (@_) {
        my $args = isa($_[0], 'HASH') ? shift : { @_ };
        $self->{'parser_args'} = $args;
    }
    $self->{'parser_args'};
} 

=head2 B<translate>

The B<translate> method calls the subroutines referenced by the
B<parser> and B<producer> data members (described above).  It accepts
as arguments a number of things, in key => value format, including
(potentially) a parser and a producer (they are passed directly to the
B<parser> and B<producer> methods).

Here is how the parameter list to B<translate> is parsed:

=over

=item *

1 argument means it's the data to be parsed; which could be a string
(filename) or a refernce to a scalar (a string stored in memory), or a
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

=head2 B<filename>, B<data>

Using the B<filename> method, the filename of the data to be parsed
can be set. This method can be used in conjunction with the B<data>
method, below.  If both the B<filename> and B<data> methods are
invoked as mutators, the data set in the B<data> method is used.

    $tr->filename("/my/data/files/create.sql");

or:

    my $create_script = do {
        local $/;
        open CREATE, "/my/data/files/create.sql" or die $!;
        <CREATE>;
    };
    $tr->data(\$create_script);

B<filename> takes a string, which is interpreted as a filename.
B<data> takes a reference to a string, which is used as the data to be
parsed.  If a filename is set, then that file is opened and read when
the B<translate> method is called, as long as the data instance
variable is not set.

=cut

# filename - get or set the filename
sub filename {
    my $self = shift;
    if (@_) {
        my $filename = shift;
        if (-d $filename) {
            my $msg = "Cannot use directory '$filename' as input source";
            return $self->error($msg);
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

# data - get or set the data
# if $self->{'data'} is not set, but $self->{'filename'} is, then
# $self->{'filename'} is opened and read, whith the results put into
# $self->{'data'}.
sub data {
    my $self = shift;

    # Set $self->{'data'} to $_[0], if it is provided.
    if (@_) {
        my $data = shift;
        if (isa($data, "SCALAR")) {
            $self->{'data'} =  $data;
        }
        elsif (! ref $data) {
            $self->{'data'} = \$data;
        }
    }

    # If we have a filename but no data yet, populate.
    if (not $self->{'data'} and my $filename = $self->filename) {
        $self->debug("Opening '$filename' to get contents.\n");
        local *FH;
        local $/;
        my $data;

        unless (open FH, $filename) {
            return $self->error("Can't read file '$filename': $!");
        }

        $data = <FH>;
        $self->{'data'} = \$data;

        unless (close FH) {
            return $self->error("Can't close file '$filename': $!");
        }
    }

    return $self->{'data'};
}

# translate
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

    if (my $data = ($self->{'data'} || $self->{'datasource'})) {
        $self->data($data);
    }

    # ----------------------------------------------------------------
    # Get the data.
    # ----------------------------------------------------------------
    my $data = $self->data;
    unless (length $$data) {
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

    eval { $producer_output = $producer->($self, $parser_output) };
    if ($@ || ! $producer_output) {
        my $msg = sprintf "translate: Error with producer '%s': %s",
            $producer_type, ($@) ? $@ : " no results";
        return $self->error($msg);
    }

    return $producer_output;
}

sub list_producers {
    require SQL::Translator::Producer;
    my $path = catfile(dirname($INC{'SQL/Translator/Producer.pm'}), "Producer");
    my $dh = IO::Dir->new($path);

    my @available = map { join "::", "SQL::Translator::Producer", $_ }
                    grep /\.pm$/, $dh->read;

    return @available;
}


sub list_parsers {
    require SQL::Translator::Parser;
    my $path = catfile(dirname($INC{'SQL/Translator/Parser.pm'}), "Parser");
    my $dh = IO::Dir->new($path);

    my @available = map { join "::", "SQL::Translator::Parser", $_ }
                    grep /\.pm$/, $dh->read;

    return @available;
}


sub load {
    my $module = do { my $m = shift; $m =~ s[::][/]g; "$m.pm" };
    return 1 if $INC{$module};
    
    eval { require $module };
    
    return if ($@);
    return 1;
}

sub isa { UNIVERSAL::isa($_[0], $_[1]) }

1;

#-----------------------------------------------------
# Rescue the drowning and tie your shoestrings.
# Henry David Thoreau 
#-----------------------------------------------------

=pod

=head1 AUTHORS

Ken Y. Clark, E<lt>kclark@logsoft.comE<gt>,
darren chamberlain E<lt>darren@cpan.orgE<gt>

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

=head1 SEE ALSO

L<perl>, L<Parse::RecDescent>

=cut
