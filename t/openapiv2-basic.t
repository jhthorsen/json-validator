use Mojo::Base -strict;
use JSON::Validator::Schema::OpenAPIv2;
use Mojo::File;
use Test::More;

my $cwd    = Mojo::File->new(__FILE__)->dirname;
my $schema = JSON::Validator::Schema::OpenAPIv2->new;

is $schema->specification, 'http://swagger.io/v2/schema.json', 'specification';
is $schema->base_url, '/', 'default base url';
is $schema->base_url('https://api.example.com/v1'), $schema, 'set base url';
is_deeply $schema->get('/schemes'), ['https'], 'schemes saved';
is $schema->get('/host'),     'api.example.com', 'host saved';
is $schema->get('/basePath'), '/v1',             'basePath saved';
is int(keys %{$schema->formats}), 15, 'correct number of formats';

$schema->data($cwd->child(qw(spec v2-petstore.json)));
is @{$schema->errors}, 0, 'petstore errors' or diag explain $schema->errors;
is $schema->base_url, 'http://petstore.swagger.io/v1', 'petstore base url';

note 'default_response_schema';
$schema->ensure_default_response({codes => [404], name => 'CoolBeans'});
is_deeply $schema->get([qw(paths /pets get responses 404)]),
  {
  description => 'Default response.',
  schema      => {'$ref' => '#/definitions/CoolBeans'}
  },
  'default response schema added for 404';
is $schema->get([qw(paths /pets get responses 401)]), undef,
  'did not add response schema added for 401';

$schema->ensure_default_response;
for my $code (400, 401, 404, 500, 501) {
  my $ref = sprintf '#/definitions/%s',
    $code == 404 ? 'CoolBeans' : 'DefaultResponse';
  is_deeply $schema->get([qw(paths /pets get responses), $code]),
    {description => 'Default response.', schema => {'$ref' => $ref}},
    "default response schema added for $code";
}

is_deeply $schema->get([qw(definitions CoolBeans)]),
  $schema->default_response_schema, 'schema CoolBeans added';
is_deeply $schema->get([qw(definitions DefaultResponse)]),
  $schema->default_response_schema, 'schema DefaultResponse added';

is $schema->get([qw(info version)]), '1.0.0', 'version from schema';
$schema->version_from_class('main')
  ->data($cwd->child(qw(spec v2-petstore.json)));
is $schema->get([qw(info version)]), '1.0.0', 'version from invalid class';

Mojo::Util::monkey_patch(main => VERSION => sub {'2.0'});
$schema->version_from_class('main')
  ->data($cwd->child(qw(spec v2-petstore.json)));
is $schema->get([qw(info version)]), '2.0', 'version from class';

done_testing;
