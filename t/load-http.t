use Mojo::Base -strict;
use Test::More;
use JSON::Validator;

plan skip_all => 'TEST_ONLINE=1' unless $ENV{TEST_ONLINE};

my $validator = JSON::Validator->new;

$validator->schema('http://swagger.io/v2/schema.json');

isa_ok($validator->schema, 'Mojo::JSON::Pointer');
like $validator->schema->get('/title'), qr{swagger}i, 'got swagger spec';
ok $validator->schema->get('/patternProperties/^x-/description'),
  'resolved vendorExtension $ref';

done_testing;
