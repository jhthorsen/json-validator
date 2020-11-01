use Mojo::Base -strict;
use JSON::Validator::Schema::OpenAPIv3;
use Mojo::File;
use Test::Deep;
use Test::More;

my $cwd    = Mojo::File->new(__FILE__)->dirname;
my $schema = JSON::Validator::Schema::OpenAPIv3->new;
my ($body, $p, @errors);

is $schema->specification, 'https://spec.openapis.org/oas/3.0/schema/2019-04-02', 'specification';
is_deeply $schema->coerce, {booleans => 1, numbers => 1, strings => 1}, 'default coercion';

note 'jv->schema';
$schema = JSON::Validator->new->schema($cwd->child(qw(spec v3-petstore.json)))->schema;
isa_ok $schema, 'JSON::Validator::Schema::OpenAPIv3';

note 'validate schema';
@errors = @{JSON::Validator->new->schema({openapi => '3.0.0', paths => {}})->schema->errors};
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

note 'validate_request';
$p      = Mojo::Parameters->new('limit=10&foo=42');
@errors = $schema->validate_request([get => '/pets'], {query => $p->to_hash});
is "@errors", '', 'limit ok, even as string';

@errors = $schema->validate_request([get => '/pets'], {query => {limit => 'foo'}});
is "@errors", '/limit: Expected integer - got string.', 'limit failed';

$body   = {content_type => 'text/plain'};
@errors = $schema->validate_request([POST => '/pets'], {body => \&body});
is "@errors", '/body: Expected application/json, application/x-www-form-urlencoded - got text/plain.',
  'invalid request content_type';
is_deeply $body, {content_type => 'text/plain', in => 'body', name => 'body'}, 'input was mutated';

$body   = {content_type => 'text/plain'};
@errors = $schema->validate_response([get => '/pets'], {body => \&body});
is "@errors", '/body: Expected application/json, application/xml - got text/plain.', 'invalid response content_type';
is_deeply $body, {content_type => 'text/plain', in => 'body', name => 'body'}, 'input was mutated';

$body   = {exists => 0};
@errors = $schema->validate_request([POST => '/pets'], {body => \&body});
is "@errors", '/body: Missing property.', 'default content type, but missing body';
is_deeply $body, {content_type => 'application/json', exists => 0, in => 'body', name => 'body'}, 'input was mutated';

$body   = {exists => 1, value => {name => 'kitty'}};
@errors = $schema->validate_request([POST => '/pets'], {body => \&body});
is "@errors", '/body/id: Missing property.', 'missing id in body';

$body   = {exists => 1, value => {id => 42, name => 'kitty'}};
@errors = $schema->validate_request([POST => '/pets'], {body => \&body});
is "@errors", '', 'valid request body';
is_deeply $body,
  {content_type => 'application/json', exists => 1, in => 'body', name => 'body', valid => 1, value => $body->{value}},
  'input was mutated';

note 'validate_response';
$body   = {exists => 1, value => {id => 42, name => 'kitty'}};
@errors = $schema->validate_response([POST => '/pets', 201], {});
is "@errors", '', 'valid response body 201';

$body   = {exists => 1, value => {code => 42}};
@errors = $schema->validate_response([post => '/pets', 200], {body => \&body});
is "@errors", '/body/message: Missing property.', 'valid response body default';

done_testing;

sub body {$body}
