package SQL::Translator::Schema::Sequence;

=pod

=head1 NAME

SQL::Translator::Schema::Sequence - SQL::Translator Sequence object

=head1 SYNOPSIS

    use SQL::Translator::Schema::Sequence;
    my $sequence = SQL::Translator::Schema::Sequence->new(
        name   => 'foo',
    );

=head1 DESCRIPTION

C<SQL::Translator::Schema::Sequence> is the Sequence object.

Sequence object implements all attributes which sequences have in the following databases:
PostgreSQL, Oracle (partial), Microsoft SQL Server, Db2 and Snowflake.
Every producer supports only the subset of parameters valid for itself.

Only parameter B<name> is mandatory.

It also has the following attributes (inherited from C<SQL::Translator::Schema::Object>):

comments, an array of single line or multiline comments.

extra, any other user defined attributes.

=head1 METHODS

=cut

use Moo;
use SQL::Translator::Utils qw(ex2err throw);
use Sub::Quote             qw(quote_sub);
use SQL::Translator::Types qw(schema_obj);
use SQL::Translator::Schema::DataType;

extends 'SQL::Translator::Schema::Object';

our $VERSION = '1.66';

# Stringify to our name, being careful not to pass any args through so we don't
# accidentally set it to undef. We also have to tweak bool so the object is
# still true when it doesn't have a name (which shouldn't happen!).
use overload
    '""'     => sub { shift->name },
    'bool'   => sub { $_[0]->name || $_[0] },
    fallback => 1,
    ;

=head2 new

Object constructor.

    my $sequence         =  SQL::Translator::Schema::Sequence->new(
        name             => 'master',      # name of the sequence
        increment        => 1,             # increment
        start            => 1,             # sequence start point
        maxvalue         => 5,
        minvalue         => 1,
        cycle            => 0,
        cache            => 3,
        comments         => [ "multi\nline", 'single line' ],
        extra            => { abbr >= 'mst' }, # extra hash
    );

=cut

# Override to remove empty arrays from args.
# t/14postgres-parser breaks without this.
around BUILDARGS => sub {
    my $orig = shift;
    my $self = shift;
    my $args = $self->$orig(@_);

    foreach my $arg (keys %{$args}) {
        delete $args->{$arg}
            if ref($args->{$arg}) eq "ARRAY" && !@{ $args->{$arg} };
    }
    return $args;
};


=head2 is_valid

Determine whether the sequence is valid or not.

    my $ok = $sequence->is_valid;

=cut

sub is_valid {
    my ($self) = @_;
    my $name = $self->name or return $self->error('No name');

    return 1;
}


=head2 schema

Get or set the Sequence's schema object.

    my $schema = $sequence->schema;

=cut

has schema => (is => 'rw', isa => schema_obj('Schema'), weak_ref => 1);

around schema => \&ex2err;


=head2 order

Get or set the sequence's order.

    my $order = $order->order(3);

=cut

has order => (
    is => 'rw',
    isa => quote_sub( q{ die unless $_[0] =~ m/^[[:digit:]]{0,}$/msx; } ),
    default => quote_sub( q{0} ),
);


=head2 name

Get or set the sequence's name.

    my $name = $sequence->name('foo');

=cut

has name => (is => 'rw', default => quote_sub(q{ '' }));

around name => sub {
    my ($orig, $self, $arg) = @_;
    $self->$orig($arg || ());
};


=head2 temporary

Get or set if sequence is temporary, i.e. it lasts only the current session. Boolean.

In Oracle, this attribute is called "SESSION" (the opposite being "GLOBAL".

    my $sequence = $sequence->temporary(1);
    my $sequence = $sequence->temporary(0);
    my $sequence = $sequence->temporary();

=cut

has temporary => (
    is => 'rw',
    isa => quote_sub( q{ die unless $_[0] =~ m/^(?: 0|1|)$/msx; }),
    default => quote_sub( q{0} ),
);

around temporary => \&ex2err;


=head2 unlogged

Get or set if sequence is unlogged. Boolean.

This attribute present only in PostgeSQL.

    my $sequence = $sequence->unlogged(1);
    my $sequence = $sequence->unlogged(0);
    my $sequence = $sequence->unlogged();

=cut

has unlogged => (
    is => 'rw',
    isa => quote_sub( q{ die unless $_[0] =~ m/^(?: 0|1|)$/msx; }),
    default => quote_sub( q{0} ),
);

around unlogged => \&ex2err;


=head2 data_type

Get or set the sequence's data type.
Data type is a hash because some data types
consist of several defining elements, for instance,
character and length, numeric and decimal precision
or timestamp with or without timezone.
Data type has to be expressed precisely so that it can be
interpreted differently for each database.
There are differences, for instance, in what is the size
of "bigint" or "long".
Some databases, for example, Oracle, do not support defining
the data type for sequences.

    # my $data_type = $sequence->data_type({ type => 'integer', size => 20,});
    # my $data_type = $sequence->data_type({ type => 'text', });
    # my $data_type = $sequence->data_type({ type => 'polygon', });
    my $data_type = $sequence->data_type(
        SQL::Translator::Schema::DataType->new(type => 'integer', size => 20,)
    );

=cut

has data_type => (
  is => 'rw',
  # default => quote_sub(q{ new SQL::Translator::Schema::DataType->new(data_type => 'integer', size => 20) })
);

around data_type => sub {
    my ($orig, $self, $arg) = @_;
    $self->$orig($arg || ());
};


=head2 increment

Get or set the increment size.

    my $sequence = $sequence->increment(1);

=cut

has increment => (
    is => 'rw',
    isa => quote_sub( q{ die unless $_[0] =~ m/^[[:digit:]]{1,}$/msx; }),
    default => quote_sub( q{0} ),
);

around increment => \&ex2err;


=head2 start

Get or set the start value.

    my $sequence = $sequence->start(1);

=cut

has start => (
    is => 'rw',
    isa => quote_sub( q{ die unless $_[0] =~ m/^[[:digit:]]{1,}$/msx; }),
    default => quote_sub( q{0} ),
);

around start => \&ex2err;


=head2 maxvalue

Get or set the maxvalue.

    my $sequence = $sequence->maxvalue(1);

=cut

has maxvalue => (
    is => 'rw',
    isa => quote_sub( q{ die unless $_[0] =~ m/^[[:digit:]]{1,}$/msx; }),
    default => quote_sub( q{0} ),
);

around maxvalue => \&ex2err;


=head2 minvalue

Get or set the minvalue.

    my $sequence = $sequence->minvalue(1);

=cut

has minvalue => (
    is => 'rw',
    isa => quote_sub( q{ die unless $_[0] =~ m/^[[:digit:]]{1,}$/msx; }),
    default => quote_sub( q{0} ),
);

around minvalue => \&ex2err;


=head2 cycle

Get or set if sequence can cycle values. Boolean.

    my $sequence = $sequence->cycle(1);
    my $sequence = $sequence->cycle(0);
    my $sequence = $sequence->cycle();

=cut

has cycle => (
    is => 'rw',
    isa => quote_sub( q{ die unless $_[0] =~ m/^(?: 0|1|)$/msx; }),
    default => quote_sub( q{0} ),
);

around cycle => \&ex2err;


=head2 cache

Get or set the cache size.

    my $sequence = $sequence->cache(1);

=cut

has cache => (
    is => 'rw',
    isa => quote_sub( q{ die unless $_[0] =~ m/^[[:digit:]]{1,}$/msx; }),
    default => quote_sub( q{0} ),
);

around cache => \&ex2err;


=head2 guarantee_order

Get or set if sequence creates values in guarantee_order. Boolean.

    my $sequence = $sequence->guarantee_order(1);
    my $sequence = $sequence->guarantee_order(0);
    my $sequence = $sequence->guarantee_order();

=cut

has guarantee_order => (
    is => 'rw',
    isa => quote_sub( q{ die unless $_[0] =~ m/^(?: 0|1|)$/msx; }),
    default => quote_sub( q{0} ),
);

around guarantee_order => \&ex2err;


=head2 owner

Get or set the owner. String.

    my $sequence = $sequence->owner('database.schema.table.column');
    my $sequence = $sequence->owner('schema.table.column');
    my $sequence = $sequence->owner('table.column');
    my $sequence = $sequence->owner('NONE');
    my $sequence = $sequence->owner('');

=cut

has owner => (
    is => 'rw',
    isa => quote_sub( q{ die unless $_[0] =~ m/^[[:graph:]]{0,}$/msx; }),
    default => quote_sub( q{ 'NONE' } ),
);

around owner => \&ex2err;


=head2 keep

Get or set if sequence keeps NEXTVAL during replay for Application Continuity (Oracle). Boolean.

    my $sequence = $sequence->keep(1);
    my $sequence = $sequence->keep(0);
    my $sequence = $sequence->keep();

=cut

has keep => (
    is => 'rw',
    isa => quote_sub( q{ die unless $_[0] =~ m/^(?: 0|1|)$/msx; }),
    default => quote_sub( q{0} ),
);

around keep => \&ex2err;


=head2 comments

Get or set the comments on a sequence.  May be called several times to
set and it will accumulate the comments.  Called in an array context,
returns each comment individually; called in a scalar context, returns
all the comments joined on newlines.

    $sequence->comments('foo');
    $sequence->comments('bar');
    print join( ', ', $sequence->comments ); # prints "foo, bar"

=cut

has comments => (
    is      => 'rw',
    coerce  => quote_sub(q{ ref($_[0]) eq 'ARRAY' ? $_[0] : [$_[0]] }),
    default => quote_sub(q{ [] }),
);

around comments => sub {
    my $orig     = shift;
    my $self     = shift;
    my @comments = ref $_[0] ? @{ $_[0] } : @_;

    for my $arg (@comments) {
        $arg = $arg->[0] if ref $arg;
        push @{ $self->$orig }, $arg if defined $arg && $arg;
    }

    @comments = @{ $self->$orig };
    return wantarray ? @comments
            : @comments ? join("\n", @comments)
            :             undef;
};


=head2 equals

Determines if this sequence is the same as another

    my $isIdentical = $sequence1->equals( $sequence2 );

=cut

around equals => sub {
    my $orig                    = shift;
    my $self                    = shift;
    my $other                   = shift;
    my $case_insensitive        = shift;

    return 0 unless $self->SUPER::equals($other);
    return 0
        unless $case_insensitive
            ? uc($self->name) eq uc($other->name)
            : $self->name eq $other->name;

    return 0 unless $self->order eq $other->order;
    return 0 unless $self->temporary eq $other->temporary;
    return 0 unless $self->unlogged eq $other->unlogged;
    # return 0 unless $self->data_type eq $other->data_type;
    return 0 unless $self->increment eq $other->increment;
    return 0 unless $self->minvalue eq $other->minvalue;
    return 0 unless $self->maxvalue eq $other->maxvalue;
    return 0 unless $self->start eq $other->start;
    return 0 unless $self->cache eq $other->cache;
    return 0 unless $self->cycle eq $other->cycle;
    # return 0 unless $self->owner eq $other->owner;
    return 0 unless $self->guarantee_order eq $other->guarantee_order;
    return 0 unless $self->keep eq $other->keep;

    return 0
        unless $self->_compare_objects(scalar $self->data_type, scalar $other->data_type);

    return 0
        unless $self->_compare_objects(scalar $self->owner, scalar $other->owner);

    return 0
        unless $self->_compare_objects(scalar $self->comments, scalar $other->comments);

    return 0
        unless $self->_compare_objects(scalar $self->extra, scalar $other->extra);

    return 1;
};

# Must come after all 'has' declarations
around new => \&ex2err;


=head2 data

Return a hash containing all data.
The values, including deep values, are copied.

    my $data = $sequence->data;

=cut

sub data {
    my ($self) = @_;

    my %data;
    $data{name} = $self->name;
    $data{order} = $self->order;
    $data{temporary} = $self->temporary;
    $data{unlogged} = $self->unlogged;
    $data{data_type} = $self->data_type;
    $data{increment} = $self->increment;
    $data{minvalue} = $self->minvalue;
    $data{maxvalue} = $self->maxvalue;
    $data{start} = $self->start;
    $data{cache} = $self->cache;
    $data{cycle} = $self->cycle;
    $data{owner} = $self->owner;
    $data{guarantee_order} = $self->guarantee_order;
    $data{keep} = $self->keep;
    $data{comments} = [ $self->comments ];

    return \%data;
}

1;

=pod

=head1 AUTHOR

Mikko Koivunalho <mikkoi@cpan.org>

=cut
