use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Test::Warnings;
use t::Api;

use Mojolicious::Lite;
plugin Swagger2 => {url => 'data://main/bodytest.json'};

my $t = Test::Mojo->new;
$t::Api::RES = [];

# invalid input
$t->patch_ok('/api/pets' => json => {id => 123, name => "kit-cat"})->status_is(400);

# valid input and output
$t::Api::RES = [{"op" => "test", "path" => "/a/b/c", "value" => "foo"}];
$t->patch_ok('/api/pets' => json => [{"op" => "test", "path" => "/a/b/c", "value" => "foo"}])->status_is(226);

# invalid output
$t::Api::RES = [{op => "add"}];
$t->patch_ok('/api/pets' => json => [{"op" => "test", "path" => "/a/b/c", "value" => "foo"}])->status_is(500)
  ->json_is('/errors/0/path', '/0/path')->json_is('/errors/0/message', 'Missing property.');

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
      "patch" : {
        "x-mojo-controller": "t::Api",
        "operationId" : "jsonPatchPet",
        "parameters" : [
          {
            "name" : "patch",
            "schema": {
              "type": "object"
            },
            "x-json-schema": {
              "$ref": "http://json.schemastore.org/json-patch"
            },
            "in" : "body",
            "required": true,
            "description" : "Patch object to update pet"
          }
        ],
        "responses" : {
          "226": {
            "description": "pet response",
            "schema": {
              "type": "object"
            },
            "x-json-schema": {
              "$ref": "http://json.schemastore.org/json-patch"
            }
          }
        }
      }
    }
  }
}
