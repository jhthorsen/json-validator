use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use t::Api;

use Mojolicious::Lite;
plugin Swagger2 => {url => 'data://main/empty.json'};


my $t = Test::Mojo->new();
$t->get_ok('/api/empty/response')->status_is(500)
  ->json_is('/errors/0/message', 'No responses rules defined for status 200.');

$t::Api::CODE = 204;
$t->get_ok('/api/empty/response')->status_is(204)->content_is('');

done_testing;

__DATA__
@@ empty.json
{
  "swagger" : "2.0",
  "info" : { "version": "9.1", "title" : "Test API for body parameters" },
  "schemes" : [ "http" ],
  "basePath" : "/api",
  "paths" : {
    "/empty/response" : {
      "get" : {
        "x-mojo-controller": "t::Api",
        "operationId" : "empty",
        "responses" : {
          "204" : {
            "description": "this is required",
            "schema": { "type" : "string" }
          }
        }
      }
    }
  }
}
