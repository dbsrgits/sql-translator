package SQL::Translator::Producer::TT::Base;

# -------------------------------------------------------------------
# $Id: Base.pm,v 1.3 2004-05-14 00:46:32 grommit Exp $
# -------------------------------------------------------------------
# Copyright (C) 2002-4 SQLFairy Authors
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

=pod

=head1 NAME

SQL::Translator::Producer::TT::Base - TT (Template Toolkit) based Producer base
class.

=cut

use strict;

use vars qw[ $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/;

use Template;
use Data::Dumper;
use Exporter;
use base qw(Exporter);
@EXPORT_OK = qw(produce);

use SQL::Translator::Utils 'debug';

# Hack to convert the produce call into an object. ALL sub-classes need todo
# this so that the correct class gets created.
sub produce {
    return __PACKAGE__->new( translator => shift )->run;
};

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;
    my %args  = @_;

    my $me = bless {}, $class;
    $me->{translator} = delete $args{translator} || die "Need a translator.";

    return $me;
}

sub translator { shift->{translator}; }
sub schema     { shift->{translator}->schema(@_); }

# Util args access method.
# No args - Return hashref (the actual hash in Translator) or hash of args.
# 1 arg   - Return that named args value.
# Args    - List of names. Return values of the given arg names in list context
#           or return as hashref in scalar context. Any names given that don't
#           exist in the args are returned as undef.
sub args {
    my $me = shift;

    # No args
    unless (@_) {
        return wantarray
            ? %{ $me->{translator}->producer_args }
            : $me->{translator}->producer_args
        ;
    }

    # 1 arg. Return the value whatever the context.
    return $me->{translator}->producer_args->{$_[0]} if @_ == 1;

    # More args so return values list or hash ref
    my %args = %{ $me->{translator}->producer_args };
    return wantarray ? @args{@_} : { map { ($_=>$args{$_}) } @_ };
}

# Run the produce and return the result.
sub run {
    my $me = shift;
    my $scma = $me->schema;
    my %args = %{$me->args};
    my $tmpl = $me->tt_schema or die "No template!";

    debug "Processing template $tmpl\n";
    my $out;
    my $tt = Template->new(
        #DEBUG    => $me->translator->debug,
        ABSOLUTE => 1,  # Set so we can use from the command line sensibly
        RELATIVE => 1,  # Maybe the cmd line code should set it! Security!
        $me->tt_config, # Hook for sub-classes to add config
        %args,          # Allow any TT opts to be passed in the producer_args
    ) || die "Failed to initialize Template object: ".Template->error;

    $tt->process( $tmpl, {
        $me->tt_default_vars,
        $me->tt_vars,          # Sub-class hook for adding vars
    }, \$out )
    or die "Error processing template '$tmpl': ".$tt->error;

    return $out;
}


# Sub class hooks
#-----------------------------------------------------------------------------

sub tt_config { () };

sub tt_schema { shift->args("ttfile") };

sub tt_default_vars {
    my $me = shift;
    return (
        translator => $me->translator,
        schema     => $me->translator->schema,
    );
}

sub tt_vars   { () };

1;

# -------------------------------------------------------------------

=pod

=head1 SYNOPSIS

 package SQL::Translator::Producer::Foo;

 use base qw/SQL::Translator::Producer::TT::Base/;

 # Convert produce call into an object of our new class
 sub produce { return __PACKAGE__->new( translator => shift )->run; };

 # Return file name or template source
 sub tt_schema { local $/ = undef; \<DATA>; }

 # Configure the Template object.
 sub tt_config { ( INTERPOLATE => 1 ); }

 # Extra vars to add to the template
 sub tt_vars { ( foo => "bar" ); }

=head1 DESCRIPTION

WARNING: This is currently WORK IN PROGRESS and so subject to change,
but it does work ;-)

A base class producer designed to be sub-classed to create new TT based
producers cheaply - by simply giving the template to use and sprinkling in some
extra template variables and config.

The 1st thing the module does is convert the produce sub routine call we get
from SQL::Translator into a method call on an object, so we can sub-class it.
This is done with the following code which B<must> appear in B<all> sub
classes.

 # Convert produce call into an object method call
 sub produce { return __PACKAGE__->new( translator => shift )->run; };

See L<PRODUCER OBJECT> below for details.

The upshot of this is we can make new template producers by writing a template,
then creating a module that starts like this;

 package SQL::Translator::Producer::Foo;

 use base qw/SQL::Translator::Producer::TT::Base/;

 # Convert produce call into an object of our new class
 sub produce { return __PACKAGE__->new( translator => shift )->run; };

And then over ride the hooks detailed below in L<SUB CLASS HOOKS>.

See the L<SYNOPSIS> above for an example of creating a simple producer using
a single template stored in the producers DATA section.

=head1 SUB CLASS HOOKS

Sub-classes should override these methods to control the templating by giving
the template source, adding variables and giving config to the Tempate object.

=head2 tt_config

 sub tt_config { ( INTERPOLATE => 1 ); }

Return hash of Template config to add to the config given to the
C<< Template->new >> method.

=head2 tt_schema

 sub tt_schema { "foo.tt"; }
 sub tt_schema { local $/ = undef; \<DATA>; }

Should return a template file name to use, or a scalar ref of TT source, or
an L<IO::Handle>. See L<Template> for details, as the return from this is passed
on to the produce call.

The default implimentation uses the producer arg C<ttfile> as a filename to read
the template from.

=head2 tt_vars

 sub tt_vars { ( foo => "bar" ); }

Return hash of template vars to use in the template. Doesn't add anything
by default, but see L<tt_default_vars> for the variables you get for free.

=head2 tt_default_vars

Return a hash-ref of the default vars given to the template.
You wouldn't normally over-ride this, just inherit the default implimentation,
to get the C<translator> & C<schema> variables, then over-ride L<tt_vars> to add
your own.

The current default variables are:

=over 4

=item schema

The schema to template.

=item translator

The L<SQL::Translator> object.

=back

=head1 PRODUCER OBJECT

The rest of the methods in the class set up a sub-classable producer object.
You normally just inherit them.

=head2 new

 my $tt_producer = TT::Base->new( translator => $translator );

Construct a new TT Producer object. Takes a single, named arg of the
L<SQL::Translator> object running the translation. Dies if this is not given.

=head2 translator

Return the L<SQL::Translator> object.

=head2 schema

Return the L<SQL::Translator::Schema> we are translating. This is equivilent
to C<< $tt_producer->translator->schema >>.

=head2 args

Util wrapper method around C<< TT::Base->translator->producer_args >> for
(mostley) readonly access to the producer args. How it works depends on the
number of arguments you give it and the context.

 No args - Return hashref (the actual hash in Translator) or hash of args.
 1 arg   - Return value of the arg with the passed name.
 2+ args - List of names. In list context returns values of the given arg names,
           returns as a hashref in scalar context. Any names given that don't
           exist in the args are returned as undef.

This is still experimental but is a handy way to access the args when you use
your own producer args to drive the templating.

=head2 run

Called to actually produce the output, calling the sub class hooks. Returns the
produced text.

=head1 AUTHOR

Mark Addison E<lt>grommit@users.sourceforge.netE<gt>.

=head1 TODO

- Add support for a sqlf template repository, set as an INCLUDE_PATH,
so that sub-classes can easily include file based templates using relative
paths.

- Merge in TT::Table.

- Hooks to pre-process the schema and post-process the output.

=head1 SEE ALSO

SQL::Translator.

=cut
