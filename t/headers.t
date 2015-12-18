use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use t::Api;

use Mojolicious::Lite;
plugin Swagger2 => {url => 'data://main/headers.json'};

my $t = Test::Mojo->new;
$t->get_ok('/api/headers' => {'x-number' => 'x', 'x-string' => '123'})->status_is(400);

$t::Api::RES->{header} = 123;
$t->get_ok('/api/headers' => {'x-number' => 42.3, 'x-string' => '123'})->status_is(500)
  ->json_is('/errors/0/message', 'Expected string - got number.');

$t::Api::RES->{header} = '123';
$t->get_ok('/api/headers' => {'x-number' => 42.3, 'x-string' => '123'})->status_is(200)->json_is('/x-number', 42.3)
  ->header_is('what-ever', '123');

$t->get_ok('/api/headers' => {'x-bool' => 'true'})->status_is(200)->json_is('/x-bool', 1);

done_testing;

__DATA__
@@ headers.json
{
  "swagger" : "2.0",
  "info" : { "version": "9.1", "title" : "Test API for body parameters" },
  "consumes" : [ "application/json" ],
  "produces" : [ "application/json" ],
  "schemes" : [ "http" ],
  "basePath" : "/api",
  "paths" : {
    "/headers" : {
      "get" : {
        "x-mojo-controller": "t::Api",
        "operationId" : "getHeaders",
        "parameters" : [
          { "in": "header", "name": "x-number", "type": "number", "description": "desc..." },
          { "in": "header", "name": "x-string", "type": "string", "description": "desc..." }
          { "in": "header", "name": "x-bool", "type": "boolean", "description": "desc..." }
        ],
        "responses" : {
          "200" : {
            "description": "this is required",
            "headers": {
              "what-ever": {
                "type": "array",
                "items": { "type": "string" },
                "minItems": 1
              }
            },
            "schema": {
              "type" : "object"
            }
          }
        }
      }
    }
  }
}
