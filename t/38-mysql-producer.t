#!/usr/bin/perl -w
# vim:filetype=perl

#
# Note that the bulk of the testing for the mysql producer is in
# 08postgres-to-mysql.t. This test is for additional stuff that can't be tested
# using an Oracle schema as source e.g. extra attributes.
#

use strict;
use Test::More;
use Test::Exception;
use Test::SQL::Translator qw(maybe_plan);

use Data::Dumper;
use FindBin qw/$Bin/;

# Testing 1,2,3,4...
#=============================================================================

BEGIN {
    maybe_plan(73,
        'YAML',
        'SQL::Translator::Producer::MySQL',
        'Test::Differences',
    )
}
use Test::Differences;
use SQL::Translator;

# Main test.
{
my $yaml_in = <<EOSCHEMA;
---
schema:
  tables:
    thing:
      name: thing
      extra:
        mysql_charset: latin1
        mysql_collate: latin1_danish_ci
      order: 1
      fields:
        id:
          name: id
          data_type: unsigned int
          is_primary_key: 1
          is_auto_increment: 1
          order: 1
        name:
          name: name
          data_type: varchar
          size:
            - 32
          order: 2
        swedish_name:
          name: swedish_name
          data_type: varchar
          size: 32
          extra:
            mysql_charset: swe7
          order: 3
        description:
          name: description
          data_type: text
          extra:
            mysql_charset: utf8
            mysql_collate: utf8_general_ci
          order: 4
      constraints:
        - type: UNIQUE
          fields:
            - name
          name: idx_unique_name

    thing2:
      name: some.thing2
      extra:
      order: 2
      fields:
        id:
          name: id
          data_type: int
          is_primary_key: 0
          order: 1
          is_foreign_key: 1
        foo:
          name: foo
          data_type: int
          order: 2
          is_not_null: 1
        foo2:
          name: foo2
          data_type: int
          order: 3
          is_not_null: 1
        bar_set:
          name: bar_set
          data_type: set
          order: 4
          is_not_null: 1
          extra:
            list:
              - foo
              - bar
              - baz
      indices:
        - type: NORMAL
          fields:
            - id
          name: index_1
        - type: NORMAL
          fields:
            - id
          name: really_long_name_bigger_than_64_chars_aaaaaaaaaaaaaaaaaaaaaaaaaaa
      constraints:
        - type: PRIMARY_KEY
          fields:
            - id
            - foo
        - reference_table: thing
          type: FOREIGN_KEY
          fields: foo
          name: fk_thing
        - reference_table: thing
          type: FOREIGN_KEY
          fields: foo2
          name: fk_thing

    thing3:
      name: some.thing3
      extra:
      order: 3
      fields:
        id:
          name: id
          data_type: int
          is_primary_key: 0
          order: 1
          is_foreign_key: 1
        foo:
          name: foo
          data_type: int
          order: 2
          is_not_null: 1
        foo2:
          name: foo2
          data_type: int
          order: 3
          is_not_null: 1
        bar_set:
          name: bar_set
          data_type: set
          order: 4
          is_not_null: 1
          extra:
            list:
              - foo
              - bar
              - baz
      indices:
        - type: NORMAL
          fields:
            - id
          name: index_1
        - type: NORMAL
          fields:
            - id
          name: really_long_name_bigger_than_64_chars_aaaaaaaaaaaaaaaaaaaaaaaaaaa
      constraints:
        - type: PRIMARY_KEY
          fields:
            - id
            - foo
        - reference_table: some.thing2
          type: FOREIGN_KEY
          fields: foo
          name: fk_thing
        - reference_table: some.thing2
          type: FOREIGN_KEY
          fields: foo2
          name: fk_thing
EOSCHEMA

my @stmts = (
"SET foreign_key_checks=0",

"DROP TABLE IF EXISTS `thing`",
"CREATE TABLE `thing` (
  `id` unsigned int auto_increment,
  `name` varchar(32),
  `swedish_name` varchar(32) character set swe7,
  `description` text character set utf8 collate utf8_general_ci,
  PRIMARY KEY (`id`),
  UNIQUE `idx_unique_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARACTER SET latin1 COLLATE latin1_danish_ci",

"DROP TABLE IF EXISTS `some`.`thing2`",
"CREATE TABLE `some`.`thing2` (
  `id` integer,
  `foo` integer,
  `foo2` integer,
  `bar_set` set('foo', 'bar', 'baz'),
  INDEX `index_1` (`id`),
  INDEX `really_long_name_bigger_than_64_chars_aaaaaaaaaaaaaaaaa_aed44c47` (`id`),
  INDEX (`foo`),
  INDEX (`foo2`),
  PRIMARY KEY (`id`, `foo`),
  CONSTRAINT `fk_thing` FOREIGN KEY (`foo`) REFERENCES `thing` (`id`),
  CONSTRAINT `fk_thing_1` FOREIGN KEY (`foo2`) REFERENCES `thing` (`id`)
) ENGINE=InnoDB",

"DROP TABLE IF EXISTS `some`.`thing3`",
"CREATE TABLE `some`.`thing3` (
  `id` integer,
  `foo` integer,
  `foo2` integer,
  `bar_set` set('foo', 'bar', 'baz'),
  INDEX `index_1` (`id`),
  INDEX `really_long_name_bigger_than_64_chars_aaaaaaaaaaaaaaaaa_aed44c47` (`id`),
  INDEX (`foo`),
  INDEX (`foo2`),
  PRIMARY KEY (`id`, `foo`),
  CONSTRAINT `fk_thing_2` FOREIGN KEY (`foo`) REFERENCES `some`.`thing2` (`id`, `foo`),
  CONSTRAINT `fk_thing_3` FOREIGN KEY (`foo2`) REFERENCES `some`.`thing2` (`id`, `foo`)
) ENGINE=InnoDB",

"SET foreign_key_checks=1",

);

my @stmts_no_drop = grep {$_ !~ /^DROP TABLE/} @stmts;

my $mysql_out = join(";\n\n", @stmts_no_drop) . ";\n\n";


    my $sqlt;
    $sqlt = SQL::Translator->new(
        show_warnings  => 1,
        no_comments    => 1,
#        debug          => 1,
        from           => "YAML",
        to             => "MySQL",
        quote_table_names => 1,
        quote_field_names => 1
    );

    my $out = $sqlt->translate(\$yaml_in)
    or die "Translate error:".$sqlt->error;
    ok $out ne "",                    "Produced something!";
    eq_or_diff $out, $mysql_out,      "Scalar output looks right with quoting";

    my @out = $sqlt->translate(\$yaml_in)
      or die "Translat eerror:".$sqlt->error;
    is_deeply \@out, \@stmts_no_drop, "Array output looks right with quoting";

    $sqlt->quote_identifiers(0);

    $out = $sqlt->translate(\$yaml_in)
      or die "Translate error:".$sqlt->error;

    @out = $sqlt->translate(\$yaml_in)
      or die "Translate error:".$sqlt->error;
    $mysql_out =~ s/`//g;
    my @unquoted_stmts = map { s/`//g; $_} @stmts_no_drop;
    eq_or_diff $out, $mysql_out,       "Output looks right without quoting";
    is_deeply \@out, \@unquoted_stmts, "Array output looks right without quoting";

    $sqlt->quote_identifiers(1);
    $sqlt->add_drop_table(1);

    @out = $sqlt->translate(\$yaml_in)
      or die "Translat eerror:".$sqlt->error;
    $out = $sqlt->translate(\$yaml_in)
      or die "Translat eerror:".$sqlt->error;

    eq_or_diff $out, join(";\n\n", @stmts) . ";\n\n", "Output looks right with DROP TABLEs";
    is_deeply \@out, \@stmts,          "Array output looks right with DROP TABLEs";
}

###############################################################################
# New alter/add subs

{
my $table = SQL::Translator::Schema::Table->new( name => 'mytable');

my $field1 = SQL::Translator::Schema::Field->new( name => 'myfield',
                                                  table => $table,
                                                  data_type => 'VARCHAR',
                                                  size => 10,
                                                  default_value => undef,
                                                  is_auto_increment => 0,
                                                  is_nullable => 1,
                                                  is_foreign_key => 0,
                                                  is_unique => 0 );

my $field1_sql = SQL::Translator::Producer::MySQL::create_field($field1);

is($field1_sql, 'myfield VARCHAR(10)', 'Create field works');

my $field2 = SQL::Translator::Schema::Field->new( name      => 'myfield',
                                                  table => $table,
                                                  data_type => 'VARCHAR',
                                                  size      => 25,
                                                  default_value => undef,
                                                  is_auto_increment => 0,
                                                  is_nullable => 0,
                                                  is_foreign_key => 0,
                                                  is_unique => 0 );

my $alter_field = SQL::Translator::Producer::MySQL::alter_field($field1,
                                                                $field2);
is($alter_field, 'ALTER TABLE mytable CHANGE COLUMN myfield myfield VARCHAR(25) NOT NULL', 'Alter field works');

my $add_field = SQL::Translator::Producer::MySQL::add_field($field1);

is($add_field, 'ALTER TABLE mytable ADD COLUMN myfield VARCHAR(10)', 'Add field works');

my $drop_field = SQL::Translator::Producer::MySQL::drop_field($field2);
is($drop_field, 'ALTER TABLE mytable DROP COLUMN myfield', 'Drop field works');

my $field3 = SQL::Translator::Schema::Field->new( name      => 'myfield',
                                                  table => $table,
                                                  data_type => 'boolean',
                                                  is_nullable => 0,
                                                  is_foreign_key => 0,
                                                  is_unique => 0 );

my $field3_sql = SQL::Translator::Producer::MySQL::create_field($field3, { mysql_version => 4.1 });
is($field3_sql, 'myfield boolean NOT NULL', 'For Mysql >= 4, use boolean type');
$field3_sql = SQL::Translator::Producer::MySQL::create_field($field3, { mysql_version => 3.22 });
is($field3_sql, "myfield enum('0','1') NOT NULL", 'For Mysql < 4, use enum for boolean type');
$field3_sql = SQL::Translator::Producer::MySQL::create_field($field3,);
is($field3_sql, "myfield enum('0','1') NOT NULL", 'When no version specified, use enum for boolean type');

my $number_sizes = {
    '3, 2' => 'double',
    12 => 'bigint',
    1 => 'tinyint',
    4 => 'int',
};
for my $size (keys %$number_sizes) {
    my $expected = $number_sizes->{$size};
    my $number_field = SQL::Translator::Schema::Field->new(
        name => "numberfield_$expected",
        table => $table,
        data_type => 'number',
        size => $size,
        is_nullable => 1,
        is_foreign_key => 0,
        is_unique => 0
    );

    is(
        SQL::Translator::Producer::MySQL::create_field($number_field),
        "numberfield_$expected $expected($size)",
        "Use $expected for NUMBER types of size $size"
    );
}

my $varchars;
for my $size (qw/255 256 65535 65536/) {
    $varchars->{$size} = SQL::Translator::Schema::Field->new(
        name => "vch_$size",
        table => $table,
        data_type => 'varchar',
        size => $size,
        is_nullable => 1,
    );
}


is (
    SQL::Translator::Producer::MySQL::create_field($varchars->{255}, { mysql_version => 5.000003 }),
    'vch_255 varchar(255)',
    'VARCHAR(255) is not substituted with TEXT for Mysql >= 5.0.3'
);
is (
    SQL::Translator::Producer::MySQL::create_field($varchars->{255}, { mysql_version => 5.0 }),
    'vch_255 varchar(255)',
    'VARCHAR(255) is not substituted with TEXT for Mysql < 5.0.3'
);
is (
    SQL::Translator::Producer::MySQL::create_field($varchars->{255}),
    'vch_255 varchar(255)',
    'VARCHAR(255) is not substituted with TEXT when no version specified',
);


is (
    SQL::Translator::Producer::MySQL::create_field($varchars->{256}, { mysql_version => 5.000003 }),
    'vch_256 varchar(256)',
    'VARCHAR(256) is not substituted with TEXT for Mysql >= 5.0.3'
);
is (
    SQL::Translator::Producer::MySQL::create_field($varchars->{256}, { mysql_version => 5.0 }),
    'vch_256 text',
    'VARCHAR(256) is substituted with TEXT for Mysql < 5.0.3'
);
is (
    SQL::Translator::Producer::MySQL::create_field($varchars->{256}),
    'vch_256 text',
    'VARCHAR(256) is substituted with TEXT when no version specified',
);


is (
    SQL::Translator::Producer::MySQL::create_field($varchars->{65535}, { mysql_version => 5.000003 }),
    'vch_65535 varchar(65535)',
    'VARCHAR(65535) is not substituted with TEXT for Mysql >= 5.0.3'
);
is (
    SQL::Translator::Producer::MySQL::create_field($varchars->{65535}, { mysql_version => 5.0 }),
    'vch_65535 text',
    'VARCHAR(65535) is substituted with TEXT for Mysql < 5.0.3'
);
is (
    SQL::Translator::Producer::MySQL::create_field($varchars->{65535}),
    'vch_65535 text',
    'VARCHAR(65535) is substituted with TEXT when no version specified',
);


is (
    SQL::Translator::Producer::MySQL::create_field($varchars->{65536}, { mysql_version => 5.000003 }),
    'vch_65536 text',
    'VARCHAR(65536) is substituted with TEXT for Mysql >= 5.0.3'
);
is (
    SQL::Translator::Producer::MySQL::create_field($varchars->{65536}, { mysql_version => 5.0 }),
    'vch_65536 text',
    'VARCHAR(65536) is substituted with TEXT for Mysql < 5.0.3'
);
is (
    SQL::Translator::Producer::MySQL::create_field($varchars->{65536}),
    'vch_65536 text',
    'VARCHAR(65536) is substituted with TEXT when no version specified',
);


{
  my $view1 = SQL::Translator::Schema::View->new( name => 'view_foo',
                                                  fields => [qw/id name/],
                                                  sql => 'SELECT id, name FROM thing',
                                                  extra => {
                                                    mysql_definer => 'CURRENT_USER',
                                                    mysql_algorithm => 'MERGE',
                                                    mysql_security => 'DEFINER',
                                                  });
  my $create_opts = { add_replace_view => 1, no_comments => 1 };
  my $view1_sql1 = SQL::Translator::Producer::MySQL::create_view($view1, $create_opts);

  my $view_sql_replace = <<'EOV';
CREATE OR REPLACE
   ALGORITHM = MERGE
   DEFINER = CURRENT_USER
   SQL SECURITY DEFINER
  VIEW view_foo ( id, name ) AS
    SELECT id, name FROM thing
EOV

  is($view1_sql1, $view_sql_replace, 'correct "CREATE OR REPLACE VIEW" SQL');


  my $view2 = SQL::Translator::Schema::View->new( name => 'view_foo',
                                                  fields => [qw/id name/],
                                                  sql => 'SELECT id, name FROM thing',);
  my $create2_opts = { add_replace_view => 0, no_comments => 1 };
  my $view1_sql2 = SQL::Translator::Producer::MySQL::create_view($view2, $create2_opts);
  my $view_sql_noreplace = <<'EOV';
CREATE
  VIEW view_foo ( id, name ) AS
    SELECT id, name FROM thing
EOV

  is($view1_sql2, $view_sql_noreplace, 'correct "CREATE VIEW" SQL');

  {
    my %extra = $view1->extra;
    is_deeply \%extra,
      {
        'mysql_algorithm' => 'MERGE',
        'mysql_definer'   => 'CURRENT_USER',
        'mysql_security'  => 'DEFINER'
      },
      'Extra attributes';
  }

  $view1->remove_extra(qw/mysql_definer mysql_security/);
  {
    my %extra = $view1->extra;
    is_deeply \%extra, { 'mysql_algorithm' => 'MERGE', }, 'Extra attributes after first reset_extra call';
  }

  $view1->remove_extra();
  {
    my %extra = $view1->extra;
    is_deeply \%extra, {}, 'Extra attributes completely removed';
  }
}

{

    # certain types do not support a size, see also:
    # http://dev.mysql.com/doc/refman/5.1/de/create-table.html
    for my $type (qw/date time timestamp datetime year/) {
        my $field = SQL::Translator::Schema::Field->new(
            name              => "my$type",
            table             => $table,
            data_type         => $type,
            size              => 10,
            default_value     => undef,
            is_auto_increment => 0,
            is_nullable       => 1,
            is_foreign_key    => 0,
            is_unique         => 0
        );
        my $sql = SQL::Translator::Producer::MySQL::create_field($field);
        is($sql, "my$type $type", "Skip length param for type $type");
    }
}

} #non quoted test

{
    #Quoted test
    my $table = SQL::Translator::Schema::Table->new( name => 'mydb.mytable');

    my $field1 = SQL::Translator::Schema::Field->new( name => 'myfield',
                                                  table => $table,
                                                  data_type => 'VARCHAR',
                                                  size => 10,
                                                  default_value => undef,
                                                  is_auto_increment => 0,
                                                  is_nullable => 1,
                                                  is_foreign_key => 0,
                                                  is_unique => 0 );


    my $field2 = SQL::Translator::Schema::Field->new( name      => 'myfield',
                                                  table => $table,
                                                  data_type => 'VARCHAR',
                                                  size      => 25,
                                                  default_value => undef,
                                                  is_auto_increment => 0,
                                                  is_nullable => 0,
                                                  is_foreign_key => 0,
                                                  is_unique => 0 );

    my $field3 = SQL::Translator::Schema::Field->new( name      => 'myfield',
                                                  table => $table,
                                                  data_type => 'boolean',
                                                  is_nullable => 0,
                                                  is_foreign_key => 0,
                                                  is_unique => 0 );


    my $qt = '`';
    my $qf = '`';
    my $options = {
        quote_table_names => $qt,
        quote_field_names => $qf,
    };


    my $alter_field = SQL::Translator::Producer::MySQL::alter_field($field1, $field2, $options);
    is($alter_field, 'ALTER TABLE `mydb`.`mytable` CHANGE COLUMN `myfield` `myfield` VARCHAR(25) NOT NULL', 'Alter field works');

    my $add_field = SQL::Translator::Producer::MySQL::add_field($field1, $options);

    is($add_field, 'ALTER TABLE `mydb`.`mytable` ADD COLUMN `myfield` VARCHAR(10)', 'Add field works');

    my $drop_field = SQL::Translator::Producer::MySQL::drop_field($field2, $options);
    is($drop_field, 'ALTER TABLE `mydb`.`mytable` DROP COLUMN `myfield`', 'Drop field works');

    my $field3_sql = SQL::Translator::Producer::MySQL::create_field($field3, { mysql_version => 4.1, %$options });
is($field3_sql, '`myfield` boolean NOT NULL', 'For Mysql >= 4, use boolean type');
$field3_sql = SQL::Translator::Producer::MySQL::create_field($field3, { mysql_version => 3.22, %$options });
is($field3_sql, "`myfield` enum('0','1') NOT NULL", 'For Mysql < 4, use enum for boolean type');
$field3_sql = SQL::Translator::Producer::MySQL::create_field($field3,$options);
is($field3_sql, "`myfield` enum('0','1') NOT NULL", 'When no version specified, use enum for boolean type');

    my $number_sizes = {
        '3, 2' => 'double',
        12 => 'bigint',
        1 => 'tinyint',
        4 => 'int',
    };
    for my $size (keys %$number_sizes) {
        my $expected = $number_sizes->{$size};
        my $number_field = SQL::Translator::Schema::Field->new(
            name => "numberfield_$expected",
            table => $table,
            data_type => 'number',
            size => $size,
            is_nullable => 1,
            is_foreign_key => 0,
            is_unique => 0
        );

        is(
            SQL::Translator::Producer::MySQL::create_field($number_field, $options),
            "`numberfield_$expected` $expected($size)",
            "Use $expected for NUMBER types of size $size"
        );
    }

    my $varchars;
    for my $size (qw/255 256 65535 65536/) {
        $varchars->{$size} = SQL::Translator::Schema::Field->new(
            name => "vch_$size",
            table => $table,
            data_type => 'varchar',
            size => $size,
            is_nullable => 1,
        );
    }


    is (
        SQL::Translator::Producer::MySQL::create_field($varchars->{255}, { mysql_version => 5.000003, %$options }),
        '`vch_255` varchar(255)',
        'VARCHAR(255) is not substituted with TEXT for Mysql >= 5.0.3'
    );
    is (
        SQL::Translator::Producer::MySQL::create_field($varchars->{255}, { mysql_version => 5.0, %$options }),
        '`vch_255` varchar(255)',
        'VARCHAR(255) is not substituted with TEXT for Mysql < 5.0.3'
    );
    is (
        SQL::Translator::Producer::MySQL::create_field($varchars->{255}, $options),
        '`vch_255` varchar(255)',
        'VARCHAR(255) is not substituted with TEXT when no version specified',
    );


    is (
        SQL::Translator::Producer::MySQL::create_field($varchars->{256}, { mysql_version => 5.000003, %$options }),
        '`vch_256` varchar(256)',
        'VARCHAR(256) is not substituted with TEXT for Mysql >= 5.0.3'
    );
    is (
        SQL::Translator::Producer::MySQL::create_field($varchars->{256}, { mysql_version => 5.0, %$options }),
        '`vch_256` text',
        'VARCHAR(256) is substituted with TEXT for Mysql < 5.0.3'
    );
    is (
        SQL::Translator::Producer::MySQL::create_field($varchars->{256}, $options),
        '`vch_256` text',
        'VARCHAR(256) is substituted with TEXT when no version specified',
    );


    is (
        SQL::Translator::Producer::MySQL::create_field($varchars->{65535}, { mysql_version => 5.000003, %$options }),
        '`vch_65535` varchar(65535)',
        'VARCHAR(65535) is not substituted with TEXT for Mysql >= 5.0.3'
    );
    is (
        SQL::Translator::Producer::MySQL::create_field($varchars->{65535}, { mysql_version => 5.0, %$options }),
        '`vch_65535` text',
        'VARCHAR(65535) is substituted with TEXT for Mysql < 5.0.3'
    );
    is (
        SQL::Translator::Producer::MySQL::create_field($varchars->{65535}, $options),
        '`vch_65535` text',
        'VARCHAR(65535) is substituted with TEXT when no version specified',
    );


    is (
        SQL::Translator::Producer::MySQL::create_field($varchars->{65536}, { mysql_version => 5.000003, %$options }),
        '`vch_65536` text',
        'VARCHAR(65536) is substituted with TEXT for Mysql >= 5.0.3'
    );
    is (
        SQL::Translator::Producer::MySQL::create_field($varchars->{65536}, { mysql_version => 5.0, %$options }),
        '`vch_65536` text',
        'VARCHAR(65536) is substituted with TEXT for Mysql < 5.0.3'
    );
    is (
        SQL::Translator::Producer::MySQL::create_field($varchars->{65536}, $options),
        '`vch_65536` text',
        'VARCHAR(65536) is substituted with TEXT when no version specified',
    );

    {
      my $view1 = SQL::Translator::Schema::View->new( name => 'view_foo',
                                                      fields => [qw/id name/],
                                                      sql => 'SELECT `id`, `name` FROM `my`.`thing`',
                                                      extra => {
                                                        mysql_definer => 'CURRENT_USER',
                                                        mysql_algorithm => 'MERGE',
                                                        mysql_security => 'DEFINER',
                                                      });
      my $create_opts = { add_replace_view => 1, no_comments => 1, %$options };
      my $view1_sql1 = SQL::Translator::Producer::MySQL::create_view($view1, $create_opts);

      my $view_sql_replace = <<'EOV';
CREATE OR REPLACE
   ALGORITHM = MERGE
   DEFINER = CURRENT_USER
   SQL SECURITY DEFINER
  VIEW `view_foo` ( `id`, `name` ) AS
    SELECT `id`, `name` FROM `my`.`thing`
EOV

      is($view1_sql1, $view_sql_replace, 'correct "CREATE OR REPLACE VIEW" SQL');


      my $view2 = SQL::Translator::Schema::View->new( name => 'view_foo',
                                                      fields => [qw/id name/],
                                                      sql => 'SELECT `id`, `name` FROM `my`.`thing`',);
      my $create2_opts = { add_replace_view => 0, no_comments => 1, %$options };
      my $view1_sql2 = SQL::Translator::Producer::MySQL::create_view($view2, $create2_opts);
      my $view_sql_noreplace = <<'EOV';
CREATE
  VIEW `view_foo` ( `id`, `name` ) AS
    SELECT `id`, `name` FROM `my`.`thing`
EOV

      is($view1_sql2, $view_sql_noreplace, 'correct "CREATE VIEW" SQL');

      {
        my %extra = $view1->extra;
        is_deeply \%extra,
          {
            'mysql_algorithm' => 'MERGE',
            'mysql_definer'   => 'CURRENT_USER',
            'mysql_security'  => 'DEFINER'
          },
          'Extra attributes';
      }

      $view1->remove_extra(qw/mysql_definer mysql_security/);
      {
        my %extra = $view1->extra;
        is_deeply \%extra, { 'mysql_algorithm' => 'MERGE', }, 'Extra attributes after first reset_extra call';
      }

      $view1->remove_extra();
      {
        my %extra = $view1->extra;
        is_deeply \%extra, {}, 'Extra attributes completely removed';
      }
    }

    {

        # certain types do not support a size, see also:
        # http://dev.mysql.com/doc/refman/5.1/de/create-table.html
        for my $type (qw/date time timestamp datetime year/) {
            my $field = SQL::Translator::Schema::Field->new(
                name              => "my$type",
                table             => $table,
                data_type         => $type,
                size              => 10,
                default_value     => undef,
                is_auto_increment => 0,
                is_nullable       => 1,
                is_foreign_key    => 0,
                is_unique         => 0
            );
            my $sql = SQL::Translator::Producer::MySQL::create_field($field, $options);
            is($sql, "`my$type` $type", "Skip length param for type $type");
        }
    }
}

{ # test for rt62250
    my $table = SQL::Translator::Schema::Table->new(name => 'table');
    $table->add_field(
        SQL::Translator::Schema::Field->new( name => 'mypk',
                                             table => $table,
                                             data_type => 'INT',
                                             size => 10,
                                             default_value => undef,
                                             is_auto_increment => 1,
                                             is_nullable => 0,
                                             is_foreign_key => 0,
                                             is_unique => 1 ));

    my $constraint = $table->add_constraint(fields => ['mypk'], type => 'PRIMARY_KEY');
    my $options = {quote_table_names => '`'};
    is(SQL::Translator::Producer::MySQL::alter_drop_constraint($constraint,$options),
       'ALTER TABLE `table` DROP PRIMARY KEY','valid drop primary key');
}
