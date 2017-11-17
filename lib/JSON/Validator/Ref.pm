package JSON::Validator::Ref;
use Mojo::Base -base;

sub fqn { $_[0]->{'fqn'} // $_[0]->{'$ref'} }
sub ref { $_[0]->{'$ref'} }
sub schema { $_[0]->{'schema'} }

# jhthorsen: This cannot return schema() since it might cause circular references
sub TO_JSON { {'$ref' => $_[0]->ref} }

1;

=encoding utf8

=head1 NAME

JSON::Validator::Ref - JSON::Validator $ref representation

=head1 SYNOPSIS

  use JSON::Validator::Ref;
  my $ref = JSON::Validator::Ref->new({ref => "...", schema => {...});

=head1 DESCRIPTION

L<JSON::Validator::Ref> is a class representing a C<$ref> inside a JSON Schema.

Note that this module should be considered internal to the L<JSON::Validator>
project and the API is subject to change.

=head1 ATTRIBUTES

=head2 fqn

  $str = $self->fqn;

The fully qualified version of L</ref>.

=head2 ref

  $str = $self->ref;

The original C<$ref> from the document.

=head2 schema

  $hash_ref = $self->schema;

A reference to the schema that the C</fqn> points to.

=head1 SEE ALSO

L<JSON::Validator>.

=cut
