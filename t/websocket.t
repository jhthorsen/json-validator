use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;
use lib catdir qw( t lib );

my $ws = app->routes->websocket('/ws')->to(
  cb => sub {
    shift->on(
      json => sub {
        my ($c, $data) = @_;
        return if $c->dispatch_to_swagger($data);
        return $c->send({json => {errors => [{message => 'Unable to dispatch_to_swagger', path => ''}]}});
      }
    );
  }
);

plugin Swagger2 => {url => 'data://main/petstore.json', ws => $ws};
app->routes->namespaces(['MyApp::Controller']);

my $t = Test::Mojo->new;

$t->websocket_ok('/ws');

$t->send_ok({json => {id => 42, op => 'foo', params => {}}})->message_ok->json_message_is('/id', 42)
  ->json_message_is('/code', 400)->json_message_is('/body/errors/0/message', 'Unknown operationId.');

$MyApp::Controller::Pet::RES = [{foo => 123, name => 'kit-cat'}];
$t->send_ok({json => {id => 43, op => 'listPets', params => {}}})->message_ok->json_message_is('/id', 43)
  ->json_message_is('/code', 200)->json_message_is('/body/0/name', 'kit-cat');

$MyApp::Controller::Pet::RES = [{id => '123', name => 'kit-cat'}];
$t->send_ok({json => {id => 44, op => 'listPets', params => {}}})->message_ok->json_message_is('/id', 44)
  ->json_message_is('/code', 500)->json_message_is('/body/errors/0/message', 'Expected integer - got string.');

$MyApp::Controller::Pet::RES = {id => 123, name => 'kit-cat'};
$t->send_ok({json => {id => 44, op => 'updatePetById', params => {petId => 'foo'}}})
  ->message_ok->json_message_is('/id', 44)->json_message_is('/code', 400)
  ->json_message_is('/body/errors/0/path',    '/petId')
  ->json_message_is('/body/errors/0/message', 'Expected integer - got string.');

$t->send_ok({json => {id => 45, op => 'updatePetById', params => {petId => 123}}})
  ->message_ok->json_message_is('/id', 45)->json_message_is('/code', 200);

done_testing;

__DATA__
@@ petstore.json
{
  "swagger": "2.0",
  "info": { "version": "1.0.0", "title": "Swagger Petstore" },
  "basePath": "/api",
  "paths": {
    "/pets": {
      "get": {
        "operationId": "listPets",
        "responses": {
          "200": { "description": "pet response", "schema": { "type": "array", "items": { "$ref": "#/definitions/Pet" } } }
        }
      }
    },
    "/pets/{petId}": {
      "post": {
        "operationId": "updatePetById",
        "parameters": [
          {
            "name": "petId",
            "in": "path",
            "required": true,
            "description": "The id of the pet to receive",
            "type": "integer"
          }
        ],
        "responses": {
          "200": { "description": "Expected response to a valid request", "schema": { "$ref": "#/definitions/Pet" } }
        }
      }
    }
  },
  "definitions": {
    "Pet": {
      "required": [ "id", "name" ],
      "properties": {
        "id": { "type": "integer", "format": "int64" },
        "name": { "type": "string" },
        "tag": { "type": "string" }
      }
    }
  }
}
