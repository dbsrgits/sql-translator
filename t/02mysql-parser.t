#!/usr/bin/perl
# vim: set ft=perl:
#

use strict;

use Test::More;
use SQL::Translator;
use SQL::Translator::Schema::Constants;
use Test::SQL::Translator qw(maybe_plan);

BEGIN {
    maybe_plan(199, "SQL::Translator::Parser::MySQL");
    SQL::Translator::Parser::MySQL->import('parse');
}

{
    my $tr = SQL::Translator->new;
    my $data = q|create table sessions (
        id char(32) not null default '0' primary key,
        a_session text
    );|;

    my $val = parse($tr, $data);

    my $schema = $tr->schema;
    is( $schema->is_valid, 1, 'Schema is valid' );
    my @tables = $schema->get_tables;
    is( scalar @tables, 1, 'Right number of tables (1)' );
    my $table  = shift @tables;
    is( $table->name, 'sessions', 'Found "sessions" table' );

    my @fields = $table->get_fields;
    is( scalar @fields, 2, 'Right number of fields (2)' );
    my $f1 = shift @fields;
    my $f2 = shift @fields;
    is( $f1->name, 'id', 'First field name is "id"' );
    is( $f1->data_type, 'char', 'Type is "char"' );
    is( $f1->size, 32, 'Size is "32"' );
    is( $f1->is_nullable, 0, 'Field cannot be null' );
    is( $f1->default_value, '0', 'Default value is "0"' );
    is( $f1->is_primary_key, 1, 'Field is PK' );

    is( $f2->name, 'a_session', 'Second field name is "a_session"' );
    is( $f2->data_type, 'text', 'Type is "text"' );
    is( $f2->size, 65_535, 'Size is "65,535"' );
    is( $f2->is_nullable, 1, 'Field can be null' );
    is( $f2->default_value, undef, 'Default value is undefined' );
    is( $f2->is_primary_key, 0, 'Field is not PK' );

    my @indices = $table->get_indices;
    is( scalar @indices, 0, 'Right number of indices (0)' );

    my @constraints = $table->get_constraints;
    is( scalar @constraints, 1, 'Right number of constraints (1)' );
    my $c = shift @constraints;
    is( $c->type, PRIMARY_KEY, 'Constraint is a PK' );
    is( join(',', $c->fields), 'id', 'Constraint is on "id"' );
}

{
    my $tr = SQL::Translator->new;
    my $data = parse($tr, 
        q[
            CREATE TABLE check (
              check_id int(7) unsigned zerofill NOT NULL default '0000000' 
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
    
    my $schema = $tr->schema;
    is( $schema->is_valid, 1, 'Schema is valid' );
    my @tables = $schema->get_tables;
    is( scalar @tables, 1, 'Right number of tables (1)' );
    my $table  = shift @tables;
    is( $table->name, 'check', 'Found "check" table' );

    my @fields = $table->get_fields;
    is( scalar @fields, 10, 'Right number of fields (10)' );
    my $f1 = shift @fields;
    is( $f1->name, 'check_id', 'First field name is "check_id"' );
    is( $f1->data_type, 'int', 'Type is "int"' );
    is( $f1->size, 7, 'Size is "7"' );
    is( $f1->is_nullable, 0, 'Field cannot be null' );
    is( $f1->default_value, '0000000', 'Default value is "0000000"' );
    is( $f1->is_primary_key, 1, 'Field is PK' );
    is( $f1->is_auto_increment, 1, 'Field is auto inc' );
    my %extra = $f1->extra;
    ok( defined $extra{'unsigned'}, 'Field is unsigned' );
    ok( defined $extra{'zerofill'}, 'Field is zerofill' );

    my $f2 = shift @fields;
    is( $f2->name, 'successful', 'Second field name is "successful"' );
    is( $f2->data_type, 'date', 'Type is "date"' );
    is( $f2->size, 0, 'Size is "0"' );
    is( $f2->is_nullable, 0, 'Field cannot be null' );
    is( $f2->default_value, '0000-00-00', 'Default value is "0000-00-00"' );
    is( $f2->is_primary_key, 0, 'Field is not PK' );

    my $f3 = shift @fields;
    is( $f3->name, 'unsuccessful', 'Third field name is "unsuccessful"' );
    is( $f3->data_type, 'date', 'Type is "date"' );
    is( $f3->size, 0, 'Size is "0"' );
    is( $f3->is_nullable, 1, 'Field can be null' );
    is( $f3->default_value, '0000-00-00', 'Default value is "0000-00-00"' );
    is( $f3->is_primary_key, 0, 'Field is not PK' );

    my $f4 = shift @fields;
    is( $f4->name, 'i1', 'Fourth field name is "i1"' );
    is( $f4->data_type, 'int', 'Type is "int"' );
    is( $f4->size, 11, 'Size is "11"' );
    is( $f4->is_nullable, 0, 'Field cannot be null' );
    is( $f4->default_value, '0', 'Default value is "0"' );
    is( $f4->is_primary_key, 0, 'Field is not PK' );

    my $f5 = shift @fields;
    is( $f5->name, 's1', 'Fifth field name is "s1"' );
    is( $f5->data_type, 'set', 'Type is "set"' );
    is( $f5->size, 1, 'Size is "1"' );
    is( $f5->is_nullable, 1, 'Field can be null' );
    is( $f5->default_value, 'b', 'Default value is "b"' );
    is( $f5->is_primary_key, 0, 'Field is not PK' );
    my %f5extra = $f5->extra;
    is( join(',', @{ $f5extra{'list'} || [] }), 'a,b,c', 'List is "a,b,c"' );

    my $f6 = shift @fields;
    is( $f6->name, 'e1', 'Sixth field name is "e1"' );
    is( $f6->data_type, 'enum', 'Type is "enum"' );
    is( $f6->size, 1, 'Size is "1"' );
    is( $f6->is_nullable, 1, 'Field can be null' );
    is( $f6->default_value, 'c', 'Default value is "c"' );
    is( $f6->is_primary_key, 0, 'Field is not PK' );
    my %f6extra = $f6->extra;
    is( join(',', @{ $f6extra{'list'} || [] }), 'a,b,c', 'List is "a,b,c"' );

    my $f7 = shift @fields;
    is( $f7->name, 'name', 'Seventh field name is "name"' );
    is( $f7->data_type, 'varchar', 'Type is "varchar"' );
    is( $f7->size, 30, 'Size is "30"' );
    is( $f7->is_nullable, 1, 'Field can be null' );
    is( $f7->default_value, 'NULL', 'Default value is "NULL"' );
    is( $f7->is_primary_key, 0, 'Field is not PK' );

    my $f8 = shift @fields;
    is( $f8->name, 'foo_type', 'Eighth field name is "foo_type"' );
    is( $f8->data_type, 'enum', 'Type is "enum"' );
    is( $f8->size, 2, 'Size is "2"' );
    is( $f8->is_nullable, 0, 'Field cannot be null' );
    is( $f8->default_value, 'vk', 'Default value is "vk"' );
    is( $f8->is_primary_key, 0, 'Field is not PK' );
    my %f8extra = $f8->extra;
    is( join(',', @{ $f8extra{'list'} || [] }), 'vk,ck', 'List is "vk,ck"' );

    my $f9 = shift @fields;
    is( $f9->name, 'date', 'Ninth field name is "date"' );
    is( $f9->data_type, 'timestamp', 'Type is "timestamp"' );
    is( $f9->size, 0, 'Size is "0"' );
    is( $f9->is_nullable, 1, 'Field can be null' );
    is( $f9->default_value, undef, 'Default value is undefined' );
    is( $f9->is_primary_key, 0, 'Field is not PK' );

    my $f10 = shift @fields;
    is( $f10->name, 'time_stamp2', 'Tenth field name is "time_stamp2"' );
    is( $f10->data_type, 'timestamp', 'Type is "timestamp"' );
    is( $f10->size, 0, 'Size is "0"' );
    is( $f10->is_nullable, 1, 'Field can be null' );
    is( $f10->default_value, undef, 'Default value is undefined' );
    is( $f10->is_primary_key, 0, 'Field is not PK' );

    my @indices = $table->get_indices;
    is( scalar @indices, 3, 'Right number of indices (3)' );

    my $i1 = shift @indices;
    is( $i1->name, '', 'No name on index' );
    is( $i1->type, NORMAL, 'Normal index' );
    is( join(',', $i1->fields ), 'i1', 'Index is on field "i1"' );

    my $i2 = shift @indices;
    is( $i2->name, 'date_idx', 'Name is "date_idx"' );
    is( $i2->type, NORMAL, 'Normal index' );
    is( join(',', $i2->fields ), 'date', 'Index is on field "date"' );

    my $i3 = shift @indices;
    is( $i3->name, 'name_idx', 'Name is "name_idx"' );
    is( $i3->type, NORMAL, 'Normal index' );
    is( join(',', $i3->fields ), 'name(10)', 'Index is on field "name(10)"' );

    my @constraints = $table->get_constraints;
    is( scalar @constraints, 2, 'Right number of constraints (2)' );

    my $c1 = shift @constraints;
    is( $c1->type, PRIMARY_KEY, 'Constraint is a PK' );
    is( join(',', $c1->fields), 'check_id', 'Constraint is on "check_id"' );

    my $c2 = shift @constraints;
    is( $c2->type, UNIQUE, 'Constraint is UNIQUE' );
    is( join(',', $c2->fields), 'date,i1', 'Constraint is on "date, i1"' );
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
              FOREIGN KEY (status)              REFERENCES order_status(id) MATCH FULL ON DELETE CASCADE ON UPDATE CASCADE,
              FOREIGN KEY (billing_address_id)  REFERENCES address(address_id),
              FOREIGN KEY (shipping_address_id) REFERENCES address(address_id)
            ) TYPE=INNODB;

            CREATE TABLE address (
              address_id                int NOT NULL auto_increment,
              recipient                 varchar(255) NOT NULL,
              address1                  varchar(255) NOT NULL,
              address2                  varchar(255),
              city                      varchar(255) NOT NULL,
              state                     varchar(255) NOT NULL,
              postal_code               varchar(255) NOT NULL,
              phone                     varchar(255),
              PRIMARY KEY (address_id)
            ) TYPE=INNODB;
        ]
    ) or die $tr->error;

    my $schema = $tr->schema;
    is( $schema->is_valid, 1, 'Schema is valid' );
    my @tables = $schema->get_tables;
    is( scalar @tables, 2, 'Right number of tables (2)' );

    my $t1  = shift @tables;
    is( $t1->name, 'orders', 'Found "orders" table' );

    my @fields = $t1->get_fields;
    is( scalar @fields, 10, 'Right number of fields (10)' );

    my $f1 = shift @fields;
    is( $f1->name, 'order_id', 'First field name is "order_id"' );
    is( $f1->data_type, 'int', 'Type is "int"' );
    is( $f1->size, 11, 'Size is "11"' );
    is( $f1->is_nullable, 0, 'Field cannot be null' );
    is( $f1->default_value, undef, 'Default value is undefined' );
    is( $f1->is_primary_key, 1, 'Field is PK' );
    is( $f1->is_auto_increment, 1, 'Field is auto inc' );

    my $f2 = shift @fields;
    is( $f2->name, 'member_id', 'Second field name is "member_id"' );
    is( $f2->data_type, 'varchar', 'Type is "varchar"' );
    is( $f2->size, 255, 'Size is "255"' );
    is( $f2->is_nullable, 1, 'Field can be null' );
    is( $f2->default_value, undef, 'Default value is undefined' );

    my $f3 = shift @fields;
    is( $f3->name, 'billing_address_id', 
        'Third field name is "billing_address_id"' );
    is( $f3->data_type, 'int', 'Type is "int"' );
    is( $f3->size, 11, 'Size is "11"' );

    my $f4 = shift @fields;
    is( $f4->name, 'shipping_address_id', 
        'Fourth field name is "shipping_address_id"' );
    is( $f4->data_type, 'int', 'Type is "int"' );
    is( $f4->size, 11, 'Size is "11"' );

    my $f5 = shift @fields;
    is( $f5->name, 'credit_card_id', 'Fifth field name is "credit_card_id"' );
    is( $f5->data_type, 'int', 'Type is "int"' );
    is( $f5->size, 11, 'Size is "11"' );

    my $f6 = shift @fields;
    is( $f6->name, 'status', 'Sixth field name is "status"' );
    is( $f6->data_type, 'smallint', 'Type is "smallint"' );
    is( $f6->size, 6, 'Size is "6"' );
    is( $f6->is_nullable, 0, 'Field cannot be null' );

    my $f7 = shift @fields;
    is( $f7->name, 'store_id', 'Seventh field name is "store_id"' );
    is( $f7->data_type, 'varchar', 'Type is "varchar"' );
    is( $f7->size, 255, 'Size is "255"' );
    is( $f7->is_nullable, 0, 'Field cannot be null' );
    is( $f7->is_foreign_key, 1, 'Field is a FK' );
    my $fk_ref = $f7->foreign_key_reference;
    isa_ok( $fk_ref, 'SQL::Translator::Schema::Constraint', 'FK' );
    is( $fk_ref->reference_table, 'store', 'FK is to "store" table' );

    my $f8 = shift @fields;
    is( $f8->name, 'tax', 'Eighth field name is "tax"' );
    is( $f8->data_type, 'decimal', 'Type is "decimal"' );
    is( $f8->size, '8,2', 'Size is "8,2"' );

    my $f9 = shift @fields;
    is( $f9->name, 'shipping_charge', 'Ninth field name is "shipping_charge"' );
    is( $f9->data_type, 'decimal', 'Type is "decimal"' );
    is( $f9->size, '8,2', 'Size is "8,2"' );

    my $f10 = shift @fields;
    is( $f10->name, 'price_paid', 'Tenth field name is "price_paid"' );
    is( $f10->data_type, 'decimal', 'Type is "decimal"' );
    is( $f10->size, '8,2', 'Size is "8,2"' );

    my @indices = $t1->get_indices;
    is( scalar @indices, 4, 'Right number of indices (4)' );

    my $i1 = shift @indices;
    is( $i1->type, NORMAL, 'First index is normal' );
    is( join(',', $i1->fields), 'status', 'Index is on "status"' );

    my $i2 = shift @indices;
    is( $i2->type, NORMAL, 'Second index is normal' );
    is( join(',', $i2->fields), 'billing_address_id', 
        'Index is on "billing_address_id"' );

    my $i3 = shift @indices;
    is( $i3->type, NORMAL, 'Third index is normal' );
    is( join(',', $i3->fields), 'shipping_address_id', 
        'Index is on "shipping_address_id"' );

    my $i4 = shift @indices;
    is( $i4->type, NORMAL, 'Third index is normal' );
    is( join(',', $i4->fields), 'member_id,store_id', 
        'Index is on "member_id,store_id"' );

    my @constraints = $t1->get_constraints;
    is( scalar @constraints, 5, 'Right number of constraints (5)' );

    my $c1 = shift @constraints;
    is( $c1->type, PRIMARY_KEY, 'Constraint is a PK' );
    is( join(',', $c1->fields), 'order_id', 'Constraint is on "order_id"' );

    my $c2 = shift @constraints;
    is( $c2->type, FOREIGN_KEY, 'Constraint is a FK' );
    is( join(',', $c2->fields), 'status', 'Constraint is on "status"' );
    is( $c2->reference_table, 'order_status', 'To table "order_status"' );
    is( join(',', $c2->reference_fields), 'id', 'To field "id"' );

    my $c3 = shift @constraints;
    is( $c3->type, FOREIGN_KEY, 'Constraint is a FK' );
    is( join(',', $c3->fields), 'billing_address_id', 
        'Constraint is on "billing_address_id"' );
    is( $c3->reference_table, 'address', 'To table "address"' );
    is( join(',', $c3->reference_fields), 'address_id', 
        'To field "address_id"' );

    my $c4 = shift @constraints;
    is( $c4->type, FOREIGN_KEY, 'Constraint is a FK' );
    is( join(',', $c4->fields), 'shipping_address_id', 
        'Constraint is on "shipping_address_id"' );
    is( $c4->reference_table, 'address', 'To table "address"' );
    is( join(',', $c4->reference_fields), 'address_id', 
        'To field "address_id"' );

    my $c5 = shift @constraints;
    is( $c5->type, FOREIGN_KEY, 'Constraint is a FK' );
    is( join(',', $c5->fields), 'store_id', 'Constraint is on "store_id"' );
    is( $c5->reference_table, 'store', 'To table "store"' );
    is( join(',', map { $_ || '' } $c5->reference_fields), '', 
        'No reference fields defined' );

    my $t2  = shift @tables;
    is( $t2->name, 'address', 'Found "address" table' );

    my @t2_fields = $t2->get_fields;
    is( scalar @t2_fields, 8, 'Right number of fields (8)' );
}

# djh Tests for:
#    USE database ;
#    ALTER TABLE ADD FOREIGN KEY
#    trailing comma on last create definition
#    Ignoring INSERT statements
#
{
    my $tr = SQL::Translator->new;
    my $data = parse($tr, 
        q[
            USE database_name;

            CREATE TABLE one (
              id                     integer NOT NULL auto_increment,
              two_id                 integer NOT NULL auto_increment,
              some_data              text,
              PRIMARY KEY (id),
              INDEX (two_id),
            ) TYPE=INNODB;

            CREATE TABLE two (
              id                     int NOT NULL auto_increment,
              one_id                 int NOT NULL auto_increment,
              some_data              text,
              PRIMARY KEY (id),
              INDEX (one_id),
              FOREIGN KEY (one_id) REFERENCES one (id),
            ) TYPE=INNODB;

            ALTER TABLE one ADD FOREIGN KEY (two_id) REFERENCES two (id);

            INSERT absolutely *#! any old $£ ? rubbish ;
        ]
    ) or die $tr->error;

    my $schema = $tr->schema;
    is( $schema->is_valid, 1, 'Schema is valid' );
    my $db_name = $schema->name;
    is( $db_name, 'database_name', 'Database name extracted from USE' );
    my @tables = $schema->get_tables;
    is( scalar @tables, 2, 'Right number of tables (2)' );
    my $table1 = shift @tables;
    is( $table1->name, 'one', 'Found "one" table' );
    my $table2 = shift @tables;
    is( $table2->name, 'two', 'Found "two" table' );

    my @constraints = $table1->get_constraints;
    is(scalar @constraints, 2, 'Right number of constraints (2) on table one');

    my $t1c1 = shift @constraints;
    is( $t1c1->type, PRIMARY_KEY, 'Constraint is a PK' );
    is( join(',', $t1c1->fields), 'id', 'Constraint is on "id"' );

    my $t1c2 = shift @constraints;
    is( $t1c2->type, FOREIGN_KEY, 'Constraint is a FK' );
    is( join(',', $t1c2->fields), 'two_id', 'Constraint is on "two_id"' );
    is( $t1c2->reference_table, 'two', 'To table "two"' );
    is( join(',', $t1c2->reference_fields), 'id', 'To field "id"' );

    @constraints = $table2->get_constraints;
    is(scalar @constraints, 2, 'Right number of constraints (2) on table two');

    my $t2c1 = shift @constraints;
    is( $t2c1->type, PRIMARY_KEY, 'Constraint is a PK' );
    is( join(',', $t2c1->fields), 'id', 'Constraint is on "id"' );

    my $t2c2 = shift @constraints;
    is( $t2c2->type, FOREIGN_KEY, 'Constraint is a FK' );
    is( join(',', $t2c2->fields), 'one_id', 'Constraint is on "one_id"' );
    is( $t2c2->reference_table, 'one', 'To table "one"' );
    is( join(',', $t2c2->reference_fields), 'id', 'To field "id"' );
}

