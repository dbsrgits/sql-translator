package SQL::Translator::Producer::ClassDBI;

# -------------------------------------------------------------------
# $Id: ClassDBI.pm,v 1.20 2003-06-25 18:47:45 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Allen Day <allenday@ucla.edu>,
#                    Ying Zhang <zyolive@yahoo.com>
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

use strict;
use vars qw[ $VERSION $DEBUG ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.20 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 1 unless defined $DEBUG;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(header_comment);
use Data::Dumper;

my %CDBI_auto_pkgs = (
    MySQL      => 'mysql',
    PostgreSQL => 'Pg',
    Oracle     => 'Oracle',
);

# -------------------------------------------------------------------
sub produce {
    my $translator    = shift;
    local $DEBUG      = $translator->debug;
    my $no_comments   = $translator->no_comments;
    my $schema        = $translator->schema;
    my $args          = $translator->producer_args;
    my $db_user       = $args->{'db_user'} || '';
    my $db_pass       = $args->{'db_pass'} || '';
    my $dsn           = $args->{'dsn'}     || 'dbi:$from:_';
    my $main_pkg_name = $translator->format_package_name('DBI');
    my $header        = header_comment(__PACKAGE__, "# ");
    my $sep           = '# ' . '-' x 67;

    my $parser_type   = ( split /::/, $translator->parser_type )[-1];
    my $from          = $CDBI_auto_pkgs{ $parser_type } || '';
    
    #
    # Iterate over all tables
    #
    my ( %packages, $order );
    for my $table ( $schema->get_tables ) {
        my $table_name = $table->name or next;

        my $table_pkg_name = $translator->format_package_name($table_name);
        $packages{ $table_pkg_name } = {
            order     => ++$order,
            pkg_name  => $table_pkg_name,
            base      => $main_pkg_name,
            table     => $table_name,
        };

        #
        # Primary key may have a differenct accessor method name
        #
        if ( my $pk_xform = $translator->format_pk_name ) {
            if ( my $constraint = $table->primary_key ) {
                my $field          = ($constraint->fields)[0];
                my $pk_name        = $pk_xform->($table_pkg_name, $field);
                
                $packages{ $table_pkg_name }{'pk_accessor'} = 
                    "#\n# Primary key accessor\n#\n".
                    "sub $pk_name {\n    shift->$field\n}\n"
                ;
            }
        }
        
        #
        # Use foreign keys to set up "has_a/has_many" relationships.
        #
        foreach my $field ( $table->get_fields ) {
            if ( $field->is_foreign_key ) {
                my $table_name = $table->name;
                my $field_name = $field->name;
                my $fk         = $field->foreign_key_reference;
                my $ref_table  = $fk->reference_table;
                my $ref_pkg    = $translator->format_package_name($ref_table);
                my $ref_fld    = 
                    $translator->format_fk_name($ref_table, $field_name);

                push @{ $packages{ $table_pkg_name }{'has_a'} },
                    "$table_pkg_name->has_a(\n".
                    "    $field_name => '$ref_pkg'\n);\n\n".
                    "sub $ref_fld {\n".
                    "    return shift->$field_name\n}\n\n"
                ;

                #
                # If this table "has a" to the other, then it follows 
                # that the other table "has many" of this one, right?
                #
                push @{ $packages{ $ref_pkg }{'has_many'} },
                    "$ref_pkg->has_many(\n    '$table_name', ".
                    "'$table_pkg_name' => '$field_name'\n);\n\n"
                ;
            }
        }

        #
        # Identify link tables, defined as tables that have 
        # only PK and FK fields.
        #
#        my %linkable;
#        my %linktable;
#        foreach my $table ( $schema->get_tables ) {
#            my $is_link = 1;
#            foreach my $field ( $table->get_fields ) {
#                unless ( $field->is_primary_key or $field->is_foreign_key ) {
#                    $is_link = 0; 
#                    last;
#                }
#            }
#          
#            if ( $is_link ) {
#                foreach my $left ( $table->get_fields ) {
#                    next unless $left->is_foreign_key and $schema->get_table(
#                        $left->foreign_key_reference->reference_table
#                    );
#
#                    next unless $left->is_foreign_key and $schema->get_table(
#                        $left->foreign_key_reference->reference_table
#                    )->get_field(
#                        ($left->foreign_key_reference->reference_fields)[0]
#                    )->is_primary_key;
#              
#                    foreach my $right ( $table->get_fields ) {
#                        #skip the diagonal
#                        next if $left->name eq $right->name;
#
#                        next unless $right->is_foreign_key and 
#                            $schema->get_table(
#                                $right->foreign_key_reference->reference_table
#                            )
#                        ;
#                
#                        next unless $right->is_foreign_key and
#                            $schema->get_table(
#                                $right->foreign_key_reference->reference_table
#                            )->get_field(
#                            ($right->foreign_key_reference->reference_fields)[0]
#                            )->is_primary_key
#                        ;
#                
#                
#                        $linkable{
#                            $left->foreign_key_reference->reference_table
#                        }{
#                            $right->foreign_key_reference->reference_table
#                        } = $table;
#
#                        $linkable{
#                            $right->foreign_key_reference->reference_table
#                        }{
#                            $left->foreign_key_reference->reference_table
#                        } = $table;
#
#                        $linktable{ $table->name } = $table;
#                    }
#                }
#            }
#        }
#
#        #
#        # Generate many-to-many linking methods for data tables
#        #
#        my $is_data = 0;
#        for ( $table->get_fields ) {
#            $is_data++ if !$_->is_foreign_key and !$_->is_primary_key;
#        }
#
#        my %linked;
#        if ( $is_data ) {
#            foreach my $link ( keys %{ $linkable{ $table->name } } ) {
#                my $linkmethodname = 
#                    "_".$translator->format_fk_name($table->name,$link)."_refs"
#                ;
#
#                $create .= $translator->format_package_name($table->name).
#                    "->has_many('$linkmethodname','".
#                    $translator->format_package_name(
#                        $linkable{$table->name}{$link}->name
#                    )."','".
#                    ($schema->get_table($link)->primary_key->fields)[0]."');\n"
#                ;
#
#                $create .= "sub ". $translator->format_fk_name($table,$link).
#                    # HARDCODED 's' HERE.  
#                    # ADD CALLBACK FOR PLURALIZATION MANGLING
#                    "s {\n    my \$self = shift; return map \$_->".$link.
#                    ", \$self->".$linkmethodname.";\n}\n\n"
#                ;
#            }
#        }
    }

    my $base_pkg = sprintf( 'Class::DBI%s', $from ? "::$from" : '' );
    my $create = join("\n",
        "package $main_pkg_name;\n",
        $header,
        "use strict;",
        "use base '$base_pkg';\n",
        "$main_pkg_name->set_db('Main', '$dsn', '$db_user', '$db_pass');\n\n",
    ); 

    for my $pkg_name ( 
        sort { $packages{ $a }{'order'} <=> $packages{ $b }{'order'} }
        keys %packages
    ) {
        my $pkg = $packages{ $pkg_name };

        $create .= join("\n",
            $sep,
            "package ".$pkg->{'pkg_name'}.";",
            "use base '".$pkg->{'base'}."';",
            "use Class::DBI::Pager;\n\n",
        );    

        if ( $from ) {
            $create .= 
                $pkg->{'pkg_name'}."->set_up_table('".$pkg->{'table'}."');\n\n";
        }
        else {
            my $table       = $schema->get_table( $pkg->{'table'} );
            my @field_names = map { $_->name } $table->get_fields;

            $create .= join("\n",
                $pkg_name."->table('".$pkg->{'table'}."');\n",
                $pkg_name."->columns(All => qw/".
                join(' ', @field_names)."/);\n\n",
            );
        }

        if ( my $pk = $pkg->{'pk_accessor'} ) {
            $create .= $pk;
        }

        if ( my @has_a = @{ $pkg->{'has_a'} || [] } ) {
            $create .= $_ for @has_a;
        }

        if ( my @has_many = @{ $pkg->{'has_many'} || [] } ) {
            $create .= $_ for @has_many;
        }
    }

    $create .= "1;\n";

    return $create;
}

1;

# -------------------------------------------------------------------

=pod

=head1 NAME

SQL::Translator::Producer::ClassDBI - create Class::DBI classes from schema

=head1 SYNOPSIS

Use this producer as you would any other from SQL::Translator.  See
L<SQL::Translator> for details.

This package utilizes SQL::Translator's formatting methods
format_package_name(), format_pk_name(), format_fk_name(), and
format_table_name() as it creates classes, one per table in the schema
provided.  An additional base class is also created for database connectivity
configuration.  See L<Class::DBI> for details on how this works.

=head1 AUTHORS

Allen Day E<lt>allenday@ucla.eduE<gt>
Ying Zhang E<lt>zyolive@yahoo.comE<gt>,
Ken Y. Clark E<lt>kclark@cpan.org<gt>.
