package SQL::Translator::Producer::NuoDB;
# Started with lib/SQL/Translator/Producer/DB2.pm since it created a vastly correct DDL without modification
=head1 NAME

SQL::Translator::Producer::NuoDB - NuoDB SQL producer

=head1 SYNOPSIS

  use SQL::Translator;

  my $t = SQL::Translator->new( parser => '...', producer => 'NuoDB' );
  print $translator->translate( $file );

=head1 DESCRIPTION

Creates an SQL DDL suitable for NuoDB.

=cut

use warnings;
use strict;
use warnings;
our ( $DEBUG, $WARN );
our $VERSION = '1.59';
$DEBUG   = 0 unless defined $DEBUG;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(header_comment);

my %dt_translate;
BEGIN {
  %dt_translate = (
    int                 => 'INTEGER',
    varchar             => 'STRING',
    text                => 'STRING',
    interval            => 'INTEGER',
    bytea               => 'BINARY',
    inet                => 'STRING',
);
}

my %nuodb_reserved = map { $_ => 1} qw/
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
IMMEDIATE      PARTITION     UNION
CURRENT_LC_CTYPE   IN             PATH          UNIQUE
CURRENT_PATH       INCLUDING      PIECESIZE     UNTIL
CURRENT_SERVER     INCREMENT      PLAN          UPDATE
INDEX          POSITION      USAGE
INDICATOR      PRECISION     USER
CURRENT_TIMEZONE   INHERIT        PREPARE       USING
CURRENT_USER       INNER          PRIMARY       VALIDPROC
CURSOR             INOUT          PRIQTY        VALUES
CYCLE              INSENSITIVE    PRIVILEGES    VARIABLE
DATA               INSERT         PROCEDURE     VARIANT
DATABASE           INTEGRITY      PROGRAM       VCAT
DAY                INTO           PSID          VIEW
DAYS               IS             QUERYNO       VOLUMES
ISOBID             READ           WHEN
ISOLATION          READS          WHERE
ITERATE            RECOVERY       WHILE
DBINFO             JAR            REFERENCES    WITH
DECLARE            JAVA           REFERENCING   WLM
DEFAULT            JOIN           RELEASE       WRITE
DEFAULTS           KEY            RENAME        YEAR
DEFINITION         LABEL          REPEAT        YEARS
DELETE             LANGUAGE       RESET
DESCRIPTOR         LC_CTYPE       RESIGNAL
SET                STRING
/;

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
    my (@table_defs, @fks, @index_defs);
    foreach my $table ($schema->get_tables)
    {
        push @table_defs, 'DROP TABLE ' . $table->name . ";" if $add_drop_table;
        my ($table_def, $fks) = create_table($table, {
            no_comments => $no_comments});
        push @table_defs, $table_def;
        push @fks, @$fks;

        foreach my $index ($table->get_indices)
        {
            push @index_defs, create_index($index);
        }

    }
    my (@view_defs);
    foreach my $view ( $schema->get_views )
    {
        push @view_defs, create_view($view);
    }
    my (@trigger_defs);
    foreach my $trigger ( $schema->get_triggers )
    {
        push @trigger_defs, create_trigger($trigger);
    }

    return wantarray ? (@table_defs, @fks, @index_defs, @view_defs, @trigger_defs) :
        $output . join("\n\n", @table_defs, @fks, @index_defs, @view_defs, @trigger_defs) . "\n\n";
}

{ my %objnames;

    sub check_name
    {
        my ($name, $type, $length) = @_;

        my $newname = $name;
        if(length($name) > $length)   ## Maximum table name length is 18
        {
            warn "Table name $name is longer than $length characters, truncated" if $WARN;
        }

        if($nuodb_reserved{uc($newname)})
        {
            warn "$newname is a reserved word in NuoDB!" if $WARN;
            $newname = '"'.$newname.'"';
        }

        return $newname;
    }
}

sub create_table
{
    my ($table, $options) = @_;

    my $table_name = check_name($table->name, 'tables', 128);

    my (@field_defs, @comments);
    push @comments, "--\n-- Table: $table_name\n--" unless $options->{no_comments};
    foreach my $field ($table->get_fields)
    {
        push @field_defs, create_field($field);
    }
    my (@con_defs, @fks);
    foreach my $con ($table->get_constraints)
    {
        my ($cdefs, $fks) = create_constraint($con);
        push @con_defs, @$cdefs;
        push @fks, @$fks;
    }

    my $tablespace = $table->extra()->{'TABLESPACE'} || '';
    my $table_def = "CREATE TABLE $table_name (\n";
    $table_def .= join (",\n", map { "  $_" } @field_defs, @con_defs);
    $table_def .= "\n)";
    $table_def .= $tablespace ? "IN $tablespace;" : ';';

    return $table_def, \@fks;
}

sub create_field
{
    my ($field) = @_;

    my $field_name = check_name($field->name, 'fields', 30);
#    use Data::Dumper;
#    print Dumper(\%dt_translate);
#    print $field->data_type, " ", $dt_translate{lc($field->data_type)}, "\n";
    my $data_type = uc($dt_translate{lc($field->data_type)} || $field->data_type);
    my $size = $field->size();

    my $field_def = "$field_name $data_type";
    $field_def .= $field->is_auto_increment ?
        ' GENERATED BY DEFAULT AS IDENTITY' : '';
    $field_def .= $data_type =~ /(CHAR|CLOB|NUMERIC|DECIMAL)/i ? "(${size})" : '';
    $field_def .= !$field->is_nullable ? ' NOT NULL':'';
    $field_def .= !defined $field->default_value ? '' :
        $field->default_value =~ /current( |_)timestamp/i ||
        $field->default_value =~ /\Qnow()\E/i ?
        ' DEFAULT \'NOW\'' : defined $field->default_value ?
        (" DEFAULT " . ($data_type =~ /(INT|DOUBLE)/i ?
                        $field->default_value : "'" . $field->default_value . "'")
         ) : '';

    return $field_def;
}

sub create_index
{
    my ($index) = @_;

    my @fields;
    # check each field name
    for ($index->fields) {
        push @fields, check_name($_, 'fields', 30);
    }

    my $out = sprintf('CREATE %sINDEX %s ON %s (%s);',
                      $index->type() =~ /^UNIQUE$/i ? 'UNIQUE ' : '',
                      $index->name,
                      $index->table->name,
                      join(', ', @fields));

    return $out;
}

sub create_constraint
{
    my ($constraint) = @_;

    my (@con_defs, @fks);

    my $ctype =  $constraint->type =~ /^PRIMARY(_|\s)KEY$/i ? 'PRIMARY KEY' :
                 $constraint->type =~ /^UNIQUE$/i      ? 'UNIQUE' :
                 $constraint->type =~ /^CHECK_C$/i     ? 'CHECK' :
                 $constraint->type =~ /^FOREIGN(_|\s)KEY$/i ? 'FOREIGN KEY' : '';

    my $expr = $constraint->type =~ /^CHECK_C$/i ? $constraint->expression :
        '';
    my $ref = $constraint->type =~ /^FOREIGN(_|\s)KEY$/i ? ('REFERENCES ' . $constraint->reference_table . '(' . join(', ', $constraint->reference_fields) . ')') : '';
    my $update = $constraint->on_update ? $constraint->on_update : '';
    my $delete = $constraint->on_delete ? $constraint->on_delete : '';

    my $out = join(' ', grep { $_ }
                      $ctype,
                      $constraint->name && $constraint->type ne FOREIGN_KEY ? ('KEY ' . $constraint->name) : '',
                      '(' . join (', ', check_name($constraint->fields, 'fields', 30)) . ')',
                      $expr ? $expr : $ref,
                      $update,
                      $delete);
    if ($constraint->type eq FOREIGN_KEY) {
        my $table_name = $constraint->table->name;

        $out = join(' ',
                    'ALTER TABLE',
                    $table_name,
                    $constraint->name ? ('ADD CONSTRAINT ' . $constraint->name) : 'ADD',
                    ($out . ';'),
            );

        push @fks, $out;
    }
    else {
        push @con_defs, $out;
    }

    return \@con_defs, \@fks;

}

sub create_view
{
    my ($view) = @_;

    my $out = sprintf("CREATE VIEW %s AS\n%s;",
                      $view->name,
                      $view->sql);

    return $out;
}

sub create_trigger
{
    my ($trigger) = @_;

    my $db_events = join ', ', $trigger->database_events;
    my $out = sprintf("DROP TRIGGER IF EXISTS %s;\nSET DELIMITER @\nCREATE TRIGGER %s FOR %s %s %s AS\n %s\nEND_TRIGGER@\nSET DELIMITER ;",
                      $trigger->name,
                      $trigger->name,
                      $trigger->table->name,
                      uc($trigger->perform_action_when) || 'AFTER',
                      uc($db_events) || 'UPDATE',
                      $trigger->action );

    return $out;

}

sub alter_field
{
    my ($from_field, $to_field) = @_;

    my $data_type = uc($dt_translate{lc($to_field->data_type)} || $to_field->data_type);

    my $size = $to_field->size();
    $data_type .= $data_type =~ /CHAR/i ? "(${size})" : '';

    my $out = sprintf('ALTER TABLE %s ALTER %s SET DATATYPE %s',
                      $to_field->table->name,
                      $to_field->name,
                      $data_type);

}

sub add_field
{
    my ($new_field) = @_;

    my $out = sprintf('ALTER TABLE %s ADD COLUMN %s',
                      $new_field->table->name,
                      create_field($new_field));

    return $out;
}

sub drop_field
{
    my ($field) = @_;

    return '';
}
1;
