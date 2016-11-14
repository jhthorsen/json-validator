use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use lib '.';
use t::Api;

use Mojolicious::Lite;
plugin Swagger2 => {url => 'data://main/nullable.json'};

my $t = Test::Mojo->new;

$t::Api::RES = {name => 123};
$t->get_ok('/pets')->status_is(500)->json_has('/errors');

$t::Api::RES = {name => 'batman'};
$t->get_ok('/pets')->status_is(200)->content_like(qr/"name":"batman"/);

$t::Api::RES = {name => undef};
$t->get_ok('/pets')->status_is(200)->content_like(qr/"name":null/);

done_testing;

__DATA__
@@ nullable.json
{
  "swagger" : "2.0",
  "info" : { "version": "9.1", "title" : "Test API for body parameters" },
  "paths" : {
    "/pets" : {
      "get" : {
        "x-mojo-controller": "t::Api",
        "operationId" : "listPets",
        "responses" : {
          "200" : {
            "description": "this is required",
            "schema": {
              "type" : "object",
              "properties" : {
                "name" : { "type" : ["null", "string"] }
              }
            }
          }
        }
      }
    }
  }
}
