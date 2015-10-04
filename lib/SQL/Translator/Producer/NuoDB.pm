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
ALL               AS              BETWEEN         BITS
BOTH              BREAK           BY              CALL
CASCADE           CASE            CATCH           COLLATE
COLUMN            CONSTRAINT      CONTAINING      CONTINUE
CREATE            CURRENT         CURRENT_DATE    CURRENT_TIME
CURRENT_TIMESTAMP DEFAULT         DELETE          DESCRIBE
DISTINCT          ELSE            END             END_FOR
END_FUNCTION      END_IF          END_PROCEDURE   END_TRIGGER
END_TRY           END_WHILE       ENUM            ESCAPE
EXECUTE           EXISTS          FALSE           FETCH
FOR               FOREIGN         FOR_UPDATE      FROM
FULL              GENERATED       GROUP           HAVING
IDENTITY          IF              IN              INNER
INOUT             INSERT          INTO            IS
JOIN              KEY             LEADING         LEFT
LIKE              LIMIT           LOGICAL_AND     LOGICAL_NOT
LOGICAL_OR        MAX             MAXVALUE        MIN
NATIONAL          NATURAL         NCHAR           NCLOB
NEXT              NEXT_VALUE      NOT_BETWEEN     NOT_CONTAINING
NOT_IN            NOT_LIKE        NOT_STARTING    NTEXT
NULL              NUMERIC         NVARCHAR        OCTETS
OFF               OFFSET          ON              ONLY
ORDER             OUT             PRIMARY         REAL
RECORD_BATCHING   REFERENCES      REGEXP          RESTART
RESTRICT          RETURN          RIGHT           ROLLBACK
ROWS              SELECT          SET             SHOW
SMALLDATETIME     SMALLINT        STARTING        STRING_TYPE
THEN              THROW           TINYBLOB        TINYINT
TO                TRAILING        TRUE            TRY
UNION             UNIQUE          UNKNOWN         UPDATE
USING             VAR             VER             WHEN
WHERE             WHILE           WITH
ABS               ACOS            ASIN            ATAN2
ATAN              BIT_LENGTH      CAST            CEILING
CHARACTER_LENGTH  COALESCE        CONCAT          CONVERT_TZ
COS               COT             CURRENT_USER    DATE
DATE_ADD          DATE_SUB        DAYOFWEEK       DAY
DEGREES           EXTRACT         FLOOR           GREATEST
HOUR              IFNULL          LEAST           LOCATE
LOWER             LTRIM           MINUTE          MOD
MONTH             MSLEEP          NOW             NULLIF
OCTET_LENGTH      OPTIONAL_FIELD  PI              POSITION
POWER             RADIANS         RAND            REPLACE
ROUND             RTRIM           SECOND          SIN
SQRT              SUBSTRING_INDEX SUBSTR          TAN
TRIM              UPPER           USER            YEAR
STRING            SCHEMA          PART            LOCK
PATH              GET
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
