use Mojo::Base -strict;
use JSON::Validator;
use Test::More;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE};

my $jv = JSON::Validator->new;

$jv->schema('http://swagger.io/v2/schema.json');

isa_ok($jv->schema, 'JSON::Validator::Schema');
like $jv->schema->get('/title'), qr{swagger}i, 'got swagger spec';
ok $jv->schema->get('/patternProperties/^x-/description'),
  'resolved vendorExtension $ref';

is $jv->{schemas}{'http://swagger.io/v2/schema.json'}{title},
  'A JSON Schema for Swagger 2.0 API.',
  'registered this referenced schema for reuse';

is $jv->{schemas}{'http://json-schema.org/draft-04/schema'}{description},
  'Core schema meta-schema', 'registered this referenced schema for reuse';

done_testing;
