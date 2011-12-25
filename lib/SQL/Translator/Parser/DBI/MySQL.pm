package SQL::Translator::Parser::DBI::MySQL;

=head1 NAME

SQL::Translator::Parser::DBI::MySQL - parser for DBD::mysql

=head1 SYNOPSIS

This module will be invoked automatically by SQL::Translator::Parser::DBI,
so there is no need to use it directly.

=head1 DESCRIPTION

Uses SQL calls to query database directly for schema rather than parsing
a create file.  Should be much faster for larger schemas.

=cut

use strict;
use warnings;
use DBI;
use Data::Dumper;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Parser::MySQL;

our ( $DEBUG, @EXPORT_OK );
our $VERSION = '1.59';
$DEBUG   = 0 unless defined $DEBUG;

sub parse {
    my ( $tr, $dbh ) = @_;
    my $schema       = $tr->schema;
    my @table_names  = @{ $dbh->selectcol_arrayref('show tables') };
    my @skip_tables  = defined $tr->parser_args->{skip}
                       ? split(/,/, $tr->parser_args->{skip})
                       : ();

    $dbh->{'FetchHashKeyName'} = 'NAME_lc';

    my $create;
    for my $table_name ( @table_names ) {
        next if (grep /^$table_name$/, @skip_tables);
        my $sth = $dbh->prepare("show create table $table_name");
        $sth->execute;
        my $table = $sth->fetchrow_hashref;
        $create .= $table->{'create table'} . ";\n\n";
    }

    SQL::Translator::Parser::MySQL::parse( $tr, $create );

    return 1;
}

1;

# -------------------------------------------------------------------
# Where man is not nature is barren.
# William Blake
# -------------------------------------------------------------------

=pod

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=head1 SEE ALSO

SQL::Translator.

=cut
