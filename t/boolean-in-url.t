use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;

plugin Swagger2 => {url => 'data://main/boolean-in-url.json'};

my $t = Test::Mojo->new;
$t->get_ok('/boolean-in-url/false?q1=true')->status_is(200);
like $t->tx->res->body, qr{"p1":false}, 'p1 false';
like $t->tx->res->body, qr{"q1":true},  'q1 true';

$t->get_ok('/boolean-in-url/true')->status_is(200);
like $t->tx->res->body, qr{"p1":true}, 'p1 true';
like $t->tx->res->body, qr{"q1":null}, 'q1 null';

$t->get_ok('/boolean-in-url/1')->status_is(200);
like $t->tx->res->body, qr{"p1":true}, 'p1 1';

$t->get_ok('/boolean-in-url/0')->status_is(200);
like $t->tx->res->body, qr{"p1":false}, 'p1 0';

done_testing;

__DATA__
@@ boolean-in-url.json
{
  "swagger" : "2.0",
  "info" : {
    "version": "1.0",
    "title" : "Test _not_implemented() in plugin"
  },
  "paths" : {
    "/boolean-in-url/{p1}" : {
      "get" : {
        "x-mojo-controller": "t::Api",
        "operationId" : "BooleanInUrl",
        "parameters" : [
          { "name": "p1", "type": "boolean", "in": "path", "required": true },
          { "name": "q1", "type": "boolean", "in": "query" }
        ],
        "responses" : {
          "200" : {
            "description": "whatever",
            "schema" : {
              "type": "object"
            }
          }
        }
      }
    }
  }
}
