#!/usr/bin/perl
use warnings;
use strict;
use Test::More;
use_ok( "SQL::Translator" );
use_ok( "SQL::Translator::Parser::MySQL" );
use_ok( "SQL::Translator::Producer::SQLite" );

# This test reproduces a bug in SQL::Translator::Producer::SQLite.
#
# When tables are created their names are not added to %global_names, and
# may be duplicated.
#
# SQL::Translator::Producer::SQLite version 1.59.
# compliments of SymKat <symkat@symkat.com>



my $output = SQL::Translator
    ->new( data => do { local $/; <DATA> })
    ->translate( from => 'MySQL', to => 'SQLite' );

sub find_table_names {
    my ( $content ) = @_;
    my @tables;

    for my $line ( split /\n/, $content ) {
        if ($content =~ /CREATE (?:INDEX|UNIQUE|TABLE| ){0,6} ([^\s]+)/gc) {
            push @tables, $1;
        }
    }
    return @tables;
}

sub has_dupes {
    my ( @list ) = @_;
    my %hist;

    for my $elem ( @list ) {
        return 0 if exists $hist{$elem};
        $hist{$elem} = 1;
    }
    return 1;
}

ok ( has_dupes( find_table_names( $output ) ) );

done_testing;

__DATA__
CREATE TABLE `ip_address` (
  `id` int(11) NOT NULL auto_increment,
  `ip_address` varchar(255) NOT NULL,
  `machine_id` int(11) default NULL,
  `primary_machine_id` int(11) default NULL,
  `secondary_machine_id` int(11) default NULL,
  `tertiary_machine_id` int(11) default NULL,
  `protocol` enum('ipv4','ipv6') NOT NULL default 'ipv4',
  `shared` tinyint(1) NOT NULL default '1',
  PRIMARY KEY  (`id`),
  UNIQUE KEY `ip_address` (`ip_address`),
  KEY `machine_id` (`machine_id`),
  KEY `primary_machine_id` (`primary_machine_id`),
  KEY `secondary_machine_id` (`secondary_machine_id`),
  KEY `tertiary_machine_id` (`tertiary_machine_id`),
  CONSTRAINT `ip_address_ibfk_1` FOREIGN KEY (`machine_id`) REFERENCES `machine` (`id`),
  CONSTRAINT `ip_address_ibfk_2` FOREIGN KEY (`primary_machine_id`) REFERENCES `machine` (`id`),
  CONSTRAINT `ip_address_ibfk_3` FOREIGN KEY (`secondary_machine_id`) REFERENCES `machine` (`id`),
  CONSTRAINT `ip_address_ibfk_4` FOREIGN KEY (`tertiary_machine_id`) REFERENCES `machine` (`id`)
);

