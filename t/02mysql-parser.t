#!/usr/bin/perl
# vim: set ft=perl:
#
# NOTE!!!!
# For now, all this is testing is that Parse::RecDescent does not
# die with an error!  I am not verifying the validity of the data
# returned here, just that the parser actually completed its parsing!
#

use strict;

use Test::More tests => 19;
use SQL::Translator;
use SQL::Translator::Parser::MySQL qw(parse);

{
    my $tr = SQL::Translator->new;
    my $data = q|create table sessions (
        id char(32) not null primary key,
        a_session text
    );|;

    my $val = parse($tr, $data);

    # $val holds the processed data structure.

    # The data structure should have one key:
    is( scalar keys %{$val}, 1, 'Right number of tables' );

    # The data structure should have a single key, named sessions
    ok( defined $val->{'sessions'}, 'Found "sessions" table' );

    # $val->{'sessions'} should have a single index (since we haven't
    # defined an index, but have defined a primary key)
    my $indices = $val->{'sessions'}->{'indices'};
    is( scalar @{$indices || []}, 1, 'Correct index number' );

    is( $indices->[0]->{'type'}, 'primary_key', 'Correct index type' );
    is( $indices->[0]->{'fields'}->[0], 'id', 'Correct index name' );

    # $val->{'sessions'} should have two fields, id and a_sessionn
    my $fields = $val->{'sessions'}->{'fields'};
    is( scalar keys %{$fields}, 2, 'Correct fields number' );

    is( $fields->{'id'}->{'data_type'}, 'char',
        'Correct field type: id (char)' );

    is ( $fields->{'a_session'}->{'data_type'}, 'text',
        'Correct field type: a_session (text)' );

    is( $fields->{'id'}->{'is_primary_key'}, 1, 
        'Correct key identification (id == key)' );

    ok( ! defined $fields->{'a_session'}->{'is_primary_key'}, 
        'Correct key identification (a_session != key)' );

    # Test that the order is being maintained by the internal order
    # data element
    my @order = sort { $fields->{$a}->{'order'}
                                 <=>
                       $fields->{$b}->{'order'}
                     } keys %{$fields};

    ok( $order[0] eq 'id' && $order[1] eq 'a_session', 'Ordering of fields' );
}

{
    my $tr = SQL::Translator->new;
    my $data = parse($tr, 
        q[
            CREATE TABLE check (
              id int(7) unsigned zerofill NOT NULL default '0000000' 
                auto_increment primary key,
              successful date NOT NULL default '0000-00-00',
              unsuccessful date default '0000-00-00',
              i1 int(11) default '0' not null,
              s1 set('a','b','c') default 'b',
              e1 enum('a','b','c') default 'c',
              name varchar(30) default NULL,
              foo_type enum('vk','ck') NOT NULL default 'vk',
              date timestamp,
              time_stamp2 timestamp,
              KEY (i1),
              UNIQUE (date, i1),
              KEY date_idx (date),
              KEY name_idx (name(10))
            ) TYPE=MyISAM PACK_KEYS=1;
        ]
    );
    
    is( scalar keys %$data, 1, 'Right number of tables' );
    ok( defined $data->{'check'}, 'Found "check" table' );

    my $fields = $data->{'check'}{'fields'};
    is( scalar keys %$fields, 10, 'Correct number of fields' );

    is( $fields->{'i1'}{'data_type'}, 'int', 'i1 an int' );
    is( join(',', @{$fields->{'i1'}{'size'}}), '11', 'i1 of size "11"' );

    my @order = sort { 
        $fields->{$a}->{'order'} <=> $fields->{$b}->{'order'}
    } keys %$fields;

    is( $order[3], 'i1', 'Found the "i1" field' );
}

{
    my $tr = SQL::Translator->new;
    my $data = parse($tr, 
        q[
            CREATE TABLE orders (
              order_id                  integer NOT NULL auto_increment,
              member_id                 varchar(255),
              billing_address_id        int,
              shipping_address_id       int,
              credit_card_id            int,
              status                    smallint NOT NULL,
              store_id                  varchar(255) NOT NULL REFERENCES store,
              tax                       decimal(8,2),
              shipping_charge           decimal(8,2),
              price_paid                decimal(8,2),
              PRIMARY KEY (order_id),
              KEY (status),
              KEY (billing_address_id),
              KEY (shipping_address_id),
              KEY (member_id, store_id),
              FOREIGN KEY (status)              REFERENCES order_status(id),
              FOREIGN KEY (billing_address_id)  REFERENCES address(address_id),
              FOREIGN KEY (shipping_address_id) REFERENCES address(address_id)
            ) TYPE=INNODB;
        ]
    ) or die $tr->error;

    is( scalar keys %{$data}, 1, 'Parsed correct number of tables' );
    ok( defined $data->{'orders'}, 'Found "orders" table' );
}
