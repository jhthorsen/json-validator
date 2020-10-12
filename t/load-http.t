use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE};

my $jv = JSON::Validator->new;

$jv->schema('http://swagger.io/v2/schema.json');

isa_ok $jv->schema, 'JSON::Validator::Schema';
like $jv->schema->get('/title'), qr{swagger}i, 'got swagger spec';
ok $jv->schema->get('/patternProperties/^x-/description'), 'resolved vendorExtension $ref';

is_deeply [sort keys %{$jv->store->schemas}],
  ['http://json-schema.org/draft-04/schema', 'http://swagger.io/v2/schema.json'], 'schemas in store';

done_testing;
