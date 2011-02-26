package SQL::Translator::Parser::YAML;

use strict;
use warnings;
our $VERSION = '1.59';

use SQL::Translator::Schema;
use SQL::Translator::Utils qw(header_comment);
use Data::Dumper;
use YAML qw(Load);

sub parse {
    my ($translator, $data) = @_;
    $data = Load($data);
    $data = $data->{'schema'};

    warn "YAML data:",Dumper( $data ) if $translator->debug;

    my $schema = $translator->schema;

    #
    # Tables
    #
    my @tables =
        map   { $data->{'tables'}{ $_->[1] } }
        sort  { $a->[0] <=> $b->[0] }
        map   { [ $data->{'tables'}{ $_ }{'order'} || 0, $_ ] }
        keys %{ $data->{'tables'} }
    ;

    for my $tdata ( @tables ) {

        my $table = $schema->add_table(
            map {
              $tdata->{$_} ? ($_ => $tdata->{$_}) : ()
            } (qw/name extra options/)
        ) or die $schema->error;

        my @fields =
            map   { $tdata->{'fields'}{ $_->[1] } }
            sort  { $a->[0] <=> $b->[0] }
            map   { [ $tdata->{'fields'}{ $_ }{'order'}, $_ ] }
            keys %{ $tdata->{'fields'} }
        ;

        for my $fdata ( @fields ) {
            $table->add_field( %$fdata ) or die $table->error;
            $table->primary_key( $fdata->{'name'} )
                if $fdata->{'is_primary_key'};
        }

        for my $idata ( @{ $tdata->{'indices'} || [] } ) {
            $table->add_index( %$idata ) or die $table->error;
        }

        for my $cdata ( @{ $tdata->{'constraints'} || [] } ) {
            $table->add_constraint( %$cdata ) or die $table->error;
        }
    }

    #
    # Views
    #
    my @views =
        map   { $data->{'views'}{ $_->[1] } }
        sort  { $a->[0] <=> $b->[0] }
        map   { [ $data->{'views'}{ $_ }{'order'}, $_ ] }
        keys %{ $data->{'views'} }
    ;

    for my $vdata ( @views ) {
        $schema->add_view( %$vdata ) or die $schema->error;
    }

    #
    # Triggers
    #
    my @triggers =
        map   { $data->{'triggers'}{ $_->[1] } }
        sort  { $a->[0] <=> $b->[0] }
        map   { [ $data->{'triggers'}{ $_ }{'order'}, $_ ] }
        keys %{ $data->{'triggers'} }
    ;

    for my $tdata ( @triggers ) {
        $schema->add_trigger( %$tdata ) or die $schema->error;
    }

    #
    # Procedures
    #
    my @procedures =
        map   { $data->{'procedures'}{ $_->[1] } }
        sort  { $a->[0] <=> $b->[0] }
        map   { [ $data->{'procedures'}{ $_ }{'order'}, $_ ] }
        keys %{ $data->{'procedures'} }
    ;

    for my $tdata ( @procedures ) {
        $schema->add_procedure( %$tdata ) or die $schema->error;
    }

    if ( my $tr_data = $data->{'translator'} ) {
        $translator->add_drop_table( $tr_data->{'add_drop_table'} );
        $translator->filename( $tr_data->{'filename'} );
        $translator->no_comments( $tr_data->{'no_comments'} );
        $translator->parser_args( $tr_data->{'parser_args'} );
        $translator->producer_args( $tr_data->{'producer_args'} );
        $translator->parser_type( $tr_data->{'parser_type'} );
        $translator->producer_type( $tr_data->{'producer_type'} );
        $translator->show_warnings( $tr_data->{'show_warnings'} );
        $translator->trace( $tr_data->{'trace'} );
    }

    return 1;
}

1;

__END__

=head1 NAME

SQL::Translator::Parser::YAML - Parse a YAML representation of a schema

=head1 SYNOPSIS

    use SQL::Translator;

    my $translator = SQL::Translator->new(parser => "YAML");

=head1 DESCRIPTION

C<SQL::Translator::Parser::YAML> parses a schema serialized with YAML.

=head1 AUTHORS

Darren Chamberlain E<lt>darren@cpan.orgE<gt>,
Ken Y. Clark E<lt>kclark@cpan.orgE<gt>.
