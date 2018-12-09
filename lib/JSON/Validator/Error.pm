package JSON::Validator::Error;
use Mojo::Base -base;

use overload q("") => \&to_string, bool => sub {1}, fallback => 1;

sub new {
  my $self = bless {}, shift;
  @$self{qw(path message)} = ($_[0] || '/', $_[1] || '');
  $self;
}

sub message   { shift->{message} }
sub path      { shift->{path} }
sub to_string { sprintf '%s: %s', @{$_[0]}{qw(path message)} }
sub TO_JSON   { {message => $_[0]->{message}, path => $_[0]->{path}} }

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

=head2 message

  my $str = $error->message;

A human readable description of the error. Defaults to empty string.

=head2 path

  my $str = $error->path;

A JSON pointer to where the error occurred. Defaults to "/".

=head1 METHODS

=head2 new

  my $error = JSON::Validator::Error->new($path, $message);

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
