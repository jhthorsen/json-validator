use Mojo::Base -strict;
use JSON::Validator::Schema::OpenAPIv3;
use Mojo::File;
use Test::More;

my $cwd    = Mojo::File->new(__FILE__)->dirname;
my $schema = JSON::Validator::Schema::OpenAPIv3->new;

is $schema->specification,
  'https://spec.openapis.org/oas/3.0/schema/2019-04-02', 'specification';
is $schema->base_url, '/', 'default base url';
is $schema->base_url('https://api.example.com/v1'), $schema, 'set base url';
is_deeply $schema->get('/servers'), [{url => 'https://api.example.com/v1'}],
  'base url saved in schema';
is int(keys %{$schema->formats}), 26, 'correct number of formats';

$schema->data($cwd->child(qw(spec v3-petstore.json)));
is @{$schema->errors}, 0, 'petstore errors' or diag explain $schema->errors;
is $schema->base_url, 'http://petstore.swagger.io/v1', 'petstore base url';

note 'default_response_schema';
$schema->ensure_default_response({codes => [404], name => 'CoolBeans'});
is_deeply $schema->get([qw(paths /pets get responses 404 content)]),
  {'application/json' =>
    {schema => {'$ref' => '#/components/schemas/CoolBeans'}}},
  'default response schema added for 404';
is $schema->get([qw(paths /pets get responses 401)]), undef,
  'did not add response schema added for 401';

$schema->ensure_default_response;
for my $code (400, 401, 404, 500, 501) {
  my $ref = sprintf '#/components/schemas/%s',
    $code == 404 ? 'CoolBeans' : 'DefaultResponse';
  is_deeply $schema->get([qw(paths /pets get responses), $code, 'content']),
    {'application/json' => {schema => {'$ref' => $ref}}},
    "default response schema added for $code";
}

is_deeply $schema->get([qw(components schemas CoolBeans)]),
  $schema->default_response_schema, 'schema CoolBeans added';
is_deeply $schema->get([qw(components schemas DefaultResponse)]),
  $schema->default_response_schema, 'schema DefaultResponse added';

done_testing;
