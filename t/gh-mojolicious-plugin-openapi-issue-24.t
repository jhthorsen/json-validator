use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojo::JSON;

eval {
  use Mojolicious::Lite;
  plugin OpenAPI => {url => 'data://main/boolean_default.yml'};
  1;
} or do {
  plan skip_all => $@;
};

my $t = Test::Mojo->new;
$t->get_ok('/api')->status_is(200)
  ->json_is('/definitions/data/properties/bool_value/default', Mojo::JSON->false);

done_testing;

__DATA__
@@ boolean_default.yml
---
swagger: '2.0'
info:
  version: '0.8'
  title: Pets
schemes: [ http ]
basePath: "/api"
paths:
  /echo:
    post:
      x-mojo-name: echo
      parameters:
      - in: body
        name: body
        schema:
          type: object
      responses:
        200:
          description: Echo response
          schema:
            $ref: '#/definitions/data'

definitions:
  data:
    type: object
    properties:
      bool_value:
        type: boolean
        default: false
