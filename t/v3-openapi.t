use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

plan skip_all => $@ unless eval { require Mojolicious::Plugin::OpenAPI };

use Mojolicious::Lite;

get '/pets/:petId' => sub {
  my $c = shift->openapi->valid_input or return;
  $c->render(openapi => {});
  },
  'showPetById';

get '/pets' => sub {
  my $c = shift->openapi->valid_input or return;
  $c->render(openapi => $c->param('limit') ? [] : {});
  },
  'listPets';

post '/pets' => sub {
  my $c = shift->openapi->valid_input or return;
  $c->render(text => '', status => 201);
  },
  'createPets';

eval { plugin OpenAPI => {url => 'data:///petstore.json', schema => 'v3'} };
ok !$@, 'valid openapi v3 schema' or diag $@;

my $t = Test::Mojo->new;
$t->get_ok('/pets?limit=invalid', {Accept => 'application/json'})->status_is(400)
  ->json_is('/errors/0/message', 'Expected integer - got string.');

# TODO: Should probably be 400
$t->get_ok('/pets?limit=10', {Accept => 'not/supported'})->status_is(500)
  ->json_is('/errors/0/message', 'No responses rules defined for type not/supported.');

$t->get_ok('/pets?limit=0', {Accept => 'application/json'})->status_is(500)
  ->json_is('/errors/0/message', 'Expected array - got object.');

$t->get_ok('/pets?limit=10', {Accept => 'application/json'})->status_is(200)->content_is('[]');

$t->get_ok('/pets?limit=10', {Accept => 'application/json'})->status_is(200)->content_is('[]');

$t->post_ok('/pets', {Accept => 'application/json', Cookie => 'debug=foo'})->status_is(400)
  ->json_is('/errors/0/message', 'Invalid Content-Type.')
  ->json_is('/errors/1/message', 'Expected integer - got string.');

$t->post_ok('/pets', {Cookie => 'debug=1'}, json => {id => 1, name => 'Supercow'})->status_is(201)
  ->content_is('');

$t->post_ok('/pets', form => {id => 1, name => 'Supercow'})->status_is(201)->content_is('');


done_testing;

__DATA__
@@ petstore.json
{
  "openapi": "3.0.0",
  "info": {
    "license": {
      "name": "MIT"
    },
    "title": "Swagger Petstore",
    "version": "1.0.0"
  },
  "servers": [
    { "url": "http://petstore.swagger.io/v1" }
  ],
  "paths": {
    "/pets/{petId}": {
      "get": {
        "operationId": "showPetById",
        "tags": [ "pets" ],
        "summary": "Info for a specific pet",
        "parameters": [
          {
            "description": "The id of the pet to retrieve",
            "in": "path",
            "name": "petId",
            "required": true,
            "schema": { "type": "string" }
          }
        ],
        "responses": {
          "default": {
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Error"
                }
              }
            },
            "description": "unexpected error"
          },
          "200": {
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Pets"
                }
              }
            },
            "description": "Expected response to a valid request"
          }
        }
      }
    },
    "/pets": {
      "get": {
        "operationId": "listPets",
        "summary": "List all pets",
        "tags": [ "pets" ],
        "parameters": [
          {
            "description": "How many items to return at one time (max 100)",
            "in": "query",
            "name": "limit",
            "required": false,
            "schema": { "type": "integer", "format": "int32" }
          }
        ],
        "responses": {
          "200": {
            "description": "An paged array of pets",
            "headers": {
              "x-next": {
                "schema": { "type": "string" },
                "description": "A link to the next page of responses"
              }
            },
            "content": {
              "application/json": {
                "schema": { "$ref": "#/components/schemas/Pets" }
              }
            }
          },
          "default": {
            "description": "unexpected error",
            "content": {
              "application/json": {
                "schema": { "$ref": "#/components/schemas/Error" }
              }
            }
          }
        }
      },
      "post": {
        "operationId": "createPets",
        "summary": "Create a pet",
        "tags": [ "pets" ],
        "parameters": [
          {
            "description": "Turn on/off debug",
            "in": "cookie",
            "name": "debug",
            "schema": {
              "type": "integer",
              "enum": [0, 1]
            }
          }
        ],
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": { "$ref": "#/components/schemas/Pet" }
            },
            "application/x-www-form-urlencoded": {
              "schema": { "$ref": "#/components/schemas/Pet" }
            }
          }
        },
        "responses": {
          "201": {
            "description": "Null response"
          },
          "default": {
            "description": "unexpected error",
            "content": {
              "application/json": {
                "schema": {
                  "$ref": "#/components/schemas/Error"
                }
              }
            }
          }
        }
      }
    }
  },
  "components": {
    "schemas": {
      "Pets": {
        "type": "array",
        "items": { "$ref": "#/components/schemas/Pet" }
      },
      "Pet": {
        "required": [ "id", "name" ],
        "properties": {
          "tag": { "type": "string" },
          "id": { "type": "integer", "format": "int64" },
          "name": { "type": "string" }
        }
      },
      "Error": {
        "required": [ "code", "message" ],
        "properties": {
          "code": { "format": "int32", "type": "integer" },
          "message": { "type": "string" }
        }
      }
    }
  }
}
