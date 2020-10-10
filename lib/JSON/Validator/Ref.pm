package JSON::Validator::Ref;
use Mojo::Base -strict;
use Tie::Hash ();
use base 'Tie::StdHash';

sub fqn { $_[0][2] }
sub ref { $_[0][0]{'$ref'} }

sub schema {
  my $self = shift;
  my @keys = grep { $_ ne '$ref' } keys %{$self->[0]};
  return $self->[1] if !@keys or CORE::ref($self->[1]) ne 'HASH';

  # Return merged schema
  my $schema = $self->[1];
  while (my $tied = tied %$schema) { $schema = $tied->schema }
  my %schema = %$schema;
  $schema{$_} = $self->[0]{$_} for @keys;
  return \%schema;
}

sub EXISTS {
  my ($self, $k) = @_;
  return exists $self->[0]{$k} || (CORE::ref($self->[1]) eq 'HASH' && exists $self->[1]{$k});
}

sub FETCH {
  my ($self, $k) = @_;
  return $self->[0]{$k} if exists $self->[0]{$k};
  return $self->[1]{$k} if CORE::ref($self->[1]) eq 'HASH';
  return undef;
}

# Make it look like there is only one key in the hash
sub FIRSTKEY { scalar keys %{$_[0][0]}; each %{$_[0][0]} }
sub NEXTKEY  { each %{$_[0][0]} }
sub SCALAR   { scalar %{$_[0][0]} }

sub TIEHASH {
  my ($class, $schema, $ref, $fqn) = @_;
  $ref = CORE::ref($ref) eq 'HASH' ? {%$ref} : {'$ref' => $ref};
  return bless [$ref, $schema, $fqn // $ref->{'$ref'}], $class;
}

# This cannot return schema() since it might cause circular references
sub TO_JSON { $_[0][0] }

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
