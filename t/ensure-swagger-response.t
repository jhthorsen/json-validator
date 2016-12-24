use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use lib '.';
use t::Api;

use Mojolicious::Lite;
plugin Swagger2 => {ensure_swagger_response => {}, url => 'data://main/bodytest.json'};

my $t = Test::Mojo->new;
$t::Api::ERR = 'ooops!';
$t->get_ok('/api/pets')->status_is(500)->json_is('/errors/0/path', '/')
  ->json_is('/errors/0/message', 'Internal server error.');

$t->get_ok('/api/no_such_resource')->status_is(404)->json_is('/errors/0/path', '/')
  ->json_is('/errors/0/message', 'Not found.');

$t->get_ok('/no_such_resource')->status_is(404)->content_unlike(qr/^{/);

done_testing;

__DATA__
@@ bodytest.json
{
  "swagger" : "2.0",
  "info" : { "version": "9.1", "title" : "Test API for body parameters" },
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
              "type" : "object"
            }
          },
          "201": {
            "description": "empty body."
          }
        }
      }
    }
  }
}
