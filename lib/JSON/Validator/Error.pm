package JSON::Validator::Error;
use Mojo::Base -base;

use overload q("") => \&to_string, bool => sub {1}, fallback => 1;

has message => sub {
  my $self   = shift;
  my $phrase = $self->phrase;
  my $params = $self->phrase_parameters;

  $phrase =~ s!%(\d+)\b!{$params->[$1 - 1] // $1}!ge;

  return $phrase;
};

has path              => '/';
has phrase            => '';
has phrase_parameters => sub { [] };

sub new {
  my $self = shift->SUPER::new(ref $_[0] ? $_[0] : ());

  unless (ref $_[0]) {
    @$self{qw(path phrase)} = (shift || '/', shift || '');
    $self->{phrase_parameters} = [@_];
  }

  return $self;
}

sub to_string { sprintf '%s: %s', $_[0]->path, $_[0]->message }
sub TO_JSON { +{message => $_[0]->message, path => $_[0]->path} }

1;

=encoding utf8

=head1 NAME

JSON::Validator::Error - JSON::Validator error object

=head1 SYNOPSIS

  use JSON::Validator::Error;
  my $err = JSON::Validator::Error->new($path, $phrase, @phrase_parameters);

  # Translate
  $err->message(My::Lexicon->loc($err->phrase, @{$err->phrase_parameters});

=head1 DESCRIPTION

L<JSON::Validator::Error> is a class representing validation errors from
L<JSON::Validator>.

=head1 PHRASES

=head2 Generic

  Does not match %1 format.
  Expected %1 - got %2.
  Expected %1 - got different %2.
  No validation rules defined.

=head2 anyOf, allOf, oneOf, not

  /allOf Expected %1 - got %2.
  /anyOf Expected %1 - got %2.
  /oneOf Expected %1 - got %2.
  All of the oneOf rules match.
  Should not match.

=head2 Array

  Invalid number of items: %1/%2.
  Not enough items: %1/%2.
  Too many items: %1/%2.
  Unique items required.

=head2 Constants

  Does not match constant: %1.

=head2 Enum

  Not in enum list: %1.

=head2 Formats

  # uri
  Hex escapes are not complete.
  Invalid hex escape.
  Path cannot be empty or begin with a /
  Path cannot not start with //.
  Scheme missing from URI.
  Scheme must begin with a letter.
  Scheme, path or fragment are required.

=head2 Integers and numbers

  %1 %2 maximum(%3)
  %1 %2 minimum(%3)
  Not multiple of %1.

=head1 Null

  Not null.

=head2 Objects

  Missing property.
  Not enough properties: %1/%2.
  Properties not allowed: %1.
  Too many properties: %1/%2.

=head2 String

  String does not match %1.
  String is too long: %1/%2.
  String is too short: %1/%2.

=head1 ATTRIBUTES

=head2 message

  my $str   = $error->message;
  my $error = $error->message($str);

A human readable description of the error. Defaults to the English version of
L</phrase> filled with L</phrase_parameters>.

=head2 path

  my $str = $error->path;

A JSON pointer to where the error occurred. Defaults to "/".

=head2 phrase

  my $str = $error->phrase;

Holds a phrase that can be translated and filled with L</phrase_parameters>.
Example phrase: "Not enough items: %1/%2.".

=head2 phrase_parameters

  my $array_ref = $error->phrase_parameters;

A list of values that can be put into the L</phrase>.

=head1 METHODS

=head2 new

  my $error = JSON::Validator::Error->new($path, $phrase, @$phrase_parameters);
  my $error = JSON::Validator::Error->new(\%attributes);

Object constructor.

=head2 to_string

  my $str = $error->to_string;

Returns the L</path> and L</message> part as a string: C<$path: $message>.

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
