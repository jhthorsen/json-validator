package JSON::Validator::Error;
use Mojo::Base -base;

use overload q("") => \&to_string, bool => sub {1}, fallback => 1;

our %MESSAGES = (
  allOf => {type => '/allOf Expected %3 - got %4.'},
  anyOf => {type => '/anyOf Expected %3 - got %4.'},
  array => {
    additionalItems => 'Invalid number of items: %3/%4.',
    maxItems        => 'Too many items: %3/%4.',
    minItems        => 'Not enough items: %3/%4.',
    uniqueItems     => 'Unique items required.',
  },
  const   => {const => 'Does not match const: %3.'},
  enum    => {enum  => 'Not in enum list: %3.'},
  integer => {
    maximum    => '%3 > maximum(%4)',
    minimum    => '%3 < minimum(%4)',
    multipleOf => 'Not multiple of %3.',
  },
  not    => {not  => 'Should not match.'},
  null   => {null => 'Not null.'},
  number => {
    maximum    => '%3 > maximum(%4)',
    minimum    => '%3 < minimum(%4)',
    multipleOf => 'Not multiple of %3.',
  },
  object => {
    additionalProperties => 'Properties not allowed: %3.',
    maxProperties        => 'Too many properties: %3/%4.',
    minProperties        => 'Not enough properties: %3/%4.',
    required             => 'Missing property.',
  },
  oneOf => {
    all_rules_match => 'All of the oneOf rules match.',
    type            => '/oneOf Expected %3 - got %4.',
  },
  string => {
    pattern   => 'String does not match %3.',
    maxLength => 'String is too long: %3/%4.',
    minLength => 'String is too short: %3/%4.',
  }
);

has details => sub { [qw(generic generic)] };

has message => sub {
  my $self    = shift;
  my $details = $self->details;
  my $message;

  if (($details->[0] || '') eq 'format') {
    $message = '%3';
  }
  elsif (($details->[1] || '') eq 'type' and @$details == 3) {
    $message = 'Expected %1 - got %3.';
  }
  elsif (my $group = $MESSAGES{$details->[0]}) {
    $message = $group->{$details->[1] || 'default'};
  }

  return join ' ', Failed => @$details unless defined $message;

  $message =~ s!\%(\d)\b!{$details->[$1 - 1] // ''}!ge;
  return $message;
};

has path => '/';

sub new {
  my $class = shift;

  # Constructed with attributes
  return $class->SUPER::new($_[0]) if ref $_[0] eq 'HASH';

  # Constructed with ($path, ...)
  my $self = $class->SUPER::new;
  $self->{path} = shift || '/';

  # Constructed with ($path, $message)
  $self->message(shift) unless ref $_[0];

  # Constructed with ($path, \@details)
  $self->details(shift) if ref $_[0];

  return $self;
}

sub to_string { sprintf '%s: %s', $_[0]->path, $_[0]->message }
sub TO_JSON { {message => $_[0]->message, path => $_[0]->path} }

1;

=encoding utf8

=head1 NAME

JSON::Validator::Error - JSON::Validator error object

=head1 SYNOPSIS

  use JSON::Validator::Error;
  my $err = JSON::Validator::Error->new($path, $message);

=head1 DESCRIPTION

L<JSON::Validator::Error> is a class representing validation errors from
L<JSON::Validator>.

=head1 ATTRIBUTES

=head2 details

  my $error     = $error->details(["generic", "generic"]);
  my $error     = $error->details([qw(array type object)]);
  my $error     = $error->details([qw(format date-time Invalid)]);
  my $array_ref = $error->details;

Details about the error:

=over 2

=item 1.

Often the category of tests that was run. Example values: allOf, anyOf, array,
const, enum, format, integer, not, null, number, object, oneOf and string.

=item 2.

Often the test that failed. Example values: additionalItems,
additionalProperties, const, enum, maxItems, maxLength, maxProperties, maximum,
minItems, minLength.  minProperties, minimum, multipleOf, not, null, pattern,
required, type and uniqueItems,

=item 3.

The rest of the list contains parameters for the test that failed. It can be a
plain human-readable string or numbers indicating things such as max/min
values.

=back

=head2 message

  my $str = $error->message;

A human readable description of the error. Defaults to being being constructed
from L</details>. See the C<%MESSAGES> variable in the source code for more
details.

=head2 path

  my $str = $error->path;

A JSON pointer to where the error occurred. Defaults to "/".

=head1 METHODS

=head2 new

  my $error = JSON::Validator::Error->new(\%attributes);
  my $error = JSON::Validator::Error->new($path, \@details);
  my $error = JSON::Validator::Error->new($path, \@details);

Object constructor.

=head2 to_string

  my $str = $error->to_string;

Returns the "path" and "message" part as a string: "$path: $message".

=head1 OPERATORS

L<JSON::Validator::Error> overloads the following operators:

=head2 bool

  my $bool = !!$error;

Always true.

=head2 stringify

  my $str = "$error";

Alias for L</to_string>.

=head1 SEE ALSO

L<JSON::Validator>.

=cut
