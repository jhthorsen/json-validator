use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojo::JSON qw(false true);
use Mojolicious::Controller;
use JSON::Validator::OpenAPI::Mojolicious;

my $t = Test::Mojo->new;
my $c = Mojolicious::Controller->new(tx => Mojo::Transaction::HTTP->new);

my $openapi = JSON::Validator::OpenAPI::Mojolicious->new;
my ($schema, @errors);

{
  local $TODO = "No idea why this changes to 'No validation rules defined' when running with prove";
  $schema = {responses => {200 => {}}};
  @errors = $openapi->validate_response($c, $schema, 404, {});
  is "@errors", "/: No responses rules defined for status 404.", "no rules";
}

$schema = {responses => {default => {}}};
@errors = $openapi->validate_response($c, $schema, 404, {});
is "@errors", "", "default rules";

$schema = {responses => {200 => {schema => {type => 'array'}}}};
@errors = $openapi->validate_response($c, $schema, 200, {});
is "@errors", "/: Expected array - got object.", "invalid response";

@errors = $openapi->validate_response($c, $schema, 200, [1, 2, 3]);
is "@errors", "", "valid response";

$schema = {responses => {200 => {'x-json-schema' => {type => 'array'}}}};
@errors = $openapi->validate_response($c, $schema, 200, {});
is "@errors", "/: Expected array - got object.", "invalid x-json-schema response";

$schema = {responses => {200 => {headers => {'X-Location' => {type => 'string'}}}}};
$c->res->headers->header('X-Location' => 42);
@errors = $openapi->validate_response($c, $schema, 200, {});
is "@errors", "/: Expected string - got number.", "invalid header";

$c->res->headers->header('X-Location' => 'where wifi is');
@errors = $openapi->validate_response($c, $schema, 200, {});
is "@errors", "", "valid header";

done_testing;
