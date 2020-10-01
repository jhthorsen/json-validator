package JSON::Validator::Ref;
use Mojo::Base -strict;

use Tie::Hash ();
use base 'Tie::StdHash';

sub fqn    { $_[0][2] }
sub ref    { $_[0][1] }
sub schema { $_[0][0] }

sub EXISTS {
  my ($self, $k) = @_;
  return $k eq '$ref' || (CORE::ref($self->[0]) eq 'HASH' && exists $self->[0]{$k});
}

sub FETCH {
  my ($self, $k) = @_;
  return $k eq '$ref' ? $self->[1] : (CORE::ref($self->[0]) eq 'HASH' ? $self->[0]{$k} : undef);
}

# Make it look like there is only one key in the hash
sub FIRSTKEY {'$ref'}
sub KEYS     {'$ref'}
sub NEXTKEY  {undef}
sub SCALAR   {1}

sub TIEHASH {
  my ($class, $schema, $ref, $fqn) = @_;
  return bless [$schema, $ref, $fqn // $ref], $class;
}

# This cannot return schema() since it might cause circular references
sub TO_JSON { {'$ref' => $_[0][1]} }

1;

=encoding utf8

=head1 NAME

JSON::Validator::Ref - JSON::Validator $ref representation

=head1 SYNOPSIS

  use JSON::Validator::Ref;
  my $ref = JSON::Validator::Ref->new({ref => "...", schema => {...});

or:

  tie my %ref, 'JSON::Validator::Ref', $schema, $path;

=head1 DESCRIPTION

L<JSON::Validator::Ref> is a class representing a C<$ref> inside a JSON Schema.

This module SHOULD be considered internal to the L<JSON::Validator> project and
the API is subject to change.

=head1 ATTRIBUTES

=head2 fqn

  $str = $ref->fqn;

The fully qualified version of L</ref>.

=head2 ref

  $str = $ref->ref;

The original C<$ref> from the document.

=head2 schema

  $hash_ref = $ref->schema;

A reference to the schema that the C</fqn> points to.

=head1 SEE ALSO

L<JSON::Validator>.

=cut
