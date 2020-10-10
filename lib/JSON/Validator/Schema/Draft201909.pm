package JSON::Validator::Schema::Draft201909;
use Mojo::Base 'JSON::Validator::Schema::Draft7';

has specification => 'https://json-schema.org/draft/2019-09/schema';

1;

=encoding utf8

=head1 NAME

JSON::Validator::Schema::Draft201909 - JSON-Schema Draft 2019-09

=head1 SYNOPSIS

See L<JSON::Validator::Schema/SYNOPSIS>.

=head1 DESCRIPTION

This class represents
L<https://json-schema.org/specification-links.html#2019-09-formerly-known-as-draft-8>.

=head1 ATTRIBUTES

=head2 specification

  my $str = $schema->specification;

Defaults to "L<https://json-schema.org/draft/2019-09/schema>".

=head1 SEE ALSO

L<JSON::Validator::Schema>.

=cut
