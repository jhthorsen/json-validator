package JSON::Validator::URI;
use Mojo::Base 'Mojo::URL';
use Exporter qw(import);

use Digest::SHA ();
use Mojo::JSON;
use Scalar::Util qw(blessed);

use constant UUID_NAMESPACE => do {
  my $uuid = '1bab225d-1ca6-4cc5-9c53-a37cc7527848';    # UUIDv4
  $uuid =~ tr/-//d;
  pack 'H*', $uuid;
};

our @EXPORT_OK = qw(uri);

has nid => undef;
has nss => undef;

sub from_data {
  my $self = shift->scheme('urn')->nid('uuid');
  state $d = Digest::SHA->new(1);
  $d->reset->add(UUID_NAMESPACE)->add(Mojo::JSON::encode_json(shift));
  my $uuid = substr $d->digest, 0, 16;
  substr $uuid, 6, 1, chr(ord(substr $uuid, 6, 1) & 0x0f | 0x50);    # set version 5
  substr $uuid, 8, 1, chr(ord(substr $uuid, 8, 1) & 0x3f | 0x80);    # set variant 2
  return $self->nss(sprintf '%s-%s-%s-%s-%s', map { unpack 'H*', $_ } map { substr $uuid, 0, $_, '' } 4, 2, 2, 2, 6);
}

sub parse {
  my ($self, $url) = @_;

  # URL
  return $self->SUPER::parse($url) unless $url =~ m!^urn:(.*)$!i;

  # URN
  $self->scheme('urn');

  # TODO This regex is not 100% correct according to the 1997 changes regarding "?"
  return $self unless $1 =~ m/^([a-z0-9][a-z0-9-]{0,31}):([^#]+)(#(.*))?/;
  $self->fragment($4) if defined $3;
  return $self->nid($1)->nss($2);
}

sub to_abs {
  my $self = shift;

  my $abs = $self->clone;
  return $abs if $abs->is_abs;

  # Scheme
  my $base = shift || $abs->base;
  $abs->base($base)->scheme($base->scheme);

  my $scheme = lc($base->scheme // $abs->scheme // '');

  if ($scheme eq 'urn') {
    return $abs->scheme('urn') if $abs->nid and $abs->nss;
    $abs->nid($base->nid)->nss($base->nss);
  }
  else {
    return $abs if $abs->host;
    $abs->host($base->host)->port($base->port);
  }

  $abs->fragment($base->fragment) unless $abs->fragment;
  $abs->userinfo($base->userinfo) unless $abs->userinfo;

  # Absolute path
  my $path = $abs->path;
  return $abs if $path->leading_slash;

  # Inherit path
  if (!@{$path->parts}) {
    $abs->path($base->path->clone->canonicalize);

    # Query
    $abs->query($base->query->clone) unless length $abs->query->to_string;
  }

  # Merge paths
  else { $abs->path($base->path->clone->merge($path)->canonicalize) }

  return $abs;
}

sub to_string {
  my $self = shift;

  # URL
  return $self->SUPER::to_string unless 'urn' eq ($self->scheme // '');

  # URN
  my $urn = sprintf 'urn:%s:%s', $self->nid, $self->nss;
  my $p   = $self->path_query;
  $urn .= $p =~ m!^/! ? $p : "/$p" if length $p;
  $urn .= "#$p"                    if defined($p = $self->fragment);
  return $urn;
}

sub to_unsafe_string {
  my $self = shift;
  return 'urn' eq ($self->scheme // '') ? $self->to_string : $self->SUPER::to_unsafe_string;
}

sub uri {
  my ($uri, $base) = @_;
  return __PACKAGE__->new unless @_;
  $uri  = __PACKAGE__->new($uri) unless blessed $uri;
  $base = __PACKAGE__->new($base) if $base and !blessed $base;
  return $base ? $uri->to_abs($base) : $uri->clone;
}

1;

=encoding utf8

=head1 NAME

JSON::Validator::URI - Uniform Resource Identifier

=head1 SYNOPSIS

  use JSON::Validator::URI;

  my $urn = JSON::Validator::URI->new('urn:uuid:ee564b8a-7a87-4125-8c96-e9f123d6766f');
  my $url = JSON::Validator::URI->new('/foo');
  my $url = JSON::Validator::URI->new('https://mojolicious.org');

=head1 DESCRIPTION

L<JSON::Validator::URI> is a class for presenting both URL and URN.

This class is currently EXPERIMENTAL.

=head1 EXPORTED FUNCTIONS

=head2 uri

  $uri = uri;
  $uri = uri $orig, $base;

Returns a new L<JSON::Validator::URI> object from C<$orig> and C<$base>. Both
variables can be either a string or a L<JSON::Validator::URI> object.

=head1 ATTRIBUTES

L<JSON::Validator::URI> inherits all attributes from L<Mojo::URL> and
implements the following ones.

=head2 nid

  $str = $uri->nid;

Returns the NID part of a URN. Example "uuid" or "iban".

=head2 nss

  $str = $uri->nss;

Returns the NSS part of a URN. Example "6e8bc430-9c3a-11d9-9669-0800200c9a66".

=head1 METHODS

L<JSON::Validator::URI> inherits all methods from L<Mojo::URL> and implements
the following ones.

=head2 from_data

  $str = $uri->from_data($data);

This method will generate a URN for C<$data>. C<$data> will be serialized
using L<Mojo::JSON/encode_json> before being used to generate an UUIDv5.

This method is EXPERIMENTAL and subject to change!

=head2 parse

See L<Mojo::URL/parse>.

=head2 to_abs

See L<Mojo::URL/to_abs>.

=head2 to_string

See L<Mojo::URL/to_string>.

=head2 to_unsafe_string

See L<Mojo::URL/to_unsafe_string>.

=head1 SEE ALSO

L<JSON::Validator>.

=cut
