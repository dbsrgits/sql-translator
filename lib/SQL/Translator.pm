package SQL::Translator;

#-----------------------------------------------------
# $Id: Translator.pm,v 1.3.2.2 2002-03-15 20:13:46 dlc Exp $
#-----------------------------------------------------
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
  $translator->parser("MySQL");
  $translator->producer("Oracle");

  my $output = $translator->translate($file) or die $translator->error;
  print $output;

=head1 DESCRIPTION

This module attempts to simplify the task of converting one database
create syntax to another through the use of Parsers and Producers.
The idea is that any Parser can be used with any Producer in the
conversion process.  So, if you wanted PostgreSQL-to-Oracle, you could
just write the PostgreSQL parser and use an existing Oracle producer.

Currently, the existing parsers use Parse::RecDescent, but this not
a requirement, or even a recommendation.  New parser modules don't
necessarily have to use Parse::RecDescent, as long as the module
implements the appropriate API.  With this separation of code, it is
hoped that developers will find it easy to add more database dialects
by using what's written, writing only what they need, and then
contributing their parsers or producers back to the project.

=cut

use strict;
use vars qw($VERSION $DEFAULT_SUB $DEBUG);
$VERSION = sprintf "%d.%02d", q$Revision: 1.3.2.2 $ =~ /(\d+)\.(\d+)/;
$DEBUG = 1 unless defined $DEBUG;

$DEFAULT_SUB = sub { $_[0] } unless defined $DEFAULT_SUB;

*can = \&UNIVERSAL::can;
*isa = \&UNIVERSAL::isa;

=head1 CONSTRUCTOR

The constructor is called B<new>, and accepts a optional hash of options.
Valid options are:

=over 4

=item parser (aka from)

=item producer (aka to)

=item filename

=back

All options are, well, optional; these attributes can be set via
instance methods.

=cut

# {{{ new

sub new {
    my $class = shift;
    my $args  = isa($_[0], 'HASH') ? shift : { @_ };
    my $self  = bless { } => $class;

    # 
    # Set the parser and producer.  If a 'parser' or 'from' parameter
    # is passed in, use that as the parser; if a 'producer' or 'to'
    # parameter is passed in, use that as the producer; both default
    # to $DEFAULT_SUB.
    #
    $self->parser(  $args->{'parser'}   || $args->{'from'} || $DEFAULT_SUB);
    $self->producer($args->{'producer'} || $args->{'to'}   || $DEFAULT_SUB);

    #
    # Clear the error
    #
    $self->error_out("");

    return $self;
}
# }}}

=head1 METHODS


=head2 B<producer>

The B<producer> method is an accessor/mutator, used to retrieve or
define what subroutine is called to produce the output.  A subroutine
defined as a producer subroutine will be invoked as a function (not a
method) and passed 2 parameters: its encompassing SQL::Translator
instance and a data structure.  It is expected that the function
transform the data structure to the output format, and return a
string.  The SQL::Transformer instance is provided for informational
purposes; the type of the parser, for example, can be retrieved using
the B<parser_type> method, and the B<error> and B<debug> methods can
be called when needed.

When defining a producer, one of three things can be passed
in:  A full module name (e.g., My::Groovy::Parser), a module name
relative to the SQL::Translator::Producer namespace (e.g., MySQL), or
a reference to an anonymous subroutine.  If a full module name is
passed in, it is treated as a package, and a function called
"produce" will be invoked as $modulename::produce.

  my $tr = SQL::Translator->new;

  # This will invoke My::Groovy::Producer::produce($tr, $data)
  $tr->producer("My::Groovy::Producer");

  # This will invoke SQL::Translator::Producer::Sybase::produce($tr, $data)
  $tr->producer("Sybase");

  # This will invoke the referenced subroutine directly, as
  # $subref->($tr, $data);
  $tr->producer(\&my_producer);

There is also a method named B<producer_type>, which is a string
containing the classname to which the above B<produce> function
belongs.  In the case of anonymous subroutines, this method returns
the string "CODE".

=cut

# {{{ producer and producer_type
sub producer {
    my $self = shift;
    if (@_) {
        my $producer = shift;
        if ($producer =~ /::/) {
            my $func_name;
            if (load($producer)) {
                $func_name = "produce";
            } else {
                # Oops!  Passed Module::Name::function; try to recover
                my @func_parts = split /::/, $producer;
                $func_name = pop @func_parts;
                $producer = join "::", @func_parts;
                load($producer) or die "Can't load $producer: $@";
            }

            $self->{'producer'} = \&{ "$producer\::$func_name" };
            $self->{'producer_type'} = $producer;
            $self->debug("Got 'producer': $producer\::$func_name");
        } elsif (isa($producer, 'CODE')) {
            $self->{'producer'} = $producer;
            $self->{'producer_type'} = "CODE";
            $self->debug("Got 'producer': code ref");
        } else {
            my $Pp = sprintf "SQL::Translator::Producer::$producer";
            load($Pp) or die "Can't load $Pp: $@";
            $self->{'producer'} = \&{ "$Pp\::produce" };
            $self->{'producer_type'} = $Pp;
            $self->debug("Got producer: $Pp");
        }
        # At this point, $self->{'producer'} contains a subroutine
        # reference that is ready to run!
    }
    return $self->{'producer'};
};

sub producer_type { $_[0]->{'producer_type'} }
# }}}

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

=cut

# {{{ parser and parser_type
sub parser {
    my $self = shift;
    if (@_) {
        my $parser = shift;
        if ($parser =~ /::/) {
            load($parser) or die "Can't load $parser: $@";
            $self->{'parser'} = \&{ "$parser\::parse" };
            $self->{'parser_type'} = $parser;
            $self->debug("Got parser: $parser\::parse");
        } elsif (isa($parser, 'CODE')) {
            $self->{'parser'} = $parser;
            $self->{'parser_type'} = "CODE";
            $self->debug("Got parser: code ref");
        } else {
            my $Pp = "SQL::Translator::Parser::$parser";
            load($Pp) or die "Can't load $Pp: $@";
            $self->{'parser'} = \&{ "$Pp\::parse" };
            $self->{'parser_type'} = $Pp;
            $self->debug("Got parser: $Pp");
        }
        # At this point, $self->{$pp} contains a subroutine
        # reference that is ready to run!
    }
    return $self->{'parser'};
}

sub parser_type { $_[0]->{'parser_type'} }
# }}}

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
(filename), a reference to a GLOB (filehandle from which to read a
string), a refernce to a scalar (a string stored in memory), or a
reference to a hash (which means the same thing as below).

  # Parse the file /path/to/datafile
  my $output = $tr->translate("/path/to/datafile");

  # The same thing:
  my $fh = IO::File->new("/path/to/datafile");
  my $output = $tr->translate($fh);

  # Again, the same thing:
  my $fh = IO::File->new("/path/to/datafile");
  my $data = { local $/; <$fh> };
  my $output = $tr->translate(\$data);

=item *

More than 1 argument means its a hash of things, and it might be
setting a parser, producer, or datasource (this key is named
"filename" or "file" if it's a file, or "data" for a GLOB or
SCALAR reference).

  # As above, parse /path/to/datafile, but with different producers
  for my $prod ("MySQL", "XML", "Sybase") {
      print $tr->translate(
                producer => $prod,
                filename => "/path/to/datafile",
            );
  }

  # The filename hash key could also be:
      datasource => $fh,

  # or
      datasource => \$data,

You get the idea.

=back

=cut

# {{{ translate
sub translate {
    my $self = shift;
    my ($args, $parser, $producer);

    if (@_ == 1) {
        if (isa($_[0], 'HASH')) {
            # Passed a hashref
            $self->debug("translate: Got a hashref");
            $args = $_[0];
        }
        elsif (my $getlines = can($_[0], "getlines")) {
            # passed a IO::Handle derivative
            # XXX Something about this does not work!
            # XXX look into how Template does this.
            $self->debug("translate: Got a IO::Handle subclass (can getlines)");
            my $fh = $_[0];
            $fh->setpos(0);
            my $data = join '', $fh->$getlines;
            $args = { data => $data };
        }
        elsif (isa($_[0], 'GLOB')) {
            # passed a filehandle; slurp it
            $self->debug("translate: Got a GLOB");
            local $/;
            $args = { data => <$_[0]> };
        } 
        elsif (isa($_[0], 'SCALAR')) {
            # passed a ref to a string; deref it
            $self->debug("translate: Got a SCALAR reference (string)");
            $args = { data => ${$_[0]} };
        }
        else {
            # Not a ref, it's a filename
            $self->debug("translate: Got a filename");
            $args = { filename => $_[0] };
        }
    }
    else {
        # Should we check if @_ % 2, or just eat the errors if they occur?
        $args = { @_ };
    }

    if ((defined $args->{'filename'} ||
         defined $args->{'file'}   ) && not $args->{'data'}) {
        local *FH;
        local $/;

        open FH, $args->{'filename'} or die "Can't open $args->{'filename'}: $!";
        $args->{'data'} = <FH>;
        close FH or die $!;
    }

    #
    # Last chance to bail out; if there's nothing in the data
    # key of %args, back out.
    #
    return unless defined $args->{'data'};

    use Data::Dumper;
    warn Dumper($args);

    #
    # Local reference to the parser subroutine
    #
    if ($parser = ($args->{'parser'} || $args->{'from'})) {
        $self->parser($parser);
    } else {
        $parser = $self->parser;
    }

    #
    # Local reference to the producer subroutine
    #
    if ($producer = ($args->{'producer'} || $args->{'to'})) {
        $self->producer($producer);
    } else {
        $producer = $self->producer;
    }

    #
    # Execute the parser, then execute the producer with that output
    #
    my $translated = $parser->($self, $args->{'data'});

    return $producer->($self, $translated);
}
# }}}

=head2 B<error>

The error method returns the last error.

=cut

# {{{ error
#-----------------------------------------------------
sub error {
#
# Return the last error.
#
    return shift()->{'error'} || '';
}
# }}}

=head2 B<error_out>

Record the error and return undef.  The error can be retrieved by
calling programs using $tr->error.

For Parser or Producer writers, primarily.  

=cut

# {{{ error_out
sub error_out {
    my $self = shift;
    if ( my $error = shift ) {
        $self->{'error'} = $error;
    }
    return;
}
# }}}

=head2 B<debug>

If the global variable $SQL::Translator::DEBUG is set to a true value,
then calls to $tr->debug($msg) will be carped to STDERR.  If $DEBUG is
not set, then this method does nothing.

=cut

# {{{ debug
use Carp qw(carp);
sub debug {
    my $self = shift;
    carp @_ if ($DEBUG);
}
# }}}

# {{{ load
sub load {
    my $module = do { my $m = shift; $m =~ s[::][/]g; "$m.pm" };
    return 1 if $INC{$module};
    
    eval { require $module };
    
    return if ($@);
    return 1;
}
# }}}

1;

__END__
#-----------------------------------------------------
# Rescue the drowning and tie your shoestrings.
# Henry David Thoreau 
#-----------------------------------------------------

=head1 AUTHOR

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
