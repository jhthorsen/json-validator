use Mojo::Base -strict;
use JSON::Validator::Schema::OpenAPIv2;
use Test::Deep;
use Test::More;

my $cwd    = Mojo::File->new(__FILE__)->dirname;
my $schema = JSON::Validator::Schema::OpenAPIv2->new;

is $schema->specification, 'http://swagger.io/v2/schema.json', 'specification';
is_deeply $schema->coerce, {booleans => 1, numbers => 1, strings => 1}, 'default coercion';

note 'jv->schema';
$schema = JSON::Validator->new->schema($cwd->child(qw(spec v2-petstore.json)))->schema;
isa_ok $schema, 'JSON::Validator::Schema::OpenAPIv2';

note 'validate schema';
@errors = @{JSON::Validator->new->schema({swagger => '2.0', paths => {}})->schema->errors};
is "@errors", '/info: Missing property.', 'invalid schema';

note 'parameters_for_request';
is $schema->parameters_for_request([GET => '/pets/nope']), undef, 'no such path';
cmp_deeply $schema->parameters_for_request([GET => '/pets']), [superhashof({in => 'query', name => 'limit'})],
  'parameters_for_request inside path';
cmp_deeply $schema->parameters_for_request([post => '/pets']),
  [superhashof({in => 'body', name => 'body', accepts => ['application/json']})], 'parameters_for_request for body';
cmp_deeply $schema->parameters_for_request([get => '/pets/{petId}']), [superhashof({in => 'path', name => 'petId'})],
  'parameters_for_request inside method';

note 'parameters_for_response';
is $schema->parameters_for_response([GET => '/pets/nope']), undef, 'no such path';
cmp_deeply $schema->parameters_for_response([GET => '/pets']),
  [
  superhashof({in => 'header', name => 'x-next'}),
  superhashof({in => 'body',   name => 'body', accepts => ['application/json']}),
  ],
  'parameters_for_request inside path and default response code';
cmp_deeply $schema->parameters_for_response([GET => '/pets', 404]),
  [superhashof({in => 'body', name => 'body', accepts => ['application/json']})], 'default response';

done_testing;
