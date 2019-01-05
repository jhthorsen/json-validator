package JSON::Validator::Joi;
use Mojo::Base -base;

use Exporter 'import';
use JSON::Validator;
use Mojo::JSON qw(false true);
use Mojo::Util;

has enum => sub { +[] };
has [qw(format max min multiple_of regex)] => undef;
has type => 'object';

for my $attr (qw(required strict unique)) {
  Mojo::Util::monkey_patch(__PACKAGE__,
    $attr => sub { $_[0]->{$attr} = $_[1] // 1; $_[0]; });
}

sub alphanum { shift->_type('string')->regex('^\w*$') }
sub boolean  { shift->type('boolean') }

sub compile {
  my $self   = shift;
  my $merged = {};

  for (ref $self->type eq 'ARRAY' ? @{$self->type} : $self->type) {
    my $method   = "_compile_$_";
    my $compiled = $self->$method;
    @$merged{keys %$compiled} = values %$compiled;
  }

  return $merged;
}

sub date_time { shift->_type('string')->format('date-time') }
sub email     { shift->_type('string')->format('email') }

sub extend {
  my ($self, $by) = @_;
  die "Cannot extend joi '@{[$self->type]}' by '@{[$by->type]}'"
    unless $self->type eq $by->type;

  my $clone = shift->new(%$self, %$by);

  if ($self->type eq 'object') {
    $clone->{properties}{$_} ||= $self->{properties}{$_}
      for keys %{$self->{properties} || {}};
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
  state $validator = JSON::Validator->new->coerce(1);
  return $validator->validate($data, $self->compile);
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

sub _compile_null { {type => shift->type} }

sub _compile_number {
  my $self = shift;
  my $json = {type => $self->type};

  $json->{enum} = $self->{enum} if defined $self->{enum} and @{$self->{enum}};
  $json->{maximum}    = $self->{max}         if defined $self->{max};
  $json->{minimum}    = $self->{min}         if defined $self->{min};
  $json->{multipleOf} = $self->{multiple_of} if defined $self->{multiple_of};

  return $json;
}

sub _compile_object {
  my $self = shift;
  my $json = {type => $self->type};

  $json->{additionalProperties} = false          if $self->{strict};
  $json->{maxProperties}        = $self->{max}   if defined $self->{max};
  $json->{minProperties}        = $self->{min}   if defined $self->{min};
  $json->{patternProperties}    = $self->{regex} if $self->{regex};
  $json->{properties}           = $self->{properties}
    if ref $self->{properties} eq 'HASH';
  $json->{required} = $self->{required} if ref $self->{required} eq 'ARRAY';

  return $json;
}

sub _compile_string {
  my $self = shift;
  my $json = {type => $self->type};

  $json->{enum} = $self->{enum} if defined $self->{enum} and @{$self->{enum}};
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

JSON::Validator::Joi - Joi validation sugar for JSON::Validator

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

L<JSON::Validator::Joi> is an elegant DSL schema-builder. The main purpose is
to build a L<JSON Schema|https://json-schema.org/> for L<JSON::Validator>, but
it can also validate data directly with sane defaults.

=head1 ATTRIBUTES

=head2 enum

  my $joi       = $joi->enum(["foo", "bar"]);
  my $array_ref = $joi->enum;

Defines a list of enum values for L</integer>, L</number> and L</string>.

=head2 format

  my $joi = $joi->format("email");
  my $str = $joi->format;

Used to set the format of the L</string>.
See also L</iso_date>, L</email> and L</uri>.

=head2 max

  my $joi = $joi->max(10);
  my $int = $joi->max;

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

  my $joi = $joi->min(10);
  my $int = $joi->min;

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

  my $joi = $joi->multiple_of(3);
  my $int = $joi->multiple_of;

Used by L</integer> and L</number> to define what the number must be a multiple
of.

=head2 regex

  my $joi = $joi->regex("^\w+$");
  my $str = $joi->regex;

Defines a pattern that L</string> will be validated against.

=head2 type

  my $joi = $joi->type("string");
  my $joi = $joi->type([qw(null integer)]);
  my $any = $joi->type;

Sets the required type. This attribute is set by the convenience methods
L</array>, L</integer>, L</object> and L</string>, but can be set manually if
you need to check against a list of type.

=head1 METHODS

=head2 TO_JSON

Alias for L</compile>.

=head2 alphanum

  my $joi = $joi->alphanum;

Sets L</regex> to "^\w*$".

=head2 array

  my $joi = $joi->array;

Sets L</type> to "array".

=head2 boolean

  my $joi = $joi->boolean;

Sets L</type> to "boolean".

=head2 compile

  my $hash_ref = $joi->compile;

Will convert this object into a JSON-Schema data structure that
L<JSON::Validator/schema> understands.

=head2 date_time

  my $joi = $joi->date_time;

Sets L</format> to L<date-time|JSON::Validator/date-time>.

=head2 email

  my $joi = $joi->email;

Sets L</format> to L<email|JSON::Validator/email>.

=head2 extend

  my $new_joi = $joi->extend($joi);

Will extend C<$joi> with the definitions in C<$joi> and return a new object.

=head2 iso_date

Alias for L</date_time>.

=head2 integer

  my $joi = $joi->integer;

Sets L</type> to "integer".

=head2 items

  my $joi = $joi->items($joi);
  my $joi = $joi->items([$joi, ...]);

Defines a list of items for the L</array> type.

=head2 length

  my $joi = $joi->length(10);

Sets both L</min> and L</max> to the number provided.

=head2 lowercase

  my $joi = $joi->lowercase;

Will set L</regex> to only match lower case strings.

=head2 negative

  my $joi = $joi->negative;

Sets L</max> to C<0>.

=head2 number

  my $joi = $joi->number;

Sets L</type> to "number".

=head2 object

  my $joi = $joi->object;

Sets L</type> to "object".

=head2 pattern

Alias for L</regex>.

=head2 positive

  my $joi = $joi->positive;

Sets L</min> to C<0>.

=head2 props

  my $joi = $joi->props(name => JSON::Validator::Joi->new->string, ...);

Used to define properties for an L</object> type. Each key is the name of the
parameter and the values must be a L<JSON::Validator::Joi> object.

=head2 required

  my $joi = $joi->required;

Marks the current property as required.

=head2 strict

  my $joi = $joi->strict;

Sets L</array> and L</object> to not allow any more items/keys than what is defined.

=head2 string

  my $joi = $joi->string;

Sets L</type> to "string".

=head2 token

  my $joi = $joi->token;

Sets L</regex> to C<^[a-zA-Z0-9_]+$>.

=head2 validate

  my @errors = $joi->validate($data);

Used to validate C<$data> using L<JSON::Validator/validate>. Returns a list of
L<JSON::Validator::Error|JSON::Validator/ERROR OBJECT> objects on invalid
input.

=head2 unique

  my $joi = $joi->unique;

Used to force the L</array> to only contain unique items.

=head2 uppercase

  my $joi = $joi->uppercase;

Will set L</regex> to only match upper case strings.

=head2 uri

  my $joi = $joi->uri;

Sets L</format> to L<uri|JSON::Validator/uri>.

=head1 SEE ALSO

L<JSON::Validator>

L<https://github.com/hapijs/joi>.

=cut
