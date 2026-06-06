use Mojo::Base -strict;
use JSON::Validator;
use JSON::Validator::Schema::OpenAPIv3;
use Test::More;

# Issue #286: the default OpenAPI v3.0 specification must be bundled with the
# distribution and resolvable offline. Any attempt to fetch it over the network
# means the bundled spec is missing.

subtest 'default specification is the bundled 2021-09-28 spec' => sub {
  my $schema = JSON::Validator::Schema::OpenAPIv3->new;
  is $schema->specification, 'https://spec.openapis.org/oas/3.0/schema/2021-09-28', 'specification';
};

subtest 'default specification loads from the bundle without network' => sub {
  my $jv = JSON::Validator->new;
  $jv->store->ua(FakeUA->new);    # blow up if a network request is attempted

  my $url = 'https://spec.openapis.org/oas/3.0/schema/2021-09-28';
  my $id  = $jv->store->load($url);
  is $id, $url, 'loaded from bundle';
  is $jv->store->get($id)->{id}, $url, 'bundled schema id matches url';
};

subtest 'openapi 3.0.x documents are validated against the bundled default' => sub {
  my $jv = JSON::Validator->new;
  $jv->store->ua(FakeUA->new);    # blow up if a network request is attempted

  my $schema = $jv->schema({openapi => '3.0.3', info => {title => 't', version => '1'}, paths => {}})->schema;
  is $schema->specification, 'https://spec.openapis.org/oas/3.0/schema/2021-09-28', 'detected default';
  is_deeply $schema->errors, [], 'valid minimal 3.0 document';
};

done_testing;

package FakeUA;
sub new { bless {}, shift }
sub get { Test::More::BAIL_OUT('network access attempted - bundled OpenAPI v3.0 spec is missing') }
