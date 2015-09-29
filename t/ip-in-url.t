use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;

plugin Swagger2 => {url => 'data://main/ip-in-url.json'};

my $t = Test::Mojo->new;
$t->get_ok('/ip/1.2.3.4/stuff')->status_is(200)->json_is('/ip', '1.2.3.4');

done_testing;

__DATA__
@@ ip-in-url.json
{
  "swagger" : "2.0",
  "info" : {
    "version" : "0.76",
    "title" : "Test _not_implemented() in plugin"
  },
  "paths" : {
    "/ip/{ip}/stuff" : {
      "get" : {
        "x-mojo-controller": "t::Api",
        "operationId" : "IpInUrl",
        "parameters" : [
          { "name": "ip", "type": "string", "in": "path", "required" : true, "x-mojo-placeholder": "#" }
        ],
        "responses" : {
          "200" : {
            "description" : "",
            "schema" : {
              "type": "object"
            }
          }
        }
      }
    }
  }
}
