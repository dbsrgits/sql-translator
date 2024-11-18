package SQL::Translator::Schema::View;

=pod

=head1 NAME

SQL::Translator::Schema::View - SQL::Translator view object

=head1 SYNOPSIS

  use SQL::Translator::Schema::View;
  my $view   = SQL::Translator::Schema::View->new(
      name   => 'foo',                      # name, required
      sql    => 'select id, name from foo', # SQL for view
      fields => 'id, name',                 # field names in view
  );

=head1 DESCRIPTION

C<SQL::Translator::Schema::View> is the view object.

=head1 METHODS

=cut

use Moo;
use SQL::Translator::Utils qw(ex2err);
use SQL::Translator::Types qw(schema_obj);
use SQL::Translator::Role::ListAttr;
use Sub::Quote qw(quote_sub);

extends 'SQL::Translator::Schema::Object';

our $VERSION = '1.66';

=head2 new

Object constructor.

  my $view = SQL::Translator::Schema::View->new;

=head2 fields

Gets and set the fields the constraint is on.  Accepts a string, list or
arrayref; returns an array or array reference.  Will unique the field
names and keep them in order by the first occurrence of a field name.

  $view->fields('id');
  $view->fields('id', 'name');
  $view->fields( 'id, name' );
  $view->fields( [ 'id', 'name' ] );
  $view->fields( qw[ id name ] );

  my @fields = $view->fields;

=cut

with ListAttr fields => (uniq => 1);

=head2 tables

Gets and set the tables the SELECT mentions.  Accepts a string, list or
arrayref; returns an array or array reference.  Will unique the table
names and keep them in order by the first occurrence of a field name.

  $view->tables('foo');
  $view->tables('foo', 'bar');
  $view->tables( 'foo, bar' );
  $view->tables( [ 'foo', 'bar' ] );
  $view->tables( qw[ foo bar ] );

  my @tables = $view->tables;

=cut

with ListAttr tables => (uniq => 1);

=head2 options

Gets or appends a list of options on the view.

  $view->options('ALGORITHM=UNDEFINED');

  my @options = $view->options;

=cut

with ListAttr options => (uniq => 1, append => 1);

sub is_valid {

=pod

=head2 is_valid

Determine whether the view is valid or not.

  my $ok = $view->is_valid;

=cut

  my $self = shift;

  return $self->error('No name') unless $self->name;
  return $self->error('No sql')  unless $self->sql;

  return 1;
}

=head2 name

Get or set the view's name.

  my $name = $view->name('foo');

=cut

has name => (is => 'rw', default => quote_sub(q{ '' }));

=head2 order

Get or set the view's order.

  my $order = $view->order(3);

=cut

has order => (is => 'rw', default => quote_sub(q{ 0 }));

around order => sub {
  my ($orig, $self, $arg) = @_;

  if (defined $arg && $arg =~ /^\d+$/) {
    return $self->$orig($arg);
  }

  return $self->$orig;
};

=head2 sql

Get or set the view's SQL.

  my $sql = $view->sql('select * from foo');

=cut

has sql => (is => 'rw', default => quote_sub(q{ '' }));

=head2 schema

Get or set the view's schema object.

  $view->schema( $schema );
  my $schema = $view->schema;

=cut

has schema => (is => 'rw', isa => schema_obj('Schema'), weak_ref => 1);

around schema => \&ex2err;

=head2 equals

Determines if this view is the same as another

  my $isIdentical = $view1->equals( $view2 );

=cut

around equals => sub {
  my $orig             = shift;
  my $self             = shift;
  my $other            = shift;
  my $case_insensitive = shift;
  my $ignore_sql       = shift;

  return 0 unless $self->$orig($other);
  return 0
      unless $case_insensitive
      ? uc($self->name) eq uc($other->name)
      : $self->name eq $other->name;

  #return 0 unless $self->is_valid eq $other->is_valid;

  unless ($ignore_sql) {
    my $selfSql  = $self->sql;
    my $otherSql = $other->sql;

    # Remove comments
    $selfSql  =~ s/--.*$//mg;
    $otherSql =~ s/--.*$//mg;

    # Collapse whitespace to space to avoid whitespace comparison issues
    $selfSql  =~ s/\s+/ /sg;
    $otherSql =~ s/\s+/ /sg;
    return 0 unless $selfSql eq $otherSql;
  }

  my $selfFields  = join(":", $self->fields);
  my $otherFields = join(":", $other->fields);
  return 0
      unless $case_insensitive
      ? uc($selfFields) eq uc($otherFields)
      : $selfFields eq $otherFields;
  return 0
      unless $self->_compare_objects(scalar $self->extra, scalar $other->extra);
  return 1;
};

# Must come after all 'has' declarations
around new => \&ex2err;

1;

=pod

=head1 AUTHOR

Ken Youens-Clark E<lt>kclark@cpan.orgE<gt>.

=cut
