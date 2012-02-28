#!/usr/bin/perl
# vim: set ft=perl:
#

use strict;

use Test::More;
use SQL::Translator;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw//;
use Test::SQL::Translator qw(maybe_plan);
use FindBin qw/$Bin/;

BEGIN {
    maybe_plan(346, "SQL::Translator::Parser::MySQL");
    SQL::Translator::Parser::MySQL->import('parse');
}

{
    my $tr = SQL::Translator->new;
    my $data = q|create table "sessions" (
        id char(32) not null default '0' primary key,
        a_session text,
        ssn varchar(12) unique key,
        age int key,
        fulltext key `session_fulltext` (a_session)
    );|;

    my $val = parse($tr, $data);
    my $schema = $tr->schema;
    is( $schema->is_valid, 1, 'Schema is valid' );
    my @tables = $schema->get_tables;
    is( scalar @tables, 1, 'Right number of tables (1)' );
    my $table  = shift @tables;
    is( $table->name, 'sessions', 'Found "sessions" table' );

    my @fields = $table->get_fields;
    is( scalar @fields, 4, 'Right number of fields (4)' );
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
    is( scalar @indices, 2, 'Right number of indices (2)' );
    my $i = pop @indices;
    is( $i->type, 'FULLTEXT', 'Found fulltext' );

    my @constraints = $table->get_constraints;
    is( scalar @constraints, 2, 'Right number of constraints (2)' );
    my $c = shift @constraints;
    is( $c->type, PRIMARY_KEY, 'Constraint is a PK' );
    is( join(',', $c->fields), 'id', 'Constraint is on "id"' );
    my $c2 = shift @constraints;
    is( $c2->type, UNIQUE, 'Constraint is UNIQUE' );
    is( join(',', $c2->fields), 'ssn', 'Constraint is on "ssn"' );
}

{
    my $tr = SQL::Translator->new;
    my $data = parse($tr,
        q[
            CREATE TABLE `check` (
              check_id int(7) unsigned zerofill NOT NULL default '0000000'
                auto_increment primary key,
              successful date NOT NULL default '0000-00-00',
              unsuccessful date default '0000-00-00',
              i1 int(11) default '0' not null,
              s1 set('a','b','c') default 'b',
              e1 enum('a','b','c') default "c",
              name varchar(30) default NULL,
              foo_type enum('vk','ck') NOT NULL default 'vk',
              date timestamp,
              time_stamp2 timestamp,
              foo_enabled bit(1) default b'0',
              bar_enabled bit(1) default b"1",
              long_foo_enabled bit(10) default b'1010101',
              KEY (i1),
              UNIQUE (date, i1) USING BTREE,
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
    is( scalar @fields, 13, 'Right number of fields (13)' );
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

    my $f11 = shift @fields;
    is( $f11->name, 'foo_enabled', 'Eleventh field name is "foo_enabled"' );
    is( $f11->data_type, 'bit', 'Type is "bit"' );
    is( $f11->size, 1, 'Size is "1"' );
    is( $f11->is_nullable, 1, 'Field can be null' );
    is( $f11->default_value, '0', 'Default value is 0' );
    is( $f11->is_primary_key, 0, 'Field is not PK' );

    my $f12 = shift @fields;
    is( $f12->name, 'bar_enabled', 'Twelveth field name is "bar_enabled"' );
    is( $f12->data_type, 'bit', 'Type is "bit"' );
    is( $f12->size, 1, 'Size is "1"' );
    is( $f12->is_nullable, 1, 'Field can be null' );
    is( $f12->default_value, '1', 'Default value is 1' );
    is( $f12->is_primary_key, 0, 'Field is not PK' );

    my $f13 = shift @fields;
    is( $f13->name, 'long_foo_enabled', 'Thirteenth field name is "long_foo_enabled"' );
    is( $f13->data_type, 'bit', 'Type is "bit"' );
    is( $f13->size, 10, 'Size is "10"' );
    is( $f13->is_nullable, 1, 'Field can be null' );
    is( $f13->default_value, '1010101', 'Default value is 1010101' );
    is( $f13->is_primary_key, 0, 'Field is not PK' );

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
              member_id                 varchar(255) comment 'fk to member',
              billing_address_id        int,
              shipping_address_id       int,
              credit_card_id            int,
              status                    smallint NOT NULL,
              store_id                  varchar(255) NOT NULL REFERENCES store,
              tax                       decimal(8,2),
              shipping_charge           decimal(8,2),
              price_paid                decimal(8,2),
              PRIMARY KEY (order_id) USING BTREE,
              KEY (status) USING BTREE,
              KEY USING BTREE (billing_address_id),
              KEY (shipping_address_id),
              KEY (member_id, store_id),
              FOREIGN KEY (status)              REFERENCES order_status(id) MATCH FULL ON DELETE CASCADE ON UPDATE CASCADE,
              FOREIGN KEY (billing_address_id)  REFERENCES address(address_id),
              FOREIGN KEY (shipping_address_id) REFERENCES address(address_id)
            ) TYPE=INNODB COMMENT = 'orders table comment';

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
    is( $t1->comments, 'orders table comment', 'Table comment OK' );

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
    is( $f2->comments, 'fk to member', 'Field comment OK' );
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

            INSERT absolutely *#! any old $£ ? rubbish, even "quoted; semi-what""sits";
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

# cch Tests for:
#    comments like: /*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
#    char fields with character set and collate qualifiers
#    timestamp fields with on update qualifier
#    charset table option
#
{
    my $tr = SQL::Translator->new(parser_args => {mysql_parser_version => 50013});
    my $data = parse($tr,
        q[
            DELIMITER ;;
            /*!40101 SET SQL_MODE=@OLD_SQL_MODE */;;
            /*!50003 CREATE */ /*!50017 DEFINER=`cmdomain`@`localhost` */
            /*!50003 TRIGGER `acl_entry_insert` BEFORE INSERT ON `acl_entry`
                FOR EACH ROW SET NEW.dateCreated = CONVERT_TZ(SYSDATE(),'SYSTEM','+0:00'),
                NEW.dateModified = CONVERT_TZ(SYSDATE(),'SYSTEM','+0:00') */;;

            DELIMITER ;
            CREATE TABLE one (
              `op` varchar(255) character set latin1 collate latin1_bin default NULL,
              `last_modified` timestamp NOT NULL default Current_Timestamp on update CURRENT_TIMESTAMP,
              `created_at` datetime NOT NULL Default CURRENT_TIMESTAMP(),
            ) TYPE=INNODB DEFAULT CHARSET=latin1;

            /*!50001 CREATE ALGORITHM=UNDEFINED */
            /*!50013 DEFINER=`cmdomain`@`localhost` SQL SECURITY DEFINER */
            /*!50014 DEFINER=`BOGUS` */
            /*! VIEW `vs_asset` AS
                select `a`.`asset_id` AS `asset_id`,`a`.`fq_name` AS `fq_name`,
                `cfgmgmt_mig`.`ap_extract_folder`(`a`.`fq_name`) AS `folder_name`,
                `cfgmgmt_mig`.`ap_extract_asset`(`a`.`fq_name`) AS `asset_name`,
                `a`.`annotation` AS `annotation`,`a`.`asset_type` AS `asset_type`,
                `a`.`foreign_asset_id` AS `foreign_asset_id`,
                `a`.`foreign_asset_id2` AS `foreign_asset_id2`,`a`.`dateCreated` AS `date_created`,
                `a`.`dateModified` AS `date_modified`,`a`.`container_id` AS `container_id`,
                `a`.`creator_id` AS `creator_id`,`a`.`modifier_id` AS `modifier_id`,
                `m`.`user_id` AS `user_access`
                from (`asset` `a` join `M_ACCESS_CONTROL` `m` on((`a`.`acl_id` = `m`.`acl_id`))) */;
            DELIMITER ;;
            /*!50001 CREATE */
            /*! VIEW `vs_asset2` AS
                select `a`.`asset_id` AS `asset_id`,`a`.`fq_name` AS `fq_name`,
                `cfgmgmt_mig`.`ap_extract_folder`(`a`.`fq_name`) AS `folder_name`,
                `cfgmgmt_mig`.`ap_extract_asset`(`a`.`fq_name`) AS `asset_name`,
                `a`.`annotation` AS `annotation`,`a`.`asset_type` AS `asset_type`,
                `a`.`foreign_asset_id` AS `foreign_asset_id`,
                `a`.`foreign_asset_id2` AS `foreign_asset_id2`,`a`.`dateCreated` AS `date_created`,
                `a`.`dateModified` AS `date_modified`,`a`.`container_id` AS `container_id`,
                `a`.`creator_id` AS `creator_id`,`a`.`modifier_id` AS `modifier_id`,
                `m`.`user_id` AS `user_access`
                from (`asset` `a` join `M_ACCESS_CONTROL` `m` on((`a`.`acl_id` = `m`.`acl_id`))) */;
            DELIMITER ;;
            /*!50001 CREATE OR REPLACE */
            /*! VIEW `vs_asset3` AS
                select `a`.`asset_id` AS `asset_id`,`a`.`fq_name` AS `fq_name`,
                `cfgmgmt_mig`.`ap_extract_folder`(`a`.`fq_name`) AS `folder_name`,
                `cfgmgmt_mig`.`ap_extract_asset`(`a`.`fq_name`) AS `asset_name`,
                `a`.`annotation` AS `annotation`,`a`.`asset_type` AS `asset_type`,
                `a`.`foreign_asset_id` AS `foreign_asset_id`,
                `a`.`foreign_asset_id2` AS `foreign_asset_id2`,`a`.`dateCreated` AS `date_created`,
                `a`.`dateModified` AS `date_modified`,`a`.`container_id` AS `container_id`,
                `a`.`creator_id` AS `creator_id`,`a`.`modifier_id` AS `modifier_id`,
                `m`.`user_id` AS `user_access`
                from (`asset` `a` join `M_ACCESS_CONTROL` `m` on((`a`.`acl_id` = `m`.`acl_id`))) */;
            DELIMITER ;;
            /*!50003 CREATE*/ /*!50020 DEFINER=`cmdomain`@`localhost`*/ /*!50003 FUNCTION `ap_from_millitime_nullable`( millis_since_1970 BIGINT ) RETURNS timestamp
                DETERMINISTIC
                BEGIN
                    DECLARE rval TIMESTAMP;
                    IF ( millis_since_1970 = 0 )
                    THEN
                        SET rval = NULL;
                    ELSE
                        SET rval = FROM_UNIXTIME( millis_since_1970 / 1000 );
                    END IF;
                    RETURN rval;
                END */;;
            /*!50003 CREATE*/ /*!50020 DEFINER=`cmdomain`@`localhost`*/ /*!50003 PROCEDURE `sp_update_security_acl`(IN t_acl_id INTEGER)
                BEGIN
                    DECLARE hasMoreRows BOOL DEFAULT TRUE;
                    DECLARE t_group_id INT;
                    DECLARE t_user_id INT ;
                    DECLARE t_user_name VARCHAR (512) ;
                    DECLARE t_message VARCHAR (512) ;

                    DROP TABLE IF EXISTS group_acl;
                    DROP TABLE IF EXISTS user_group;
                    DELETE FROM M_ACCESS_CONTROL WHERE acl_id = t_acl_id;

                    CREATE TEMPORARY TABLE group_acl SELECT DISTINCT p.id group_id, d.acl_id acl_id
                        FROM  asset d, acl_entry e, alterpoint_principal p
                        WHERE d.acl_id = e.acl
                        AND p.id = e.principal AND d.acl_id = t_acl_id;

                    CREATE TEMPORARY TABLE user_group  SELECT a.id user_id, a.name user_name, c.id group_id
                        FROM alterpoint_principal a, groups_for_user b, alterpoint_principal c
                        WHERE a.id = b.user_ref AND b.elt = c.id;

                    INSERT INTO M_ACCESS_CONTROL SELECT DISTINCT group_acl.group_id, group_acl.acl_id, user_group.user_id, user_group.user_name
                        FROM group_acl, user_group
                        WHERE group_acl.group_id = user_group.group_id ;
                END */;;
        ]
    ) or die $tr->error;

    my $schema = $tr->schema;
    is( $schema->is_valid, 1, 'Schema is valid' );
    my @tables = $schema->get_tables;
    is( scalar @tables, 1, 'Right number of tables (1)' );
    my $table1 = shift @tables;
    is( $table1->name, 'one', 'Found "one" table' );

    my @fields = $table1->get_fields;
    is(scalar @fields, 3, 'Right number of fields (3) on table one');
    my $tableTypeFound = 0;
    my $charsetFound = 0;
    for my $t1_option_ref ( $table1->options ) {
        my($key, $value) = %{$t1_option_ref};
        if ( $key eq 'TYPE' ) {
            is($value, 'INNODB', 'Table has right table type option' );
            $tableTypeFound = 1;
        } elsif ( $key eq 'CHARACTER SET' ) {
            is($value, 'latin1', 'Table has right character set option' );
            $charsetFound = 1;
        }
    }
    fail('Table did not have a type option') unless $tableTypeFound;
    fail('Table did not have a character set option') unless $charsetFound;

    my $t1f1 = shift @fields;
    is( $t1f1->data_type, 'varchar', 'Field is a varchar' );
    is( $t1f1->size, 255, 'Field is right size' );
    is( $t1f1->extra('character set'), 'latin1', 'Field has right character set qualifier' );
    is( $t1f1->extra('collate'), 'latin1_bin', 'Field has right collate qualifier' );
    is( $t1f1->default_value, 'NULL', 'Field has right default value' );

    my $t1f2 = shift @fields;
    is( $t1f2->data_type, 'timestamp', 'Field is a timestamp' );
    ok( !$t1f2->is_nullable, 'Field is not nullable' );
    is_deeply(
      $t1f2->default_value,
      \'CURRENT_TIMESTAMP',
      'Field has right default value'
    );
    is_deeply( $t1f2->extra('on update'), \'CURRENT_TIMESTAMP', 'Field has right on update qualifier' );

    my $t1f3 = shift @fields;
    is( $t1f3->data_type, 'datetime', 'Field is a datetime' );
    ok( !$t1f3->is_nullable, 'Field is not nullable' );
    is_deeply(
      $t1f3->default_value,
      \'CURRENT_TIMESTAMP',
      'Field has right default value'
    );

    my @views = $schema->get_views;
    is( scalar @views, 3, 'Right number of views (3)' );

    my ($view1, $view2, $view3) = @views;
    is( $view1->name, 'vs_asset', 'Found "vs_asset" view' );
    is( $view2->name, 'vs_asset2', 'Found "vs_asset2" view' );
    is( $view3->name, 'vs_asset3', 'Found "vs_asset3" view' );
    like($view1->sql, qr/vs_asset/, "Detected view vs_asset");

    # KYC - commenting this out as I don't understand why this string
    # should /not/ be detected when it is in the SQL - 2/28/12
    # like($view1->sql, qr/cfgmgmt_mig/, "Did not detect cfgmgmt_mig");

    is( join(',', $view1->fields),
        join(',', qw[ asset_id fq_name folder_name asset_name annotation
            asset_type foreign_asset_id foreign_asset_id2 date_created
            date_modified container_id creator_id modifier_id user_access
        ] ),
        'First view has correct fields'
    );

    my @options = $view1->options;

    is_deeply(
      \@options,
      [
        'ALGORITHM=UNDEFINED',
        'DEFINER=`cmdomain`@`localhost`',
        'SQL SECURITY DEFINER',
      ],
      'Only version 50013 options parsed',
    );

    my @procs = $schema->get_procedures;
    is( scalar @procs, 2, 'Right number of procedures (2)' );
    my $proc1 = shift @procs;
    is( $proc1->name, 'ap_from_millitime_nullable', 'Found "ap_from_millitime_nullable" procedure' );
    like($proc1->sql, qr/CREATE FUNCTION ap_from_millitime_nullable/, "Detected procedure ap_from_millitime_nullable");
    my $proc2 = shift @procs;
    is( $proc2->name, 'sp_update_security_acl', 'Found "sp_update_security_acl" procedure' );
    like($proc2->sql, qr/CREATE PROCEDURE sp_update_security_acl/, "Detected procedure sp_update_security_acl");
}

# Tests for collate table option
{
    my $tr = SQL::Translator->new(parser_args => {mysql_parser_version => 50003});
    my $data = parse($tr,
        q[
          CREATE TABLE test ( id int ) DEFAULT CHARACTER SET latin1 COLLATE latin1_bin;
         ] );

    my $schema = $tr->schema;
    is( $schema->is_valid, 1, 'Schema is valid' );
    my @tables = $schema->get_tables;
    is( scalar @tables, 1, 'Right number of tables (1)' );
    my $table1 = shift @tables;
    is( $table1->name, 'test', 'Found "test" table' );


    my $collate = "Not found!";
    my $charset = "Not found!";
    for my $t1_option_ref ( $table1->options ) {
      my($key, $value) = %{$t1_option_ref};
      $collate = $value if $key eq 'COLLATE';
      $charset = $value if $key eq 'CHARACTER SET';
    }
    is($collate, 'latin1_bin', "Collate found");
    is($charset, 'latin1', "Character set found");
}

# Test the mysql version parser (probably needs to migrate to t/utils.t)
my $parse_as = {
    perl => {
        '3.23.2'    => 3.023002,
        '4'         => 4.000000,
        '50003'     => 5.000003,
        '5.01.0'    => 5.001000,
        '5.1'       => 5.001000,
    },
    mysql => {
        '3.23.2'    => 32302,
        '4'         => 40000,
        '50003'     => 50003,
        '5.01.0'    => 50100,
        '5.1'       => 50100,
    },
};

for my $target (keys %$parse_as) {
    for my $str (keys %{$parse_as->{$target}}) {
        cmp_ok (
            SQL::Translator::Utils::parse_mysql_version ($str, $target),
            '==',
            $parse_as->{$target}{$str},
            "'$str' parsed as $target version '$parse_as->{$target}{$str}'",
        );
    }
}

eval { SQL::Translator::Utils::parse_mysql_version ('bogus5.1') };
ok ($@, 'Exception thrown on invalid version string');

{
    my $tr = SQL::Translator->new;
    my $data = q|create table merge_example (
       id int(11) NOT NULL auto_increment,
       shape_field geometry NOT NULL,
       PRIMARY KEY (id),
       SPATIAL KEY shape_field (shape_field)
    ) ENGINE=MRG_MyISAM UNION=(`sometable_0`,`sometable_1`,`sometable_2`);|;

    my $val = parse($tr, $data);
    my $schema = $tr->schema;
    is( $schema->is_valid, 1, 'Schema is valid' );
    my @tables = $schema->get_tables;
    is( scalar @tables, 1, 'Right number of tables (1)' );
    my $table  = shift @tables;
    is( $table->name, 'merge_example', 'Found "merge_example" table' );

    my $tableTypeFound = 0;
    my $unionFound = 0;
    for my $t_option_ref ( $table->options ) {
      my($key, $value) = %{$t_option_ref};
      if ( $key eq 'ENGINE' ) {
        is($value, 'MRG_MyISAM', 'Table has right table engine option' );
        $tableTypeFound = 1;
      } elsif ( $key eq 'UNION' ) {
        is_deeply($value, [ 'sometable_0','sometable_1','sometable_2' ],
          "UNION option has correct set");
        $unionFound = 1;
      }
    }

    fail('Table did not have a type option') unless $tableTypeFound;
    fail('Table did not have a union option') unless $unionFound;

    my @fields = $table->get_fields;
    is( scalar @fields, 2, 'Right number of fields (2)' );
    my $f1 = shift @fields;
    my $f2 = shift @fields;
    is( $f1->name, 'id', 'First field name is "id"' );
    is( $f1->data_type, 'int', 'Type is "int"' );
    is( $f1->size, 11, 'Size is "11"' );
    is( $f1->is_nullable, 0, 'Field cannot be null' );
    is( $f1->is_primary_key, 1, 'Field is PK' );

    is( $f2->name, 'shape_field', 'Second field name is "shape_field"' );
    is( $f2->data_type, 'geometry', 'Type is "geometry"' );
    is( $f2->is_nullable, 0, 'Field cannot be null' );
    is( $f2->is_primary_key, 0, 'Field is not PK' );

    my @indices = $table->get_indices;
    is( scalar @indices, 1, 'Right number of indices (1)' );
    my $i1 = shift @indices;
    is( $i1->name, 'shape_field', 'No name on index' );
    is( $i1->type, SPATIAL, 'Spatial index' );

    my @constraints = $table->get_constraints;
    is( scalar @constraints, 1, 'Right number of constraints (1)' );
    my $c = shift @constraints;
    is( $c->type, PRIMARY_KEY, 'Constraint is a PK' );
    is( join(',', $c->fields), 'id', 'Constraint is on "id"' );
}

{
    my @data = (
        q|create table quote (
            id int(11) NOT NULL auto_increment,
            PRIMARY KEY (id)
        ) ENGINE="innodb";|,
        q|create table quote (
            id int(11) NOT NULL auto_increment,
            PRIMARY KEY (id)
        ) ENGINE='innodb';|,
        q|create table quote (
            id int(11) NOT NULL auto_increment,
            PRIMARY KEY (id)
        ) ENGINE=innodb;|,
    );
    for my $data (@data) {
        my $tr = SQL::Translator->new;

        my $val = parse($tr, $data);
        my $schema = $tr->schema;
        is( $schema->is_valid, 1, 'Schema is valid' );
        my @tables = $schema->get_tables;
        is( scalar @tables, 1, 'Right number of tables (1)' );
        my $table  = shift @tables;
        is( $table->name, 'quote', 'Found "quote" table' );

        my $tableTypeFound = 0;
        for my $t_option_ref ( $table->options ) {
        my($key, $value) = %{$t_option_ref};
        if ( $key eq 'ENGINE' ) {
            is($value, 'innodb', 'Table has right table engine option' );
            $tableTypeFound = 1;
        }
        }

        fail('Table did not have a type option') unless $tableTypeFound;

        my @fields = $table->get_fields;
        my $f1 = shift @fields;
        is( $f1->name, 'id', 'First field name is "id"' );
        is( $f1->data_type, 'int', 'Type is "int"' );
        is( $f1->size, 11, 'Size is "11"' );
        is( $f1->is_nullable, 0, 'Field cannot be null' );
        is( $f1->is_primary_key, 1, 'Field is PK' );
    }
}

{
    my $tr = SQL::Translator->new;
    my $data = q|create table "sessions" (
        id char(32) not null default '0' primary key,
        ssn varchar(12) NOT NULL default 'test single quotes like in you''re',
        user varchar(20) NOT NULL default 'test single quotes escaped like you\'re',
        key using btree (ssn)
    );|;

    my $val = parse($tr, $data);
    my $schema = $tr->schema;
    is( $schema->is_valid, 1, 'Schema is valid' );
    my @tables = $schema->get_tables;
    is( scalar @tables, 1, 'Right number of tables (1)' );
    my $table  = shift @tables;
    is( $table->name, 'sessions', 'Found "sessions" table' );

    my @fields = $table->get_fields;
    is( scalar @fields, 3, 'Right number of fields (3)' );
    my $f1 = shift @fields;
    my $f2 = shift @fields;
    my $f3 = shift @fields;
    is( $f1->name, 'id', 'First field name is "id"' );
    is( $f1->data_type, 'char', 'Type is "char"' );
    is( $f1->size, 32, 'Size is "32"' );
    is( $f1->is_nullable, 0, 'Field cannot be null' );
    is( $f1->default_value, '0', 'Default value is "0"' );
    is( $f1->is_primary_key, 1, 'Field is PK' );

    is( $f2->name, 'ssn', 'Second field name is "ssn"' );
    is( $f2->data_type, 'varchar', 'Type is "varchar"' );
    is( $f2->size, 12, 'Size is "12"' );
    is( $f2->is_nullable, 0, 'Field can not be null' );
    is( $f2->default_value, "test single quotes like in you''re", "Single quote in default value is escaped properly" );
    is( $f2->is_primary_key, 0, 'Field is not PK' );

    # this is more of a sanity test because the original sqlt regex for default looked for an escaped quote represented as \'
    # however in mysql 5.x (and probably other previous versions) still actually outputs that as ''
    is( $f3->name, 'user', 'Second field name is "user"' );
    is( $f3->data_type, 'varchar', 'Type is "varchar"' );
    is( $f3->size, 20, 'Size is "20"' );
    is( $f3->is_nullable, 0, 'Field can not be null' );
    is( $f3->default_value, "test single quotes escaped like you\\'re", "Single quote in default value is escaped properly" );
    is( $f3->is_primary_key, 0, 'Field is not PK' );
}

{
    # silence PR::D from spewing on STDERR
    local $::RD_ERRORS = 0;
    local $::RD_WARN = 0;
    local $::RD_HINT = 0;
    my $tr = SQL::Translator->new;
    my $data = q|create table "sessions" (
        id char(32) not null default,
        ssn varchar(12) NOT NULL default 'test single quotes like in you''re',
        user varchar(20) NOT NULL default 'test single quotes escaped like you\'re',
        key using btree (ssn)
    );|;

    my $val= parse($tr,$data);
    ok ($tr->error =~ /Parse failed\./, 'Parse failed error without default value');
}

{
    # make sure empty string default value still works
    my $tr = SQL::Translator->new;
    my $data = q|create table "sessions" (
        id char(32) not null DEFAULT '',
        ssn varchar(12) NOT NULL default "",
        key using btree (ssn)
    );|;
    my $val= parse($tr,$data);

    my @fields = $tr->schema->get_table('sessions')->get_fields;
    is (scalar @fields, 2, 'Both fields parsed correctly');
    for (@fields) {
      my $def = $_->default_value;
      ok( (defined $def and $def eq ''), "Defaults on field $_ correct" );
    }
}

{
    # test rt70437 and rt71468
    my $file = "$Bin/data/mysql/cashmusic_db.sql";
    ok (-f $file,"File exists");
    my $tr = SQL::Translator->new( parser => 'MySQL');
    ok ($tr->translate($file),'File translated');
    ok (!$tr->error, 'no error');
    ok (my $schema = $tr->schema, 'got schema');
}
