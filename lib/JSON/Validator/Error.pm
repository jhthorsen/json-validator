package JSON::Validator::Error;
use Mojo::Base -base;

use overload
  q("")    => sub { sprintf '%s: %s', @{$_[0]}{qw(path message)} },
  bool     => sub {1},
  fallback => 1;

sub new {
  my $self = bless {}, shift;
  @$self{qw(path message)} = ($_[0] || '/', $_[1] || '');
  $self->{$_} = $_[2]->{$_} for keys %{$_[2] || {}};
  $self;
}

sub message { shift->{message} }
sub path    { shift->{path} }
sub TO_JSON { {message => $_[0]->{message}, path => $_[0]->{path}} }

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

  $str = $self->message;

A human readable description of the error. Defaults to empty string.

=head2 path

  $str = $self->path;

A JSON pointer to where the error occurred. Defaults to "/".

=head1 METHODS

=head2 new

  $self = JSON::Validator::Error->new($path, $message);

Object constructor.

=head1 SEE ALSO

L<JSON::Validator>.

=cut
