package SQL::Translator::Producer::SQLServer;

use strict;
use warnings;
our ( $DEBUG, $WARN );
our $VERSION = '1.59';
$DEBUG = 1 unless defined $DEBUG;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(debug header_comment);
use SQL::Translator::Generator::DDL::SQLServer;

sub produce {
  my $translator = shift;
  SQL::Translator::Generator::DDL::SQLServer->new(
    add_comments    => !$translator->no_comments,
    add_drop_tables => $translator->add_drop_table,
  )->schema($translator->schema)
}

sub rename_table {
   my ($old, $new) = @_;;

   q(EXEC sp_rename ') . $old->name . q(', ') . $new->name . q(')
}

sub alter_drop_constraint {
    my ($constraint, $options) = @_;
    my $table_name_q= $constraint->table->name;
    my $ct_name_q= $constraint->name;
    return "ALTER TABLE $table_name_q DROP CONSTRAINT $ct_name_q;";
}

sub alter_drop_index {
    my ($index, $options) = @_;
    my $table_name_q= $index->table->name;
    my $index_name_q= $index->name;
    return "ALTER TABLE $table_name_q DROP $index_name_q";
}

sub alter_field {
    my ($from_field, $to_field, $options) = @_;

    my $field_clause= build_field_clause($to_field, $options);
    my $table_name_q= $to_field->table->name;

    my @sql;
    if (lc($from_field->data_type) eq 'enum') {
        push @sql, build_drop_enum_constraint($from_field, $options).';';
    }

    push @sql, "ALTER TABLE $table_name_q ALTER COLUMN $field_clause;";

    if ($from_field->name ne $to_field->name) {
        push @sql, rename_field(@_);
    }

    if (lc($to_field->data_type) eq 'enum') {
        push @sql, build_add_enum_constraint($to_field, $options).';';
    }

    return join("\n", @sql);
}

sub rename_field {
   q(EXEC sp_rename ') . $_[0]->name . q(', ') . $_[1]->name . q(', 'COLUMN')
}

sub alter_create_index {
    my ($index, $options) = @_;
    my ($stmt, $clause)= build_index_stmt(@_);
    return $stmt.';';
}

sub build_index_stmt {
    my ($index, $options)= @_;
    my $table_name_q = $index->table->name;
    my $idx_name_q   = $index->name;
    my $field_list   = join(', ', $index->fields );

    my $stmt= "CREATE UNIQUE NONCLUSTERED INDEX $idx_name_q" .
              " ON $table_name_q ($field_list)";
    return $stmt, undef;
}

sub build_constraint_stmt {
   my $c = shift;

   if ($c->type eq PRIMARY_KEY ) {
      return SQL::Translator::Generator::DDL::SQLServer->new->primary_key_constraint($c)
   } elsif ($c->type eq UNIQUE ) {
      return SQL::Translator::Generator::DDL::SQLServer->new->unique_constraint_single($c)
   }
}

sub drop_table { 'DROP TABLE ' . $_[0]->name }

sub alter_create_constraint {
    my ($constraint, $options) = @_;
    my ($stmt, $clause)= build_constraint_stmt(@_);
    return $stmt.';';
}

sub build_enum_constraint {
    my ($field, $options)= @_;
    my %extra = $field->extra;
    my $list = $extra{'list'} || [];
    # \todo deal with embedded quotes
    my $commalist = join( ', ', map { qq['$_'] } @$list );
    my $field_name_q = $field->name;
    my $check_name_q =  $field->table->name . '_' . $field->name . '_chk';
    return "CONSTRAINT $check_name_q CHECK ($field_name_q IN ($commalist))";
}
sub build_drop_enum_constraint {
    my ($field, $options)= @_;
    my $table_name_q = $field->table->name;
    my $check_name_q = $field->table->name . '_' . $field->name . '_chk';
    return "ALTER TABLE $table_name_q DROP $check_name_q";
}

sub build_add_enum_constraint {
    my ($field, $options)= @_;
    my $table_name_q = $field->table->name;
    return "ALTER TABLE $table_name_q ADD ".build_enum_constraint(@_);
}

sub build_field_clause {
   SQL::Translator::Generator::DDL::SQLServer->new->field(shift)
}

sub add_field {
    my ($new_field, $options) = @_;

    my $field_clause = build_field_clause($new_field);
    my $table_name_q= $new_field->table->name;

    my @sql= "ALTER TABLE $table_name_q ADD $field_clause;";
    if (lc($new_field->data_type) eq 'enum') {
        push @sql, build_add_enum_constraint($new_field, $options).';';
    }

    return join("\n", @sql);
}

sub drop_field {
    my ($old_field, $options) = @_;

    my $table_name_q= $old_field->table->name;
    my $field_name_q= $old_field->name;

    my @sql;
    if (lc($old_field->data_type) eq 'enum') {
        push @sql, build_drop_enum_constraint($old_field, $options).';';
    }

    push @sql, "ALTER TABLE $table_name_q DROP $field_name_q;";

    return join("\n", @sql);
}

1;

=head1 NAME

SQL::Translator::Producer::SQLServer - MS SQLServer producer for SQL::Translator

=head1 SYNOPSIS

  use SQL::Translator;

  my $t = SQL::Translator->new( parser => '...', producer => 'SQLServer' );
  $t->translate;

=head1 DESCRIPTION

This is currently a thin wrapper around the nextgen
L<SQL::Translator::Generator::DDL::SQLServer> DDL maker.

=head1 Extra Attributes

=over 4

=item field.list

List of values for an enum field.

=back

=head1 TODO

 * !! Write some tests !!
 * Reserved words list needs updating to SQLServer.
 * Triggers, Procedures and Views DO NOT WORK


    # Text of view is already a 'create view' statement so no need to
    # be fancy
    foreach ( $schema->get_views ) {
        my $name = $_->name();
        $output .= "\n\n";
        $output .= "--\n-- View: $name\n--\n\n" unless $no_comments;
        my $text = $_->sql();
        $text =~ s/\r//g;
        $output .= "$text\nGO\n";
    }

    # Text of procedure already has the 'create procedure' stuff
    # so there is no need to do anything fancy. However, we should
    # think about doing fancy stuff with granting permissions and
    # so on.
    foreach ( $schema->get_procedures ) {
        my $name = $_->name();
        $output .= "\n\n";
        $output .= "--\n-- Procedure: $name\n--\n\n" unless $no_comments;
        my $text = $_->sql();
      $text =~ s/\r//g;
        $output .= "$text\nGO\n";
    }

=head1 SEE ALSO

L<SQL::Translator>

=head1 AUTHORS

See the included AUTHORS file:
L<http://search.cpan.org/dist/SQL-Translator/AUTHORS>

=head1 COPYRIGHT

Copyright (c) 2012 the SQL::Translator L</AUTHORS> as listed above.

=head1 LICENSE

This code is free software and may be distributed under the same terms as Perl
itself.

=cut
