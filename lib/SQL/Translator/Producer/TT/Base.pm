package SQL::Translator::Producer::TT::Base;

# -------------------------------------------------------------------
# $Id: Base.pm,v 1.1 2004-04-14 19:19:44 grommit Exp $
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

SQL::Translator::Producer::TT::Base - TT based Producer base class.

=head1 SYNOPSIS

 package SQL::Translator::Producer::Foo;
 use base qw/SQL::Translator::Producer::TT::Base/;

 # Convert produce call into an object of our new class
 sub produce { return __PACKAGE__->new( translator => shift )->run; };

 # Return file name or template source
 sub tt_schema { local $/ = undef; return \<DATA>; }

 # Extra vars to add to the template
 sub tt_vars   { ( foo => "bar" ); }

=head1 DESCRIPTION

A base class producer designed to be sub-classed to create new TT base
producers cheaply by simply giving the template to use and sprinkling in some 
extra template variables.

See the synopsis above for an example of creating a simple producer using
a single template stored in the producers DATA section.

WARNING: This is currently WORK IN PROGRESS and so subject to change, 
but it does work ;-)

=cut

# -------------------------------------------------------------------

use strict;

use vars qw[ $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;

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

# Until args access method.
# No args - Return hashref (the actual hash in Translator) or hash of args.
# 1 arg   - Return that named args value.
# Args    - List of names. Return values of the given arg names in list context
#           or return as hashref in scalar context. Any names given that don't
#           exists in the args return undef.
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
    my $tt       = Template->new(
        #DEBUG    => $me->translator->debug,
        ABSOLUTE => 1, # Set so we can use from the command line sensibly
        RELATIVE => 1, # Maybe the cmd line code should set it! Security!
        %args,         # Allow any TT opts to be passed in the producer_args
    ) || die "Failed to initialize Template object: ".Template->error;

    $tt->process( $tmpl, { $me->tt_default_vars, $me->tt_vars, }, \$out )
    or die "Error processing template '$tmpl': ".$tt->error;

    return $out;
}

# Returns template file to use, or a scalar ref of tt source, or io handle.
# See L<Template>
sub tt_schema { shift->args("ttfile") };

# Returns hash-ref of the defaults vars given to the template.
# You wouldn't normally over-ride but here just in case.
sub tt_default_vars {
    my $me = shift;
    return (
        translator => $me->translator,
        schema     => $me->translator->schema,
    );
}

# Return hash of template vars to add to the default set.
sub tt_vars { () };
1;

# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Mark Addison E<lt>grommit@users.sourceforge.netE<gt>.

=head1 TODO

Lots! But the next things include;

- Hook to allow sub-class to set the options given to the C<Template> instance.

- Add support for a sqlf template repository somewhere, set as an INCLUDE_PATH,
so that sub-classes can easily include file based templates.

- Merge in TT::Table.

=head1 SEE ALSO

SQL::Translator.

=cut
