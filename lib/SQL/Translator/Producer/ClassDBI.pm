package SQL::Translator::Producer::ClassDBI;

# -------------------------------------------------------------------
# $Id: ClassDBI.pm,v 1.10 2003-06-09 03:38:38 allenday Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ying Zhang <zyolive@yahoo.com>,
#                    Allen Day <allenday@ucla.edu>,
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
$VERSION = sprintf "%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 1 unless defined $DEBUG;

use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils qw(header_comment);
use Data::Dumper;

sub produce {
    my ($translator, $data) = @_;
    local $DEBUG            = $translator->debug;
    my $no_comments         = $translator->no_comments;
    my $schema              = $translator->schema;
	
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
	# Identify link tables, defined as tables that have only PK and FK
	# fields
	#
	my %linkable;
	foreach my $table ($schema->get_tables) {
	  my $is_link = 1;
	  foreach my $field ($table->get_fields){
		$is_link = 0 and last unless $field->is_primary_key or $field->is_foreign_key;
	  }

	  if($is_link){
		foreach my $left ($table->get_fields){
		  next unless $left->is_foreign_key;
		  foreach my $right ($table->get_fields){
			next unless $right->is_foreign_key;

			$linkable{$left->foreign_key_reference->reference_table}
			  {$right->foreign_key_reference->reference_table} = $table;
			$linkable{$right->foreign_key_reference->reference_table}
			  {$left->foreign_key_reference->reference_table} = $table;
		  }
		}
	  }

	}

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

        $create .= "package ".$translator->format_package_name($table_name).";\n";
		$create .= "use base ".$translator->format_package_name('DBI').";\n";
        $create .= "use mixin 'Class::DBI::Join';\n";
        $create .= "use Class::DBI::Pager;\n\n";
		
        $create .= $translator->format_package_name($table_name)."->set_up_table('$table_name');\n\n";
		
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

		my $is_data = 0;
		map {(!$_->is_foreign_key and !$_->is_primary_key) ? $is_data++ : 0} $table->get_fields;
		if($is_data){
		  my %linked;
		  foreach my $field ( $table->get_fields ) {
			if($field->is_foreign_key){
			  my $fk = $field->foreign_key_reference;

#			  next if $linked{($fk->reference_fields)[0]};
			  next unless $linkable{$fk->reference_table};

			  foreach my $link (keys %{$linkable{$fk->reference_table}}){
				my $linkmethodname = "_".$translator->format_fk_name($fk->reference_table,$field->name)."_refs";

				next if $linked{$linkmethodname};

				$create .= $translator->format_package_name($table_name).
				  "->has_many('$linkmethodname','".
				  $translator->format_package_name($linkable{$fk->reference_table}{$link}->name)."','".
				  ($fk->reference_fields)[0]."');\n";
				$create .= "sub ". $translator->format_fk_name($fk->reference_table,$field->name).
####HARDCODED S HERE.  ADD CALLBACK FOR PLURALIZATION MANGLING
				  "s {\n    my \$self = shift; return map \$_->".($fk->reference_fields)[0].", \$self->".$linkmethodname.";\n}\n\n";

				$linked{$linkmethodname}++;
			  }
			}
		  }
		}

    }

    $create .= '1;';

#    for my $table (keys %{$data}) {
#        my $table_data = $data->{$table};
#        my @fields =  keys %{$table_data->{'fields'}};
#        my %pk;
#
#        $create .= "##\n## Package: " .$translator->format_package_name($table). "\n##\n" unless $no_comments;
#        $create .= "package ". $translator->format_package_name($table). ";\n";
#
#        $create .= "use base \'Chado::DBI\';\n";
#        $create .= "use mixin \'Class::DBI::Join\';\n";
#        $create .= "use Class::DBI::Pager;\n\n";
#
#        $create .= $translator->format_package_name($table). "->set_up_table('$table');\n\n";
#
#        #
#        # Primary key?
#        #
#        foreach my $constraint ( @{ $table_data->{'constraints'} } ) {
#          my $name       = $constraint->{'name'} || '';
#          my $type       = $constraint->{'type'};
#          my $ref_table  = $constraint->{'reference_table'};
#          my $ref_fields = $constraint->{'reference_fields'};
#
#          if ( $type eq 'primary_key') {
#            $pk{$table} = $constraint->{'fields'}->[0];
#            $create .= "sub " .$translator->format_pk_name(
#                                                           $translator->format_package_name($table),
#                                                           $constraint->{'fields'}->[0]
#                                                          ) . " { shift->".$constraint->{'fields'}->[0]." }\n\n";
#          }
#        }
#
#        #
#        # Foreign key?
#        #
#        foreach my $field (@fields){
#          my $field_data = $table_data->{'fields'}->{$field}->{'constraints'};
#          my $type = $field_data->[1]->{'type'} || '';
#          my $ref_table = $field_data->[1]->{'reference_table'};
#          my $ref_field = $field_data->[1]->{'reference_fields'}->[0];
#          my $field = $field_data->[1]->{'fields'}->[0];
#
#          if ($type eq 'foreign_key') {
#
#    #THIS IS IMPOSSIBLE UNTIL WE HAVE A BETTER DATA MODEL.  THIS GIANT HASH SUCKS !!!
#    #         my $r_link     = 0; #not a link table (yet)
#    #         my $r_linkthis = 0;
#    #         my $r_linkthat = 0;
#    #         my $r_linkdata = 0;
#    #         my $r_table = $data->{$ref_table};
#    #         my @r_fields = keys %{$r_table->{'fields'}};
#    #         foreach my $r_field ( keys %{$r_table->{'fields'}} ){
#    #           $r_linkthis++ and next if $r_field eq $ref_field; #remote table links to local table
#    #           if($r_table->{'fields'}->{$r_field}->{'constraints'}){
#
#    #             foreach my $r_constraint ($r_table->{'fields'}->{$r_field}->{'constraints'}){
#    #               $create .= Dumper($r_constraint);
#    #             }
#
#    #           } else {
#    #             $r_linkdata++; #if not constraints, assume it's data (safe?)
#    #           }
#    #           foreach my $r_constraint ( @{ $r_table->{'fields'}->{$r_field}->{'constraints'} } ) {
#    #             next unless $r_constraint->{'constraint_type'} eq 'foreign_key';
#
#    #             $r_linkthat++ unless $r_constraint->{'reference_table'} eq $table; #remote table links to non-local table
#    #           }
#    #         }
#
#    #        my $link = $r_linkthis && $r_linkthat && !$r_linkdata ? '_link' : '';
#            $create .= $translator->format_package_name($table). "->has_a(" .$translator->format_package_name($ref_table). " => \'$field\');\n";
#            $create .= "sub " .$translator->format_fk_name($ref_table, $field)." { return shift->$field }\n\n";
#          }
#        }
#
#    #THIS IS IMPOSSIBLE UNTIL WE HAVE A BETTER DATA MODEL.  THIS GIANT HASH SUCKS !!!
#    #     #
#    #     # Remote foreign key?
#    #     #
#    #     print "****$table\n";
#    #     # find tables that refer to this table
#    #     my %refers = ();
#    #     for my $remote_table (keys %{$data}){
#    #       next if $remote_table eq $table;
#    # #      print "********".$remote_table."\n";
#    #       my $remote_table_data = $data->{$remote_table};
#
#    #       foreach my $remote_field ( keys %{$remote_table_data->{'fields'}} ){
#    #         foreach my $remote_constraint ( @{ $remote_table_data->{'fields'}->{$remote_field}->{'constraints'} } ) {
#    #           next unless $remote_constraint->{'constraint_type'} eq 'foreign_key'; #only interested in foreign keys...
#
#    #           $refers{$remote_table} = 1 if $pk{$remote_constraint->{'reference_table'}} ;#eq $remote_constraint->{'reference_fields'}->[0];
#    #            }
#    #       }
#    #     }
#
#    #     foreach my $refer (keys %refers){
#    #       foreach my $refer_field ( keys %{$data->{$refer}->{'fields'}} ){
#    #         foreach my $refer_constraint ( @{ $data->{$refer}->{'fields'}->{$refer_field}->{'constraints'} } ) {
#    #           next unless $refer_constraint->{'constraint_type'} eq 'foreign_key'; #only interested in foreign keys...
#    #           next if $refer_constraint->{'reference_table'} eq $table; #don't want to consider the current table vs itself
#    #           print "********".$refer."\t".$refer_field."\t****\t".$refer_constraint->{'reference_table'}."\t".$refer_constraint->{'reference_fields'}->[0]."\n";
#
#    #           $create .= "****sub " .$translator->format_fk_name($refer_constraint->{'reference_table'}, $refer_constraint->{'reference_fields'}->[0]). " { return shift->".$refer_constraint->{'reference_fields'}->[0]." }\n\n";
#    #         }
#    #       }
#    #     }
#
#        $create .= "1;\n\n\n";
#    }

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

Ying Zhang E<lt>zyolive@yahoo.comE<gt>, 
Allen Day E<lt>allenday@ucla.eduE<gt>
Ken Y. Clark E<lt>kclark@cpan.org<gt>.
