package SQL::Translator::Parser::DB2;
use Data::Dumper;
use SQL::Translator::Parser::DB2::Grammar;
use Exporter;
use base qw(Exporter);

@EXPORT_OK = qw(parse);

# Enable warnings within the Parse::RecDescent module.
$::RD_ERRORS = 1; # Make sure the parser dies when it encounters an error
$::RD_WARN   = 1; # Enable warnings. This will warn on unused rules &c.
$::RD_HINT   = 1; # Give out hints to help fix problems.

# -------------------------------------------------------------------
sub parse {
    my ( $translator, $data ) = @_;
    my $parser = SQL::Translator::Parser::DB2::Grammar->new();

    local $::RD_TRACE  = $translator->trace ? 1 : undef;
    local $DEBUG       = $translator->debug;

    unless (defined $parser) {
        return $translator->error("Error instantiating Parse::RecDescent ".
            "instance: Bad grammer");
    }

    my $result = $parser->startrule($data);
    return $translator->error( "Parse failed." ) unless defined $result;
    warn Dumper( $result ) if $DEBUG;

    my $schema = $translator->schema;
    my @tables = 
        map   { $_->[1] }
        sort  { $a->[0] <=> $b->[0] } 
        map   { [ $result->{'tables'}{ $_ }->{'order'}, $_ ] }
        keys %{ $result->{'tables'} };

    for my $table_name ( @tables ) {
        my $tdata =  $result->{'tables'}{ $table_name };
        my $table =  $schema->add_table( 
            name  => $tdata->{'name'},
        ) or die $schema->error;

        $table->comments( $tdata->{'comments'} );

        for my $fdata ( @{ $tdata->{'fields'} } ) {
            my $field = $table->add_field(
                name              => $fdata->{'name'},
                data_type         => $fdata->{'data_type'},
                size              => $fdata->{'size'},
                default_value     => $fdata->{'default'},
                is_auto_increment => $fdata->{'is_auto_inc'},
                is_nullable       => $fdata->{'is_nullable'},
                comments          => $fdata->{'comments'},
            ) or die $table->error;

            $table->primary_key( $field->name ) if $fdata->{'is_primary_key'};

            for my $cdata ( @{ $fdata->{'constraints'} } ) {
                next unless $cdata->{'type'} eq 'foreign_key';
                $cdata->{'fields'} ||= [ $field->name ];
                push @{ $tdata->{'constraints'} }, $cdata;
            }
        }

        for my $idata ( @{ $tdata->{'indices'} || [] } ) {
            my $index  =  $table->add_index(
                name   => $idata->{'name'},
                type   => uc $idata->{'type'},
                fields => $idata->{'fields'},
            ) or die $table->error;
        }

        for my $cdata ( @{ $tdata->{'constraints'} || [] } ) {
            my $constraint       =  $table->add_constraint(
                name             => $cdata->{'name'},
                type             => $cdata->{'type'},
                fields           => $cdata->{'fields'},
                reference_table  => $cdata->{'reference_table'},
                reference_fields => $cdata->{'reference_fields'},
                match_type       => $cdata->{'match_type'} || '',
                on_delete        => $cdata->{'on_delete'} || $cdata->{'on_delete_do'},
                on_update        => $cdata->{'on_update'} || $cdata->{'on_update_do'},
            ) or die $table->error;
        }
    }

    for my $def ( @{ $result->{'views'} || [] } ) {
        my $view = $schema->add_view(
            name => $def->{'name'},
            sql  => $def->{'sql'},
        );
    }

    for my $def ( @{ $result->{'triggers'} || [] } ) {
        my $trig                = $schema->add_trigger(
            name                => $def->{'name'},
            perform_action_when => $def->{'when'},
            database_event      => $def->{'db_event'},
            action              => $def->{'action'},
            fields              => $def->{'fields'},
            on_table            => $def->{'table'}
                                                       );
        $trig->extra( reference => $def->{'reference'},
                      condition => $def->{'condition'},
                      granularity => $def->{'granularity'} );
    }

    return 1;
}

1;
