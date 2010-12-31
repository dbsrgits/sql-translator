package SQL::Translator::Producer::TT::Table;

# -------------------------------------------------------------------
# Copyright (C) 2002-2009 SQLFairy Authors
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

SQL::Translator::Producer::TT::Table -
    Produces output using the Template Toolkit from a SQL schema, per table.

=head1 SYNOPSIS

  # Normal STDOUT version
  #
  my $translator     = SQL::Translator->new(
      from           => 'MySQL',
      filename       => 'foo_schema.sql',
      to             => 'TT::Table',
      producer_args  => {
          tt_table     => 'foo_table.tt',
      },
  );
  print $translator->translate;

  # To generate a file per table
  #
  my $translator     = SQL::Translator->new(
      from           => 'MySQL',
      filename       => 'foo_schema.sql',
      to             => 'TT::Table',
      producer_args  => {
          tt_table       => 'foo_table.tt.html',
          mk_files      => 1,
          mk_files_base => "./doc/tables",
          mk_file_ext   => ".html",
          on_exists     => "replace",
      },
  );
  #
  # ./doc/tables/ now contains the templated tables as $tablename.html
  #

=head1 DESCRIPTION

Produces schema output using a given Template Tookit template,
processing that template for each table in the schema. Optionally
allows you to write the result for each table to a separate file.

It needs one additional producer_arg of C<tt_table> which is the file
name of the template to use.  This template will be passed a template
var of C<table>, which is the current
L<SQL::Translator::Producer::Table> table we are producing, which you
can then use to walk the schema via the methods documented in that
module. You also get L<schema> as a shortcut to the
L<SQL::Translator::Producer::Schema> for the table and C<translator>,
the L<SQL::Translator> object for this parse in case you want to get
access to any of the options etc set here.

Here's a brief example of what the template could look like:

  [% table.name %]
  ================
  [% FOREACH field = table.get_fields %]
      [% field.name %]   [% field.data_type %]([% field.size %])
  [% END -%]

See F<t/data/template/table.tt> for a more complete example.

You can also set any of the options used to initiallize the Template
object by adding them to your producer_args. See Template Toolkit docs
for details of the options.

  $translator          = SQL::Translator->new(
      to               => 'TT',
      producer_args    => {
          ttfile       => 'foo_template.tt',
          INCLUDE_PATH => '/foo/templates/tt',
          INTERPOLATE  => 1,
      },
  );

If you set C<mk_files> and its additional options the producer will
write a separate file for each table in the schema. This is useful for
producing things like HTML documentation where every table gets its
own page (you could also use TTSchema producer to add an index page).
Its also particulary good for code generation where you want to
produce a class file per table.

=head1 OPTIONS

=over 4

=item tt_table

File name of the template to run for each table.

=item mk_files

Set to true to output a file for each table in the schema (as well as
returning the whole lot back to the Translalor and hence STDOUT). The
file will be named after the table, with the optional C<mk_files_ext>
added and placed in the directory C<mk_files_base>.

=item mk_files_ext

Extension (without the dot) to add to the filename when using mk_files.

=item mk_files_base = DIR

Dir to build the table files into when using mk_files. Defaults to the
current directory.

=item mk_file_dir

Set true and if the file needs to written to a directory that doesn't
exist, it will be created first.

=item on_exists [Default:replace]

What to do if we are running with mk_files and a file already exists
where we want to write our output. One of "skip", "die", "replace",
"insert".  The default is die.

B<replace> - Over-write the existing file with the new one, clobbering
anything already there.

B<skip> - Leave the origional file as it was and don't write the new
version anywhere.

B<die> - Die with an existing file error.

B<insert> - Insert the generated output into the file bewteen a set of
special comments (defined by the following options.) Any code between
the comments will be overwritten (ie the results from a previous
produce) but the rest of the file is left alone (your custom code).
This is particularly useful for code generation as it allows you to
generate schema derived code and then add your own custom code
to the file.  Then when the schema changes you just re-produce to
insert the new code.

=item insert_comment_start

The comment to look for in the file when on_exists is C<insert>. Default
is C<SQLF INSERT START>. Must appear on it own line, with only
whitespace either side, to be recognised.

=item insert_comment_end

The end comment to look for in the file when on_exists is C<insert>.
Default is C<SQLF INSERT END>. Must appear on it own line, with only
whitespace either side, to be recognised.

=back

=cut

# -------------------------------------------------------------------

use strict;

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = '1.59';
$DEBUG   = 0 unless defined $DEBUG;

use File::Path;
use Template;
use Data::Dumper;
use Exporter;
use base qw(Exporter);
@EXPORT_OK = qw(produce);

use SQL::Translator::Utils 'debug';

my $Translator;

sub produce {
    $Translator = shift;
    local $DEBUG   = $Translator->debug;
    my $scma       = $Translator->schema;
    my $pargs      = $Translator->producer_args;
    my $file       = $pargs->{'tt_table'} or die "No template file given!";
    $pargs->{on_exists} ||= "die";

    debug "Processing template $file\n";
    my $out;
    my $tt       = Template->new(
        DEBUG    => $DEBUG,
        ABSOLUTE => 1, # Set so we can use from the command line sensibly
        RELATIVE => 1, # Maybe the cmd line code should set it! Security!
        %$pargs,        # Allow any TT opts to be passed in the producer_args
    ) || die "Failed to initialize Template object: ".Template->error;

	for my $tbl ( sort {$a->order <=> $b->order} $scma->get_tables ) {
		my $outtmp;
        $tt->process( $file, {
            translator => $Translator,
            schema     => $scma,
            table      => $tbl,
        }, \$outtmp ) 
		or die "Error processing template '$file' for table '".$tbl->name
	          ."': ".$tt->error;
        $out .= $outtmp;

        # Write out the file...
		write_file(  table_file($tbl), $outtmp ) if $pargs->{mk_files};
    }

    return $out;
};

# Work out the filename for a given table.
sub table_file {
    my ($tbl) = shift;
    my $pargs = $Translator->producer_args;
    my $root  = $pargs->{mk_files_base};
    my $ext   = $pargs->{mk_file_ext};
    return "$root/$tbl.$ext";
}

# Write the src given to the file given, handling the on_exists arg.
sub write_file {
	my ($file, $src) = @_;
    my $pargs = $Translator->producer_args;
    my $root = $pargs->{mk_files_base};

    if ( -e $file ) {
        if ( $pargs->{on_exists} eq "skip" ) {
            warn "Skipping existing $file\n";
            return 1;
        }
        elsif ( $pargs->{on_exists} eq "die" ) {
            die "File $file already exists.\n";
        }
        elsif ( $pargs->{on_exists} eq "replace" ) {
            warn "Replacing $file.\n";
        }
        elsif ( $pargs->{on_exists} eq "insert" ) {
            warn "Inserting into $file.\n";
            $src = insert_code($file, $src);
        }
        else {
            die "Unknown on_exists action: $pargs->{on_exists}\n";
        }
    }
    else {
        if ( my $interactive = -t STDIN && -t STDOUT ) {
            warn "Creating $file.\n";
        }
    }

    my ($dir) = $file =~ m!^(.*)/!; # Want greedy, eveything before the last /
	if ( $dir and not -d $dir and $pargs->{mk_file_dir} ) { mkpath($dir); }

    debug "Writing to $file\n";
	open( FILE, ">$file") or die "Error opening file $file : $!\n";
	print FILE $src;
	close(FILE);
}

# Reads file and inserts code between the insert comments and returns the new
# source.
sub insert_code {
    my ($file, $src) = @_;
    my $pargs = $Translator->producer_args;
    my $cstart = $pargs->{insert_comment_start} || "SQLF_INSERT_START";
    my $cend   = $pargs->{insert_comment_end}   || "SQLF_INSERT_END";

    # Slurp in the origional file
    open ( FILE, "<", "$file") or die "Error opening file $file : $!\n";
    local $/ = undef;
    my $orig = <FILE>;
    close(FILE);

    # Insert the new code between the insert comments
    unless (
        $orig =~ s/^\s*?$cstart\s*?\n.*?^\s*?$cend\s*?\n/\n$cstart\n$src\n$cend\n/ms
    ) {
        warn "No insert done\n";
    }

    return $orig;
}

1;

# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Mark Addison E<lt>grommit@users.sourceforge.netE<gt>.

=head1 TODO

- Some tests for the various on exists options (they have been tested
implicitley through use in a project but need some proper tests).

- More docs on code generation strategies.

- Better hooks for filename generation.

- Integrate with L<TT::Base> and L<TTSchema>.

=head1 SEE ALSO

SQL::Translator.

=cut
