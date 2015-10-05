use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Test::Warnings;
use File::Spec::Functions;
use t::Api;

use Mojolicious::Lite;
plugin Swagger2 => {url => 'data://main/bodytest.json'};

my $t = Test::Mojo->new;
$t::Api::RES = {};

# EXPERIMENTAL
ok $t->app->routes->lookup('t_api_add_pet'), 'add route add_pet';

# invalid input
$t->post_ok('/api/pets' => json => {id => 123})->status_is(400)->json_is('/errors/0/message', 'Missing property.')
  ->json_is('/errors/0/path', '/pet/name');

# invalid input
$t->post_ok('/api/pets' => json => {id => "123", name => "kit-cat"})->status_is(400)
  ->json_is('/errors/0/message', 'Expected integer - got string.')->json_is('/errors/0/path', '/pet/id');

# valid input and output
$t::Api::RES = [{id => 123, name => "kit-cat"}];
$t->post_ok('/api/pets' => json => {id => 123, name => "kit-cat"})->status_is(200)->json_is('/0/id', 123);

# do it again to check if clobbered
$t->post_ok('/api/pets' => json => {id => 123, name => "kit-cat"})->status_is(200)->json_is('/0/id', 123);

# invalid output
$t::Api::RES = [{id => "123", name => "kit-cat"}];
$t->post_ok('/api/pets' => json => {id => 123, name => "kit-cat"})->status_is(500)->json_is('/errors/0/path', '/0/id')
  ->json_is('/errors/0/message', 'Expected integer - got string.');

# invalid output
$t::Api::RES = {some_parent_key => {id => "123", name => "kit-cat"}};
$t->get_ok('/api/pets' => json => {id => 123, name => "kit-cat"})->status_is(500)
  ->json_is('/errors/0/path', '/some_parent_key/id')->json_is('/errors/0/message', 'Expected integer - got string.');

# invalid output
$t::Api::RES = {};
$t->post_ok('/api/pets' => json => {id => 123, name => "kit-cat"})->status_is(500)->json_is('/errors/0/path', '/')
  ->json_is('/errors/0/message', 'Expected array - got object.');

# no output rules defined
$t::Api::CODE = 204;
$t->post_ok('/api/pets' => json => {id => 123, name => "kit-cat"})->status_is(500)->json_is('/errors/0/path', '/')
  ->json_is('/errors/0/message', 'No validation rules defined.');

# empty document
$t::Api::CODE = 201;
$t->get_ok('/api/pets')->status_is(201)->content_is('');

done_testing;

__DATA__
@@ bodytest.json
{
  "swagger" : "2.0",
  "info" : { "version": "9.1", "title" : "Test API for body parameters" },
  "consumes" : [ "application/json" ],
  "produces" : [ "application/json" ],
  "schemes" : [ "http" ],
  "basePath" : "/api",
  "paths" : {
    "/pets" : {
      "get" : {
        "x-mojo-controller": "t::Api",
        "operationId" : "getPet",
        "responses" : {
          "200" : {
            "description": "this is required",
            "schema": {
              "type" : "object",
              "properties" : {
                "some_parent_key": {
                  "$ref": "#/definitions/Pet"
                }
              }
            }
          },
          "201": {
            "description": "empty body."
          }
        }
      },
      "post" : {
        "x-mojo-controller": "t::Api",
        "operationId" : "addPet",
        "parameters" : [
          {
            "name" : "pet",
            "schema" : { "$ref" : "#/definitions/Pet" },
            "in" : "body",
            "description" : "Pet object that needs to be added to the store"
          }
        ],
        "responses" : {
          "200": {
            "description": "pet response",
            "schema": {
              "type": "array",
              "items": { "$ref": "#/definitions/Pet" }
            }
          }
        }
      }
    }
  },
  "definitions" : {
    "Pet" : {
      "required" : ["name"],
      "properties" : {
        "id" : { "format" : "int64", "type" : "integer" },
        "name" : { "type" : "string" }
      }
    }
  }
}
