package SQL::Translator::Producer::ClassDBI;

# -------------------------------------------------------------------
# $Id: ClassDBI.pm,v 1.16 2003-06-19 01:18:07 kycl4rk Exp $
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
$VERSION = sprintf "%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 1 unless defined $DEBUG;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(header_comment);
use Data::Dumper;

sub produce {
    my $translator  = shift;
    local $DEBUG    = $translator->debug;
    my $no_comments = $translator->no_comments;
    my $schema      = $translator->schema;
	
    my $create; 
    $create .= header_comment(__PACKAGE__, "# ") unless ($no_comments);
	
    $create .= "package " . $translator->format_package_name('DBI'). ";\n\n";
	
    $create .= "my \$USER = '';\n";
    $create .= "my \$PASS = '';\n\n";
	
    my $from = _from($translator->parser_type());
	
    $create .= "use base 'Class::DBI::$from';\n\n" .
        $translator->format_package_name('DBI') . 
        "->set_db('Main', 'dbi:$from:_', \$USER, \$PASS);\n\n";
	
    #
    # Iterate over all tables
    #
    for my $table ( $schema->get_tables ) {
        my $table_name = $table->name or next;
        my %pk;

        unless ( $no_comments ) {
            $create .=
                "#\n# Package: " .
                $translator->format_package_name($table_name).
                "\n#\n"
        }

        $create .= "package ".
            $translator->format_package_name($table_name).";\n";
		$create .= "use base '".$translator->format_package_name('DBI')."';\n";
        $create .= "use mixin 'Class::DBI::Join';\n";
        $create .= "use Class::DBI::Pager;\n\n";
        $create .= $translator->format_package_name($table_name).
            "->set_up_table('$table_name');\n\n";
		
        #
        # Primary key?
        #
        foreach my $constraint ( $table->get_constraints ) {
            next unless $constraint->type eq PRIMARY_KEY;
            my $field = ($constraint->fields)[0];
			
            $pk{ $table_name } = $field;
            $create .= "sub " .$translator->format_pk_name(
                $translator->format_package_name( $table_name ),
                $field
            ) . " { shift->".$field." }\n\n";
        }
		
        #
        # Find foreign keys
        #
        foreach my $field ( $table->get_fields ) {
            if ( $field->is_foreign_key ) {
                my $field_name = $field->name;
                my $fk         = $field->foreign_key_reference;
                my $ref_table  = $fk->reference_table;
                my @ref_fields = $fk->reference_fields;
                my @fields     = $fk->fields;

              $create .= $translator->format_package_name($table_name). 
                    "->has_a(\n    " .
                    $translator->format_package_name($ref_table). 
                    " => '$field_name'\n);\n\n";
              $create .= "sub " .
                    $translator->format_fk_name($ref_table, $field_name).
                    " {\n    return shift->$field_name\n}\n\n";
            }
        }

		#
		# Identify link tables, defined as tables that have only PK and FK
		# fields
		#
		my %linkable;
        foreach my $table ( $schema->get_tables) {
            my $is_link = 1;
            foreach my $field ($table->get_fields){
                unless ( $field->is_primary_key or $field->is_foreign_key ) {
                    $is_link = 0;
                    last;
                }
            }
  		  
            if ( $is_link ) {
                foreach my $left ( $table->get_fields ) {
                    next unless $left->is_foreign_key and 
                    $schema->get_table (
                        $left->foreign_key_reference->reference_table
                    )->get_field(
                        ($left->foreign_key_reference->reference_fields)[0]
                    )->is_primary_key;
                  
                    foreach my $right ( $table->get_fields ) {
                        #skip the diagonal
                        next if $left->name eq $right->name;
                        next unless $right->is_foreign_key and
                            $schema->get_table(
                                $right->foreign_key_reference->reference_table
                            )->get_field(
                            ($right->foreign_key_reference->reference_fields)[0]
                            )->is_primary_key;
                    
                        $linkable{
                            $left->foreign_key_reference->reference_table
                        }{
                            $right->foreign_key_reference->reference_table
                        } = $table;

                        $linkable{
                            $right->foreign_key_reference->reference_table
                        }{
                            $left->foreign_key_reference->reference_table
                        } = $table;
    
#                if($left->foreign_key_reference->reference_table eq 'feature' and
#                   $right->foreign_key_reference->reference_table eq 'pub'){
#                  warn $left->foreign_key_reference->reference_table . " to " . $right->foreign_key_reference->reference_table . " via " . $table->name;
#                  warn "\tleft:  ".$left->name;
#                  warn "\tright: ".$right->name;
#              }
                  }
    			}
            }
		}


		#
		# Generate many-to-many linking methods for data tables
		#
		my $is_data = 0;
        for ( $table->get_fields ) {
		    $is_data++ if !$_->is_foreign_key and !$_->is_primary_key;
        } 

		my %linked;
		if ( $is_data ) {
            foreach my $link ( keys %{ $linkable{ $table->name } } ) {
                my $linkmethodname = 
                   "_". $translator->format_fk_name($table->name,$link)."_refs";


                $create .= $translator->format_package_name($table->name).
                    "->has_many('$linkmethodname','".
                    $translator->format_package_name(
                        $linkable{ $table->name }{ $link }->name
                    ) . "','" . $link . "');\n";

                $create .= "sub ". $translator->format_fk_name($table,$link).
                    # HARDCODED 's' HERE.  ADD CALLBACK 
                    # FOR PLURALIZATION MANGLING
                    "s {\n    my \$self = shift; return map \$_->".$link.
                    ", \$self->".$linkmethodname.";\n}\n\n";
            }
        }
    }

    $create .= '1;';

    return $create;
}

sub _from {
    my $from = shift;
    my @temp = split(/::/, $from);
    $from    = $temp[$#temp];

    if ( $from eq 'MySQL') {
        $from = lc($from);
    } elsif ( $from eq 'PostgreSQL') {
        $from = 'Pg';
    } elsif ( $from eq 'Oracle') {
        $from = 'Oracle';
    } else {
        die "__PACKAGE__ can't handle vendor $from";
    }

    return $from;
}

1;

__END__

=head1 NAME

SQL::Translator::Producer::ClassDBI - 
    Translate SQL schemata into Class::DBI classes

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
