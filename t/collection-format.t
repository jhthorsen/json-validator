use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;
use t::Api;

plugin Swagger2 => {ensure_swagger_response => {}, url => 'data://main/collection-format.json'};

my $t = Test::Mojo->new;
$t->get_ok('/collection/format/integer?foo=1|2|3')->status_is(200)->content_is('{"foo":[1,2,3]}');
$t->get_ok('/collection/format/number?foo=1.42 2 3.14')->status_is(200)->content_is('{"foo":[1.42,2,3.14]}');
$t->get_ok('/collection/format/string?foo=1,x,3')->status_is(200)->content_is('{"foo":["1","x","3"]}');
$t->get_ok('/collection/format/string?foo=x')->status_is(200)->content_is('{"foo":["x"]}');

done_testing;

__DATA__
@@ collection-format.json
{
  "info" : {"title" : "Example", "version" : "0.0.0"},
  "swagger" : "2.0",
  "paths" : {
    "/collection/format/integer" : {
      "get" : {
        "x-mojo-controller": "t::Api",
        "operationId": "collectionFormat",
        "parameters" : [
          { "collectionFormat" : "pipes", "items" : {"type" : "integer"}, "name" : "foo", "in" : "query", "type" : "array" }
        ],
        "responses" : {"200" : {"description" : "OK"}}
      }
    },
    "/collection/format/number" : {
      "get" : {
        "x-mojo-controller": "t::Api",
        "operationId": "collectionFormat",
        "parameters" : [
          { "collectionFormat" : "ssv", "items" : {"type" : "number"}, "name" : "foo", "in" : "query", "type" : "array" }
        ],
        "responses" : {"200" : {"description" : "OK"}}
      }
    },
    "/collection/format/string" : {
      "get" : {
        "x-mojo-controller": "t::Api",
        "operationId": "collectionFormat",
        "parameters" : [
          { "collectionFormat" : "csv", "items" : {"type" : "string"}, "name" : "foo", "in" : "query", "type" : "array" }
        ],
        "responses" : {"200" : {"description" : "OK"}}
      }
    }
  }
}
