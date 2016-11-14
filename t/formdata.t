use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Test::Warnings;
use File::Spec::Functions;
use lib '.';
use t::Api;

use Mojolicious::Lite;
plugin Swagger2 => {url => 'data://main/formdata.json'};

my $t = Test::Mojo->new;
$t::Api::RES = [];

# invalid input
$t->post_ok('/api/pets' => form => {id => 123})->status_is(400)
  ->json_is('/errors/0/message', 'Expected string - got null.')->json_is('/errors/0/path', '/name');

# invalid input
$t->post_ok('/api/pets' => form => {id => "invalid", name => "kit-cat"})->status_is(400)
  ->json_is('/errors/0/message', 'Expected integer - got string.')
  ->json_is('/errors/0/path',    '/id');

# valid input and output
$t::Api::RES = [{id => 123, name => "kit-cat"}];
$t->post_ok('/api/pets' => form => {id => 123, name => "kit-cat"})->status_is(200)
  ->json_is('/0/id', 123);

# do it again to check if clobbered
$t->post_ok('/api/pets' => form => {id => 123, name => "kit-cat"})->status_is(200)
  ->json_is('/0/id', 123);

$t->post_ok('/api/pets/avatar' => form => {})->status_is(400)
  ->json_is('/errors/0/message', 'Missing property.')->json_is('/errors/0/path', '/data');

$t->post_ok('/api/pets/avatar' => form => {data => {file => __FILE__}})->status_is(200)
  ->content_like(qr{whatever is here});

done_testing;

__DATA__
@@ formdata.json
{
  "swagger" : "2.0",
  "info" : { "version": "0.8", "title" : "Test API for body parameters" },
  "consumes" : [ "application/json" ],
  "produces" : [ "application/json" ],
  "schemes" : [ "http" ],
  "basePath" : "/api",
  "paths" : {
    "/pets" : {
      "post" : {
        "x-mojo-controller": "t::Api",
        "operationId" : "addPet",
        "parameters" : [
          { "name" : "name", "type" : "string", "in" : "formData", "required": true },
          { "name" : "id", "type" : "integer", "in" : "formData", "required": true }
        ],
        "responses" : {
          "200": {
            "description": "pet response",
            "schema": {
              "type": "array",
              "items": {}
            }
          }
        }
      }
    },
    "/pets/avatar" : {
      "post" : {
        "x-mojo-controller": "t::Api",
        "operationId" : "addImage",
        "parameters" : [
          { "name" : "data", "type" : "file", "in" : "formData", "required": true }
        ],
        "responses" : {
          "200": {
            "description": "pet response",
            "schema": {
              "type": "file"
            }
          }
        }
      }
    }
  }
}
