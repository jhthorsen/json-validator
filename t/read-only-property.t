use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;

plugin Swagger2 => {url => 'data://main/ro.json'};

my $t = Test::Mojo->new;

$t->post_ok('/pets', json => {})->status_is(400)
  ->json_is('/errors', [{message => 'Missing property.', path => '/body/name'}]);

$t->post_ok('/pets', json => {name => 'batman'})->status_is(200);

$t->post_ok('/pets', json => {name => 'batman', id => 123})
  ->json_is('/errors/0', {message => 'Read-only.', path => '/body/id'});

$t->get_ok('/pet/123')->status_is(500)->json_is('/errors', [{message => 'Missing property.', path => '/name'}])
  ->content_unlike(qr{\W+id});

done_testing;

__DATA__
@@ ro.json
{
  "swagger" : "2.0",
  "info" : {
    "version" : "0.76",
    "title" : "Test readOnly in properties"
  },
  "paths" : {
    "/pets" : {
      "post" : {
        "x-mojo-controller": "t::Api",
        "operationId" : "addPet",
        "parameters" : [
          { "in": "body", "name": "body", "schema": { "$ref": "#/definitions/User" }, "required": true }
        ],
        "responses" : {
          "200" : { "schema" : { "type": "object" }, "description" : "" }
        }
      }
    },
    "/pet/{petId}" : {
      "get": {
        "x-mojo-controller": "t::Api",
        "operationId" : "showPetById",
        "parameters" : [
          {
            "name": "petId",
            "in": "path",
            "type": "integer",
            "required": true
          }
        ],
        "responses" : {
          "200" : { "schema" : { "$ref": "#/definitions/User" }, "description" : "" }
        }
      }
    }
  },
  "definitions": {
    "User": {
      "required": [ "id", "name" ],
      "properties": {
        "id": {
          "type": "number",
          "readOnly": true
        },
        "name": {
          "type": "string"
        }
      }
    }
  }
}
