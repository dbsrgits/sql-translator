#!/usr/bin/perl

# -------------------------------------------------------------------
# $Id: sqlt-dumper.pl,v 1.1 2003-06-24 03:24:02 kycl4rk Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Ken Y. Clark <kclark@cpan.org>
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

=head1 sqlt-dumper.pl - create a dumper script from a schema

=head1 DESCRIPTION

This script uses SQL::Translator to parse the SQL schema and
create a Perl script that can connect to the database and dump the 
data as INSERT statements a la mysqldump.

=head1 SYNOPSIS

  ./sqlt-dumper.pl -d Oracle [options] schema.sql > dumper.pl
  ./dumper.pl > data.sql

  Options:

    --add-truncate  Add "TRUNCATE TABLE" statements for each table

=cut

use strict;
use Pod::Usage;
use Getopt::Long;
use SQL::Translator;

my ( $db, $add_truncate );
GetOptions(
    'd:s'          => \$db,
    'add-truncate' => \$add_truncate,
);

my $file = shift @ARGV or pod2usage( -msg => 'No input file' );

my $t = SQL::Translator->new(
    from     => $db,
    filename => $file,
);

my $parser = $t->parser or die $t->error;
$parser->($t, $t->data);
my $schema = $t->schema;

my $out = <<"EOF";
#!/usr/bin/perl

use strict;
use DBI;

my \$db = DBI->connect('dbi:$db:', 'user', 'passwd');

EOF

for my $table ( $schema->get_tables ) {
    my $table_name  = $table->name;
    my ( @field_names, %types );
    for my $field ( $table->get_fields ) {
        $types{ $field->name } = $field->data_type =~ m/(char|str|long|text)/
            ? 'string' : 'number';
        push @field_names, $field->name;
    }

    $out .= join('',
        "#\n# Data for table '$table_name'\n#\n{\n",
        "    print \"#\\n# Data for table '$table_name'\\n#\\n\";\n",
    );

    my $insert = "INSERT INTO $table_name (". join(', ', @field_names).
            ') VALUES (';

    if ( $add_truncate ) {
        $out .= "    print \"TRUNCATE TABLE $table_name;\\n\";\n";
    }

    $out .= join('',
        "    my \%types = (\n",
        join("\n", map { "        $_ => '$types{ $_ }'," } @field_names), 
        "\n    );\n\n",
        "    my \$data  = \$db->selectall_arrayref(\n",
        "        'select ", join(', ', @field_names), " from $table_name',\n",
        "        { Columns => {} },\n",
        "    );\n\n",
        "    for my \$rec ( \@{ \$data } ) {\n",
        "        my \@vals;\n",
        "        for my \$fld ( qw[", join(' ', @field_names), "] ) {\n",
        "            my \$val = \$rec->{ \$fld };\n",
        "            if ( \$types{ \$fld } eq 'string' ) {\n",
        "                \$val =~ s/'/\\'/g;\n",
        "                \$val = defined \$val ? qq['\$val'] : qq[''];\n",
        "            }\n",
        "            else {\n",
        "                \$val = defined \$val ? \$val : 'NULL';\n",
        "            }\n",
        "            push \@vals, \$val;\n",
        "        }\n",
        "        print \"$insert\", join(', ', \@vals), \");\\n\";\n",
        "    }\n",
        "    print \"\\n\\n\";\n",
        "}\n\n",
    );
}

print $out;
