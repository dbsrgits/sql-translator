#!/usr/bin/perl
# vim: set ft=perl:
#

use strict;

use FindBin '$Bin';
use Test::More 'no_plan';
use SQL::Translator;
use SQL::Translator::Schema::Constants;
use Test::SQL::Translator qw(maybe_plan table_ok);

#BEGIN {
#    maybe_plan(180, "SQL::Translator::Parser::Access");
#    SQL::Translator::Parser::Access->import('parse');
#}

use SQL::Translator::Parser::Access 'parse';

{
    my $tr = SQL::Translator->new;

    my $file = "$Bin/data/access/gdpdm.ddl";
    open FH, "<$file" or die "Can't read '$file': $!\n";
    local $/;
    my $data = <FH>;
    close FH;
    my $val = parse($tr, $data);
    ok( $val, 'Parsed OK' );

    my $schema = $tr->schema;
    is( $schema->is_valid, 1, 'Schema is valid' );
    my @tables = $schema->get_tables;
    is( scalar @tables, 24, 'Right number of tables (24)' );

    my @tblnames = map {$_->name} @tables;
    is_deeply( \@tblnames,
        [qw/div_aa_annotation div_allele div_allele_assay div_annotation_type div_exp_entry div_experiment div_generation div_locality div_locus div_marker div_obs_unit div_obs_unit_sample div_passport div_poly_type div_statistic_type div_stock div_stock_parent div_trait div_trait_uom div_treatment div_treatment_uom div_unit_of_measure qtl_trait_ontology qtl_treatment_ontology/]
    ,"tables");

    table_ok( $schema->get_table("div_aa_annotation"), {
        name => "div_aa_annotation",
        fields => [
        {
            name => "div_aa_annotation_id",
            data_type => "Long Integer",
            size => 4,
        },
        {
            name => "div_annotation_type_id",
            data_type => "Long Integer",
            size => 4,
        },
        {
            name => "div_allele_assay_id",
            data_type => "Long Integer",
            size => 4,
        },
        {
            name => "annotation_value",
            data_type => "Text",
            size => 50,
        },
        ],
    });

    table_ok( $schema->get_table("div_allele"), {
        name => "div_allele",
        fields => [
        {
            name => "div_allele_id",
            data_type => "Long Integer",
            size => 4,
        },
        {
            name => "div_obs_unit_sample_id",
            data_type => "Long Integer",
            size => 4,
        },
        {
            name => "div_allele_assay_id",
            data_type => "Long Integer",
            size => 4,
        },
        {
            name => "allele_num",
            data_type => "Long Integer",
            size => 4,
        },
        {
            name => "quality",
            data_type => "Long Integer",
            size => 4,
        },
        {
            name => "value",
            data_type => "Text",
            size => 50,
        },
        ],
    });
}
