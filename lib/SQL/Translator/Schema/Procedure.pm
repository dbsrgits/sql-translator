package SQL::Translator::Schema::Procedure;

=pod

=head1 NAME

SQL::Translator::Schema::Procedure - SQL::Translator procedure object

=head1 SYNOPSIS

  use SQL::Translator::Schema::Procedure;
  my $procedure  = SQL::Translator::Schema::Procedure->new(
      name       => 'foo',
      sql        => 'CREATE PROC foo AS SELECT * FROM bar',
      parameters => 'foo,bar',
      owner      => 'nomar',
      comments   => 'blah blah blah',
      schema     => $schema,
  );

=head1 DESCRIPTION

C<SQL::Translator::Schema::Procedure> is a class for dealing with
stored procedures (and possibly other pieces of nameable SQL code?).

=head1 METHODS

=cut

use Moo;
use SQL::Translator::Utils qw(ex2err);
use SQL::Translator::Role::ListAttr;
use SQL::Translator::Types qw(schema_obj);
use Sub::Quote qw(quote_sub);

extends 'SQL::Translator::Schema::Object';

our $VERSION = '1.59';

=head2 new

Object constructor.

  my $schema = SQL::Translator::Schema::Procedure->new;

=cut

=head2 parameters

Gets and set the parameters of the stored procedure.

  $procedure->parameters('id');
  $procedure->parameters('id', 'name');
  $procedure->parameters( 'id, name' );
  $procedure->parameters( [ 'id', 'name' ] );
  $procedure->parameters( qw[ id name ] );

  my @parameters = $procedure->parameters;

=cut

with ListAttr parameters => ( uniq => 1 );

=head2 name

Get or set the procedure's name.

  $procedure->name('foo');
  my $name = $procedure->name;

=cut

has name => ( is => 'rw', default => quote_sub(q{ '' }) );

=head2 sql

Get or set the procedure's SQL.

  $procedure->sql('select * from foo');
  my $sql = $procedure->sql;

=cut

has sql => ( is => 'rw', default => quote_sub(q{ '' }) );

=head2 order

Get or set the order of the procedure.

  $procedure->order( 3 );
  my $order = $procedure->order;

=cut

has order => ( is => 'rw' );


=head2 owner

Get or set the owner of the procedure.

  $procedure->owner('nomar');
  my $sql = $procedure->owner;

=cut

has owner => ( is => 'rw', default => quote_sub(q{ '' }) );

=head2 comments

Get or set the comments on a procedure.

  $procedure->comments('foo');
  $procedure->comments('bar');
  print join( ', ', $procedure->comments ); # prints "foo, bar"

=cut

has comments => (
    is => 'rw',
    coerce => quote_sub(q{ ref($_[0]) eq 'ARRAY' ? $_[0] : [$_[0]] }),
    default => quote_sub(q{ [] }),
);

around comments => sub {
    my $orig     = shift;
    my $self     = shift;
    my @comments = ref $_[0] ? @{ $_[0] } : @_;

    for my $arg ( @comments ) {
        $arg = $arg->[0] if ref $arg;
        push @{ $self->$orig }, $arg if defined $arg && $arg;
    }

    return wantarray ? @{ $self->$orig } : join( "\n", @{ $self->$orig } );
};

=head2 schema

Get or set the procedures's schema object.

  $procedure->schema( $schema );
  my $schema = $procedure->schema;

=cut

has schema => ( is => 'rw', isa => schema_obj('Schema'), weak_ref => 1 );

around schema => \&ex2err;

=head2 equals

Determines if this procedure is the same as another

  my $isIdentical = $procedure1->equals( $procedure2 );

=cut

around equals => sub {
    my $orig = shift;
    my $self = shift;
    my $other = shift;
    my $case_insensitive = shift;
    my $ignore_sql = shift;

    return 0 unless $self->$orig($other);
    return 0 unless $case_insensitive ? uc($self->name) eq uc($other->name) : $self->name eq $other->name;

    unless ($ignore_sql) {
        my $selfSql = $self->sql;
        my $otherSql = $other->sql;
        # Remove comments
        $selfSql =~ s/--.*$//mg;
        $otherSql =~ s/--.*$//mg;
        # Collapse whitespace to space to avoid whitespace comparison issues
        $selfSql =~ s/\s+/ /sg;
        $otherSql =~ s/\s+/ /sg;
        return 0 unless $selfSql eq $otherSql;
    }

    return 0 unless $self->_compare_objects(scalar $self->parameters, scalar $other->parameters);
#    return 0 unless $self->comments eq $other->comments;
#    return 0 unless $case_insensitive ? uc($self->owner) eq uc($other->owner) : $self->owner eq $other->owner;
    return 0 unless $self->_compare_objects(scalar $self->extra, scalar $other->extra);
    return 1;
};

# Must come after all 'has' declarations
around new => \&ex2err;

1;

=pod

=head1 AUTHORS

Ken Youens-Clark E<lt>kclark@cshl.orgE<gt>,
Paul Harrington E<lt>Paul-Harrington@deshaw.comE<gt>.

=cut
