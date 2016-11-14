use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojolicious::Lite;
use lib '.';
use t::Api;

sub t::Api::repeated_req {
  my ($c, $args, $cb) = @_;
  $c->$cb($args, 200);
}

plugin Swagger2 => {url => 'data://main/req.json'};

my $t = Test::Mojo->new;
$t->get_ok('/req/42')->status_is(200)->json_is('/x', [42]);
$t->get_ok('/req/42')->status_is(200)->json_is('/x', [42]);

done_testing;

__DATA__
@@ req.json
{
  "swagger" : "2.0",
  "info" : {
    "version": "1.0",
    "title" : "Repeated Requests get 400"
  },
  "paths" : {
    "/req/{x}" : {
      "get" : {
        "x-mojo-controller": "t::Api",
        "operationId" : "repeatedReq",
        "parameters" : [
          {
            "name": "x",
            "in": "path",
            "required": true,
            "type": "array",
            "items": { "type": "integer", "format": "int32" },
            "collectionFormat": "csv"
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
