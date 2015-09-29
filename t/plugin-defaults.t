use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;

plugin Swagger2 => {url => 'data://main/with-defaults.json'};

my $t = Test::Mojo->new;
$t->get_ok('/ip?x=123')->status_is(200)->json_is('/ip', '1.2.3.4')->json_is('/x', '123');
$t->get_ok('/ip/2.3.4.5')->status_is(200)->json_is('/ip', '2.3.4.5')->json_is('/x', 'xyz');
$t->get_ok('/ip/2345')->status_is(400)->json_is('/ip', undef);

done_testing;

__DATA__
@@ with-defaults.json
{
  "swagger" : "2.0",
  "info" : {
    "version": "0.1",
    "title" : "Test _not_implemented() in plugin"
  },
  "paths" : {
    "/ip/{ip}" : {
      "get" : {
        "x-mojo-controller": "t::Api",
        "operationId" : "WithDefaults",
        "parameters" : [
          {
            "name": "ip",
            "in": "path",
            "type": "string",
            "format": "ipv4",
            "default": "1.2.3.4",
            "required": true,
            "x-mojo-placeholder": "#"
          },
          {
            "name": "x",
            "in": "query",
            "type": "string",
            "default": "xyz"
          }
        ],
        "responses" : {
          "200" : {
            "description": "yay!",
            "schema" : {
              "type": "object"
            }
          }
        }
      }
    }
  }
}
