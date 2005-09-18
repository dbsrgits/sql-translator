package SQL::Translator::Producer::DB2;

# -------------------------------------------------------------------
# $Id: DB2.pm,v 1.1 2005-09-18 20:06:31 schiffbruechige Exp $
# -------------------------------------------------------------------
# Copyright (C) 2002-4 SQLFairy Authors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
# 02111-1307  USA
# -------------------------------------------------------------------

=head1 NAME

SQL::Translator::Producer::DB2 - DB2 SQL producer

=head1 SYNOPSIS

  use SQL::Translator;

  my $t = SQL::Translator->new( parser => '...', producer => 'DB2' );
  print $translator->translate( $file );

=head1 DESCRIPTION

Creates an SQL DDL suitable for DB.

=cut

use strict;
use vars qw[ $VERSION $DEBUG $WARN ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(header_comment);


# http://publib.boulder.ibm.com/infocenter/db2help/topic/com.ibm.db2.udb.doc/ad/r0006844.htm

# This is a terrible WTDI, each Parser should parse down to some standard set
# of SQL data types, with field->extra entries being used to convert back to
# weird types like "polygon" if needed (IMO anyway)

my %translate  = (
    #
    # MySQL types
    #
    int        => 'integer',
    mediumint  => 'integer',
    tinyint    => 'smallint',
    char       => 'char',
    tinyblob   => 'blob',
    mediumblob => 'blob',
    longblob   => 'long varchar for bit data',
    tinytext   => 'varchar',
    text       => 'clob',
    longtext   => 'clob',
    mediumtext => 'clob',
    enum       => 'varchar',
    set        => 'varchar',
    date       => 'date',
    datetime   => 'timestamp',
    time       => 'time',
    year       => 'date',

    #
    # PostgreSQL types
    #
    'double precision'  => 'double',
    serial              => 'integer',
    bigserial           => 'integer',
    money               => 'double',
    character           => 'char',
    'character varying' => 'varchar',
    bytea               => 'BLOB',
    interval            => 'integer',
    boolean             => 'smallint',
    point               => 'integer',
    line                => 'integer',
    lseg                => 'integer',
    box                 => 'integer',
    path                => 'integer',
    polygon             => 'integer',
    circle              => 'integer',
    cidr                => 'integer',
    inet                => 'varchar',
    macaddr             => 'varchar',
    bit                 => 'number',
    'bit varying'       => 'number',

    #
    # DB types
    #
    number              => 'integer',
    varchar2            => 'varchar',
    long                => 'clob',
);

my %db2_reserved = map { $_ => 1} qw/
ADD                DETERMINISTIC  LEAVE         RESTART
AFTER              DISALLOW       LEFT          RESTRICT
ALIAS              DISCONNECT     LIKE          RESULT
ALL                DISTINCT       LINKTYPE      RESULT_SET_LOCATOR
ALLOCATE           DO             LOCAL         RETURN
ALLOW              DOUBLE         LOCALE        RETURNS
ALTER              DROP           LOCATOR       REVOKE
AND                DSNHATTR       LOCATORS      RIGHT
ANY                DSSIZE         LOCK          ROLLBACK
APPLICATION        DYNAMIC        LOCKMAX       ROUTINE
AS                 EACH           LOCKSIZE      ROW
ASSOCIATE          EDITPROC       LONG          ROWS
ASUTIME            ELSE           LOOP          RRN
AUDIT              ELSEIF         MAXVALUE      RUN
AUTHORIZATION      ENCODING       MICROSECOND   SAVEPOINT
AUX                END            MICROSECONDS  SCHEMA
AUXILIARY          END-EXEC       MINUTE        SCRATCHPAD
BEFORE             END-EXEC1      MINUTES       SECOND
BEGIN              ERASE          MINVALUE      SECONDS
BETWEEN            ESCAPE         MODE          SECQTY
BINARY             EXCEPT         MODIFIES      SECURITY
BUFFERPOOL         EXCEPTION      MONTH         SELECT
BY                 EXCLUDING      MONTHS        SENSITIVE
CACHE              EXECUTE        NEW           SET
CALL               EXISTS         NEW_TABLE     SIGNAL
CALLED             EXIT           NO            SIMPLE
CAPTURE            EXTERNAL       NOCACHE       SOME
CARDINALITY        FENCED         NOCYCLE       SOURCE
CASCADED           FETCH          NODENAME      SPECIFIC
CASE               FIELDPROC      NODENUMBER    SQL
CAST               FILE           NOMAXVALUE    SQLID
CCSID              FINAL          NOMINVALUE    STANDARD
CHAR               FOR            NOORDER       START
CHARACTER          FOREIGN        NOT           STATIC
CHECK              FREE           NULL          STAY
CLOSE              FROM           NULLS         STOGROUP
CLUSTER            FULL           NUMPARTS      STORES
COLLECTION         FUNCTION       OBID          STYLE
COLLID             GENERAL        OF            SUBPAGES
COLUMN             GENERATED      OLD           SUBSTRING
COMMENT            GET            OLD_TABLE     SYNONYM
COMMIT             GLOBAL         ON            SYSFUN
CONCAT             GO             OPEN          SYSIBM
CONDITION          GOTO           OPTIMIZATION  SYSPROC
CONNECT            GRANT          OPTIMIZE      SYSTEM
CONNECTION         GRAPHIC        OPTION        TABLE
CONSTRAINT         GROUP          OR            TABLESPACE
CONTAINS           HANDLER        ORDER         THEN
CONTINUE           HAVING         OUT           TO
COUNT              HOLD           OUTER         TRANSACTION
COUNT_BIG          HOUR           OVERRIDING    TRIGGER
CREATE             HOURS          PACKAGE       TRIM
CROSS              IDENTITY       PARAMETER     TYPE
CURRENT            IF             PART          UNDO
CURRENT_DATE       IMMEDIATE      PARTITION     UNION
CURRENT_LC_CTYPE   IN             PATH          UNIQUE
CURRENT_PATH       INCLUDING      PIECESIZE     UNTIL
CURRENT_SERVER     INCREMENT      PLAN          UPDATE
CURRENT_TIME       INDEX          POSITION      USAGE
CURRENT_TIMESTAMP  INDICATOR      PRECISION     USER
CURRENT_TIMEZONE   INHERIT        PREPARE       USING
CURRENT_USER       INNER          PRIMARY       VALIDPROC
CURSOR             INOUT          PRIQTY        VALUES
CYCLE              INSENSITIVE    PRIVILEGES    VARIABLE
DATA               INSERT         PROCEDURE     VARIANT
DATABASE           INTEGRITY      PROGRAM       VCAT
DAY                INTO           PSID          VIEW
DAYS               IS             QUERYNO       VOLUMES
DB2GENERAL         ISOBID         READ          WHEN
DB2GENRL           ISOLATION      READS         WHERE
DB2SQL             ITERATE        RECOVERY      WHILE
DBINFO             JAR            REFERENCES    WITH
DECLARE            JAVA           REFERENCING   WLM
DEFAULT            JOIN           RELEASE       WRITE
DEFAULTS           KEY            RENAME        YEAR
DEFINITION         LABEL          REPEAT        YEARS
DELETE             LANGUAGE       RESET
DESCRIPTOR         LC_CTYPE       RESIGNAL 
/;

#------------------------------------------------------------------------------

sub produce
{
    my ($translator) = @_;
    $DEBUG             = $translator->debug;
    $WARN              = $translator->show_warnings;
    my $no_comments    = $translator->no_comments;
    my $add_drop_table = $translator->add_drop_table;
    my $schema         = $translator->schema;
    my $output         = '';
    my $indent         = '    ';

    $output .= header_comment unless($no_comments);
    my (@table_defs);
    foreach my $table ($schema->get_tables)
    {
        my $table_name = check_name($table->name, 'tables', 18);

        my (@field_defs, @comments);
        push @comments, "--\n-- Table: $table_name\n--" unless $no_comments;
        foreach my $field ($table->get_fields)
        {
            my $field_name = check_name($field->name, 'fields', 30);
            my $data_type = uc($translate{lc($field->data_type)} || $field->data_type);
            my $size = $field->size();

            my $field_def = "$field_name $data_type";
            $field_def .= $field->is_auto_increment ? 
                ' GENERATED BY DEFAULT AS IDENTITY' : '';
            $field_def .= $data_type =~ /CHAR/i ? "(${size})" : '';
            $field_def .= !$field->is_nullable ? ' NOT NULL':'';
            $field_def .= $field->is_primary_key ? ' PRIMARY KEY':'';
            $field_def .= $field->default_value ? ' DEFAULT ' .  $field->default_value : '';

            push @field_defs, "${indent}${field_def}";
        }
        

        my $tablespace = $table->extra()->{'TABLESPACE'} || '';
        my $table_def = "CREATE TABLE $table_name (\n";
        $table_def .= join (",\n", @field_defs);
        $table_def .= "\n)";
        $table_def .= $tablespace ? "IN $tablespace;" : ';';
        
        push @table_defs, "DROP TABLE $table_name;\n" if $add_drop_table;
        push @table_defs, $table_def;
    }   

    $output .= join("\n\n", @table_defs);
}

{ my %objnames;

    sub check_name
    {
        my ($name, $type, $length) = @_;

        my $newname = $name;
        if(length($name) > $length)   ## Maximum table name length is 18
        {
            warn "Table name $name is longer than $length characters, truncated" if $WARN;
            if(grep {$_ eq substr($name, 0, $length) } 
                              values(%{$objnames{$type}}))
            {
                die "Got multiple matching table names when truncated";
            }
            $objnames{$type}{$name} = substr($name, 0,$length);
            $newname = $objnames{$type}{$name};
        }

        if($db2_reserved{uc($newname)})
        {
            warn "$newname is a reserved word in DB2!" if $WARN;
        }

        return sprintf("%-*s", $length-5, $newname);
    }
}

1;
