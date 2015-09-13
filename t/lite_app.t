{
  # lite app
  use Mojolicious::Lite;
  my $id = 0;
  my %pets;

  plugin Swagger2 => {
    url        => 'data://main/petstore.json',
    operations => {
      addPet => sub {
        my ($c, $args, $cb) = @_;
        $args->{data}{id} = ++$id;
        $pets{$id} = $args->{data};
        $c->$cb($args->{data}, 200);
      },
      listPets => sub {
        my ($c, $args, $cb) = @_;
        $c->$cb([values %pets], 200);
      },
      showPetById => sub {
        my ($c, $args, $cb) = @_;
        return $c->$cb({}, 404) unless $pets{$args->{petId}};
        return $c->$cb($pets{$args->{petId}}, 200);
      }
    }
  };
}

{
  # test code
  use Mojo::Base -strict;
  use Test::Mojo;
  use Test::More;
  my $t = Test::Mojo->new;

  $t->get_ok('/api/pets')->status_is(200)->content_is('[]');
  $t->post_ok('/api/pets', json => {name => 'bob', tag => 'cat'})->status_is(200);
  $t->get_ok('/api/pets/1')->status_is(200)->json_is('/name', 'bob');
}

done_testing;

__DATA__
@@ petstore.json
{
  "swagger": "2.0",
  "info": {
    "version": "1.0.0",
    "title": "Swagger Petstore",
    "contact": { "name": "wordnik api team", "url": "http://developer.wordnik.com" },
    "license": { "name": "Creative Commons 4.0 International", "url": "http://creativecommons.org/licenses/by/4.0/" }
  },
  "basePath": "/api",
  "parameters": {
    "limit": {
      "name": "limit",
      "in": "query",
      "description": "How many items to return at one time (max 100)",
      "required": false,
      "type": "integer",
      "format": "int32"
    }
  },
  "paths": {
    "/pets": {
      "get": {
        "tags": [ "pets" ],
        "summary": "finds pets in the system",
        "operationId": "listPets",
        "parameters": [
          { "$ref": "#/parameters/limit" }
        ],
        "responses": {
          "200": {
            "description": "pet response",
            "schema": {
              "type": "array",
              "items": { "$ref": "#/definitions/Pet" }
            },
            "headers": { }
          },
          "default": {
            "description": "unexpected error",
            "schema": { "$ref": "#/definitions/Error" }
          }
        }
      },
      "post": {
        "tags": [ "pets" ],
        "summary": "add pets to the system",
        "operationId": "addPet",
        "parameters": [
          {
            "name": "data",
            "in": "body",
            "required": true,
            "schema": {
              "type": "object",
              "parameters": {
                "name": { "type": "string" },
                "tag": { "type": "string" }
              }
            }
          }
        ],
        "responses": {
          "200": {
            "description": "pet response",
            "schema": { "$ref": "#/definitions/Pet" }
          },
          "default": {
            "description": "unexpected error",
            "schema": { "$ref": "#/definitions/Error" }
          }
        }
      }
    },
    "/pets/{petId}": {
      "get": {
        "tags": [ "pets" ],
        "summary": "Info for a specific pet",
        "operationId": "showPetById",
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
          "200": {
            "description": "Expected response to a valid request",
            "schema": { "$ref": "#/definitions/Pet" }
          },
          "default": {
            "description": "unexpected error",
            "schema": { "$ref": "#/definitions/Error" }
          }
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
    },
    "Error": {
      "required": [ "code", "message" ],
      "properties": {
        "code": { "type": "integer", "format": "int32" },
        "message": { "type": "string" }
      }
    }
  }
}
