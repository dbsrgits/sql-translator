package SQL::Translator::Producer::SQLServer;

use strict;
use warnings;
our ( $DEBUG, $WARN );
our $VERSION = '1.59';
$DEBUG = 1 unless defined $DEBUG;

use Data::Dumper;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(debug header_comment);
use SQL::Translator::Generator::DDL::SQLServer;

sub produce {
    my $translator     = shift;
    my $future = SQL::Translator::Generator::DDL::SQLServer->new(
      add_comments    => !$translator->no_comments,
      add_drop_tables => $translator->add_drop_table,
    );

    my $no_comments    = $translator->no_comments;
    my $add_drop_table = $translator->add_drop_table;
    my $schema         = $translator->schema;

    my $output;
    $output .= header_comment."\n" unless ($no_comments);

    # Generate the DROP statements.
    $output .= $future->drop_tables;

    # these need to be added separately, as tables may not exist yet
    my @foreign_constraints = ();

    for my $table ( grep { $_->name } $schema->get_tables ) {
        my $table_name_ur = $future->quote($table->name);

        my ( @comments );

        push @comments, "\n\n--\n-- Table: $table_name_ur\n--"
           unless $no_comments;

        push @comments, map { "-- $_" } $table->comments;

        push @foreign_constraints, map $future->foreign_key_constraint($_),
           grep { $_->type eq FOREIGN_KEY } $table->get_constraints;

        $output .= join( "\n\n",
            @comments,
            # index defs
            $future->table($table),
            (map $future->unique_constraint_multiple($_),
               grep {
                  $_->type eq UNIQUE &&
                  grep { $_->is_nullable } $_->fields
               } $table->get_constraints),

            (map $future->index($_), $table->get_indices)
        );
    }

# Add FK constraints
    $output .= join ("\n", '', @foreign_constraints) if @foreign_constraints;

# create view/procedure are NOT prepended to the input $sql, needs
# to be filled in with the proper syntax

    return $output;
}

1;

=pod

=head1 SQLServer Create Table Syntax

TODO


=head1 NAME

SQL::Translator::Producer::SQLServer - MS SQLServer producer for SQL::Translator

=head1 SYNOPSIS

  use SQL::Translator;

  my $t = SQL::Translator->new( parser => '...', producer => 'SQLServer' );
  $t->translate;

=head1 DESCRIPTION

B<WARNING>B This is still fairly early code, basically a hacked version of the
Sybase Producer (thanks Sam, Paul and Ken for doing the real work ;-)

=head1 Extra Attributes

=over 4

=item field.list

List of values for an enum field.

=back

=head1 TODO

 * !! Write some tests !!
 * Reserved words list needs updating to SQLServer.
 * Triggers, Procedures and Views DO NOT WORK


    # Text of view is already a 'create view' statement so no need to
    # be fancy
    foreach ( $schema->get_views ) {
        my $name = $_->name();
        $output .= "\n\n";
        $output .= "--\n-- View: $name\n--\n\n" unless $no_comments;
        my $text = $_->sql();
        $text =~ s/\r//g;
        $output .= "$text\nGO\n";
    }

    # Text of procedure already has the 'create procedure' stuff
    # so there is no need to do anything fancy. However, we should
    # think about doing fancy stuff with granting permissions and
    # so on.
    foreach ( $schema->get_procedures ) {
        my $name = $_->name();
        $output .= "\n\n";
        $output .= "--\n-- Procedure: $name\n--\n\n" unless $no_comments;
        my $text = $_->sql();
      $text =~ s/\r//g;
        $output .= "$text\nGO\n";
    }

=head1 SEE ALSO

SQL::Translator.

=head1 AUTHORS

Mark Addison E<lt>grommit@users.sourceforge.netE<gt> - Bulk of code from
Sybase producer, I just tweaked it for SQLServer. Thanks.

=cut
