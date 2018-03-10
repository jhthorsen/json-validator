package JSON::Validator::Joi;
use Mojo::Base -base;

use Exporter 'import';
use JSON::Validator;
use Mojo::JSON qw(false true);
use Mojo::Util;

has [qw(format max min multiple_of regex)] => undef;
has type => 'object';

for my $attr (qw(required strict unique)) {
  Mojo::Util::monkey_patch(__PACKAGE__, $attr => sub { $_[0]->{$attr} = $_[1] // 1; $_[0]; });
}

sub alphanum  { shift->_type('string')->regex('^\w*$') }
sub boolean   { shift->type('boolean') }
sub compile   { $_[0]->${\('_compile_' . $_[0]->type)} }
sub date_time { shift->_type('string')->format('date-time') }
sub email     { shift->_type('string')->format('email') }

sub extend {
  my ($self, $by) = @_;
  die "Cannot extend joi '@{[$self->type]}' by '@{[$by->type]}'" unless $self->type eq $by->type;

  my $clone = shift->new(%$self, %$by);

  if ($self->type eq 'object') {
    $clone->{properties}{$_} ||= $self->{properties}{$_} for keys %{$self->{properties} || {}};
  }

  return $clone;
}

sub array     { shift->type('array') }
sub integer   { shift->type('integer') }
sub iso_date  { shift->date_time }
sub items     { $_[0]->{items} = $_[1]; $_[0] }
sub length    { shift->min($_[0])->max($_[0]) }
sub lowercase { shift->_type('string')->regex('^\p{Lowercase}*$') }
sub negative  { shift->_type('number')->max(0) }
sub number    { shift->type('number') }
sub object    { shift->type('object') }
sub pattern   { shift->regex(@_) }
sub positive  { shift->number->min(0) }

sub props {
  my $self = shift->type('object');
  my %properties = ref $_[0] ? %{$_[0]} : @_;

  while (my ($name, $property) = each %properties) {
    push @{$self->{required}}, $name if $property->{required};
    $self->{properties}{$name} = $property->compile;
  }

  return $self;
}

sub string    { shift->type('string') }
sub token     { shift->_type('string')->regex('^[a-zA-Z0-9_]+$') }
sub uppercase { shift->_type('string')->regex('^\p{Uppercase}*$') }
sub uri       { shift->_type('string')->format('uri') }

sub validate {
  my ($self, $data) = @_;
  return JSON::Validator->new->validate($data, $self->compile);
}

sub _compile_array {
  my $self = shift;
  my $json = {type => $self->type};

  $json->{additionalItems} = false          if $self->{strict};
  $json->{items}           = $self->{items} if $self->{items};
  $json->{maxItems}        = $self->{max}   if defined $self->{max};
  $json->{minItems}        = $self->{min}   if defined $self->{min};
  $json->{uniqueItems}     = true           if $self->{unique};

  return $json;
}

sub _compile_boolean { +{type => 'boolean'} }

sub _compile_integer { shift->_compile_number }

sub _compile_number {
  my $self = shift;
  my $json = {type => $self->type};

  $json->{maximum}    = $self->{max}         if defined $self->{max};
  $json->{minimum}    = $self->{min}         if defined $self->{min};
  $json->{multipleOf} = $self->{multiple_of} if defined $self->{multiple_of};

  return $json;
}

sub _compile_object {
  my $self = shift;
  my $json = {type => $self->type};

  $json->{additionalItems}   = false               if $self->{strict};
  $json->{maxProperties}     = $self->{max}        if defined $self->{max};
  $json->{minProperties}     = $self->{min}        if defined $self->{min};
  $json->{patternProperties} = $self->{regex}      if $self->{regex};
  $json->{properties}        = $self->{properties} if ref $self->{properties} eq 'HASH';
  $json->{required}          = $self->{required}   if ref $self->{required} eq 'ARRAY';

  return $json;
}

sub _compile_string {
  my $self = shift;
  my $json = {type => $self->type};

  $json->{format}    = $self->{format} if defined $self->{format};
  $json->{maxLength} = $self->{max}    if defined $self->{max};
  $json->{minLength} = $self->{min}    if defined $self->{min};
  $json->{pattern}   = $self->{regex}  if defined $self->{regex};

  return $json;
}

sub _type {
  $_[0]->{type} = $_[1] unless $_[0]->{type};
  return $_[0];
}

sub TO_JSON { shift->compile }

1;

=encoding utf8

=head1 NAME

JSON::Validator::Joi - Joi adapter for JSON::Validator

=head1 SYNOPSIS

  use JSON::Validator "joi";

  my @errors = joi(
    {
      name  => "Jan Henning",
      age   => 34,
      email => "jhthorsen@cpan.org",
    },
    joi->object->props(
      age   => joi->integer->min(0)->max(200),
      email => joi->regex(".@.")->required,
      name  => joi->string->min(1),
    )
  );

  die "@errors" if @errors;

=head1 DESCRIPTION

L<JSON::Validator::Joi> tries to mimic the JavaScript library
L<https://github.com/hapijs/joi>.

This module is EXPERIMENTAL and can change without warning. Let me know if you
find it useful.

=head1 ATTRIBUTES

=head2 format

  $self = $self->format("email");
  $str = $self->format;

Used to set the format of the L</string>.
See also L</iso_date>, L</email> and L</uri>.

=head2 max

  $self = $self->max(10);
  $int = $self->max;

=over 2

=item * array

Defines the max number of items in the array.

=item * integer, number

Defined the max value.

=item * object

Defines the max number of items in the object.

=item * string

Defines how long the string can be.

=back

=head2 min

  $self = $self->min(10);
  $int = $self->min;

=over 2

=item * array

Defines the minimum number of items in the array.

=item * integer, number

Defined the minimum value.

=item * object

Defines the minimum number of items in the object.

=item * string

Defines how short the string can be.

=back

=head2 multiple_of

  $self = $self->multiple_of(3);
  $int = $self->multiple_of;

Used by L</integer> and L</number> to define what the number must be a multiple
of.

=head2 regex

  $self = $self->regex("^\w+$");
  $str = $self->regex;

Defines a pattern that L</string> will be validated against.

=head2 type

  $str = $self->type;

Set by L</array>, L</integer>, L</object> or L</string>.

=head1 METHODS

=head2 TO_JSON

Alias for L</compile>.

=head2 alphanum

  $self = $self->alphanum;

Sets L</regex> to "^\w*$".

=head2 array

  $self = $self->array;

Sets L</type> to "array".

=head2 boolean

  $self = $self->boolean;

Sets L</type> to "boolean".

=head2 compile

  $hash_ref = $self->compile;

Will convert this object into a JSON-Schema data structure that
L<JSON::Validator/schema> understands.

=head2 date_time

  $self = $self->date_time;

Sets L</format> to L<date-time|JSON::Validator/date-time>.

=head2 email

  $self = $self->email;

Sets L</format> to L<email|JSON::Validator/email>.

=head2 extend

  $new_self = $self->extend($joi);

Will extend C<$self> with the definitions in C<$joi> and return a new object.

=head2 iso_date

Alias for L</date_time>.

=head2 integer

  $self = $self->integer;

Sets L</type> to "integer".

=head2 items

  $self = $self->items($joi);
  $self = $self->items([$joi, ...]);

Defines a list of items for the L</array> type.

=head2 length

  $self = $self->length(10);

Sets both L</min> and L</max> to the number provided.

=head2 lowercase

  $self = $self->lowercase;

Will set L</regex> to only match lower case strings.

=head2 negative

  $self = $self->negative;

Sets L</max> to C<0>.

=head2 number

  $self = $self->number;

Sets L</type> to "number".

=head2 object

  $self = $self->object;

Sets L</type> to "object".

=head2 pattern

Alias for L</regex>.

=head2 positive

  $self = $self->positive;

Sets L</min> to C<0>.

=head2 props

  $self = $self->props(name => JSON::Validator::Joi->new->string, ...);

Used to define properties for an L</object> type. Each key is the name of the
parameter and the values must be a L<JSON::Validator::Joi> object.

=head2 required

  $self = $self->required;

Marks the current property as required.

=head2 strict

  $self = $self->strict;

Sets L</array> and L</object> to not allow any more items/keys than what is defined.

=head2 string

  $self = $self->string;

Sets L</type> to "string".

=head2 token

  $self = $self->token;

Sets L</regex> to C<^[a-zA-Z0-9_]+$>.

=head2 validate

  @errors = $self->validate($data);

Used to validate C<$data> using L<JSON::Validator/validate>. Returns a list of
L<JSON::Validator::Error|JSON::Validator/ERROR OBJECT> objects on invalid
input.

=head2 unique

  $self = $self->unique;

Used to force the L</array> to only contain unique items.

=head2 uppercase

  $self = $self->uppercase;

Will set L</regex> to only match upper case strings.

=head2 uri

  $self = $self->uri;

Sets L</format> to L<uri|JSON::Validator/uri>.

=head1 SEE ALSO

L<JSON::Validator>

=cut
