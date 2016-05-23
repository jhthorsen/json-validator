use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojolicious::Lite;

plugin Swagger2 => {url => 'data://main/multi-param.json'};

my $t = Test::Mojo->new;
$t->get_ok('/multi-param?x=13&x=3.14')->status_is(200)->json_is('/x', [13, 3.14]);
$t->get_ok('/multi-param?x=42')->status_is(200)->json_is('/x', [42]);

done_testing;

__DATA__
@@ multi-param.json
{
  "swagger" : "2.0",
  "info" : {
    "version": "1.0",
    "title" : "Test _not_implemented() in plugin"
  },
  "paths" : {
    "/multi-param" : {
      "get" : {
        "x-mojo-controller": "t::Api",
        "operationId" : "multiParam",
        "parameters" : [
          {
            "name": "x",
            "in": "query",
            "type": "array",
            "items": { "type": "number" },
            "collectionFormat": "multi"
          }
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
