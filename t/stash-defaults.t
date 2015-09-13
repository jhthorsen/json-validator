use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use t::Api;

my $stash;

use Mojolicious::Lite;
plugin 'Swagger2' => {url => "data://main/stash.json"};
hook after_dispatch => sub { $stash = shift->stash };

$t::Api::CODE = 200;
Test::Mojo->new->get_ok('/api/pets')->status_is(200);

ok +UNIVERSAL::isa($stash->{swagger}, 'Swagger2'), 'swagger is set in stash';
is $stash->{swagger}->api_spec->get('/basePath'), '/api', 'basePath';

ok +UNIVERSAL::isa($stash->{swagger_operation_spec}, 'HASH'), 'swagger_operation_spec is set in stash';
is $stash->{swagger_operation_spec}{operationId}, 'listPets', 'operationId';

done_testing;

__DATA__
@@ stash.json
{
  "swagger": "2.0",
  "basePath": "/api",
  "paths": {
    "/pets": {
      "get": {
        "x-mojo-controller": "t::Api",
        "operationId": "listPets",
        "responses": {
          "200": {"description": "anything"}
        }
      }
    }
  }
}
