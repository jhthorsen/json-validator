use Mojo::Base -strict;
use JSON::Validator::Schema::OpenAPIv3;
use Mojo::File;
use Test::Deep;
use Test::More;

my $cwd    = Mojo::File->new(__FILE__)->dirname;
my $schema = JSON::Validator::Schema::OpenAPIv3->new;

is $schema->specification, 'https://spec.openapis.org/oas/3.0/schema/2019-04-02', 'specification';
is_deeply $schema->coerce, {booleans => 1, numbers => 1, strings => 1}, 'default coercion';

note 'jv->schema';
$schema = JSON::Validator->new->schema($cwd->child(qw(spec v3-petstore.json)))->schema;
isa_ok $schema, 'JSON::Validator::Schema::OpenAPIv3';

note 'validate schema';
my @errors = @{JSON::Validator->new->schema({openapi => '3.0.0', paths => {}})->schema->errors};
is "@errors", '/info: Missing property.', 'invalid schema';

note 'parameters_for_request';
is $schema->parameters_for_request([GET => '/pets/nope']), undef, 'no such path';
cmp_deeply $schema->parameters_for_request([GET => '/pets']), [superhashof({in => 'query', name => 'limit'})],
  'parameters_for_request inside path';

cmp_deeply $schema->parameters_for_request([post => '/pets']),
  [
  superhashof({in => 'cookie', name => 'debug'}),
  superhashof({in => 'body',   name => 'body', accepts => [qw(application/json application/x-www-form-urlencoded)]})
  ],
  'parameters_for_request for body';
cmp_deeply $schema->parameters_for_request([get => '/pets/{petId}']),
  [superhashof({in => 'path', name => 'petId'}), superhashof({in => 'query', name => 'wantAge'})],
  'parameters_for_request inside method';

note 'parameters_for_response';
is $schema->parameters_for_response([GET => '/pets/nope']), undef, 'no such path';
cmp_deeply $schema->parameters_for_response([GET => '/pets']),
  [
  superhashof({in => 'header', name => 'x-next'}),
  superhashof({in => 'body',   name => 'body', accepts => [qw(application/json application/xml)]}),
  ],
  'parameters_for_request inside path and default response code';
cmp_deeply $schema->parameters_for_response([GET => '/pets', 404]),
  [superhashof({in => 'body', name => 'body', accepts => [qw(application/json application/xml)]})], 'default response';

done_testing;
