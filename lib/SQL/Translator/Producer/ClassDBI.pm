package SQL::Translator::Producer::ClassDBI;

# -------------------------------------------------------------------
# $Id: ClassDBI.pm,v 1.6 2003-04-25 23:08:01 allenday Exp $
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
$VERSION = sprintf "%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 1 unless defined $DEBUG;

use SQL::Translator::Utils qw(header_comment);
use Data::Dumper;

sub produce {
  my ($translator, $data) = @_;
  $DEBUG                  = $translator->debug;
  my $no_comments         = $translator->no_comments;

  my $create; 
  $create .= header_comment(__PACKAGE__, "## ") unless ($no_comments);

  $create .= "package " . $translator->format_package_name('DBI'). ";\n\n";

  $create .= "my \$USER = \'\';\n";
  $create .= "my \$PASS = \'\';\n\n";

  my $from = _from($translator->parser_type());

  $create .= "use base \'Class::DBI::" .$from. "\';\n\n";

  $create .= $translator->format_package_name('DBI'). "->set_db(\'Main', \'dbi:" .$from. ":_\', \$USER,\$PASS,);\n\n";
  $create .= "1;\n\n\n";

  for my $table (keys %{$data}) {
	my $table_data = $data->{$table};
	my @fields =  keys %{$table_data->{'fields'}};


	$create .= "##\n## Package: " .$translator->format_package_name($table). "\n##\n" unless $no_comments;
	$create .= "package ". $translator->format_package_name($table). ";\n";

	$create .= "use base \'Chado::DBI\';\n";
	$create .= "use mixin \'Class::DBI::Join\';\n";
	$create .= "use Class::DBI::Pager;\n\n";

	$create .= $translator->format_package_name($table). "->set_up_table('$table');\n\n";

	#
	# Primary key?
	#
	my @constraints;
	
	for my $constraint ( @{ $table_data->{'constraints'} } ) {
	  #my $name       = $constraint->{'name'} || '';
	  my $type       = $constraint->{'type'};
	  my $fields     = $constraint->{'fields'};
	  my $ref_table  = $constraint->{'reference_table'};
	  my $ref_fields = $constraint->{'reference_fields'};

	  if ( $type eq 'primary_key') {
		$create .= "sub " .$translator->format_pk_name($translator->format_package_name($table), $fields[0]). "{ shift->$fields[0] }\n\n";
	  }
			
	}

	#
	# Foreign key?
	#
	for (my $i = 0; $i < scalar(@fields); $i++) {
	  my $field = $fields[$i];
	  my $field_data = $table_data->{'fields'}->{$field}->{'constraints'};
	  my $type = $field_data->[1]->{'type'} || '';
	  my $ref_table = $field_data->[1]->{'reference_table'};
	  my $ref_fields = $field_data->[1]->{'reference_fields'};

#there is a bug here.  the method name is being created based on the field name in the foreign table.  if this
#differs from the field name in the local table (maybe called "x_fk" here, but "x" there), the method "x" will
#be created, and WILL NOT WORK.  this can be resolved, but i don't know the tabledata structure well enough to
#easily fix it... ken?  darren?
	  if ($type eq 'foreign_key') {
		$create .= $translator->format_package_name($table). "->hasa(" .$translator->format_package_name($ref_table). " => \'@$ref_fields\');\n";
		$create .= "sub " .$translator->format_fk_name($ref_table, @$ref_fields). "{ return shift->@$ref_fields }\n\n";
	  }
	}
	
	$create .= "1;\n\n\n";
  }
 
  return $create;
}


sub _from {
  my $from = shift;
  my @temp = split(/::/, $from);
  $from = $temp[$#temp];

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

SQL::Translator::Producer::ClassDBI - Translate SQL schemata into Class::DBI classes

=head1 SYNOPSIS

Use this producer as you would any other from SQL::Translator.  See
L<SQL::Translator> for details.

This package utilizes SQL::Translator's formatting methods
format_package_name(), format_pk_name(), format_fk_name(), and
format_table_name() as it creates classes, one per table in the schema
provided.  An additional base class is also created for database connectivity
configuration.  See L<Class::DBI> for details on how this works.

=head1 AUTHOR

Ying Zhang <zyolive@yahoo.com>, Allen Day <allenday@ucla.edu>
