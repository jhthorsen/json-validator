use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

plan skip_all => 'Mojolicious::Plugin::OpenAPI is required'
  unless eval { require Mojolicious::Plugin::OpenAPI };

use Mojolicious::Lite;
get '/echo' => sub {
  my $c = shift;
  return if $c->openapi->invalid_input;
  return $c->reply->openapi(200 => {bool => $c->param('bool')});
  },
  'echo';

get '/echo/:whatever' => sub {
  my $c = shift;
  return if $c->openapi->invalid_input;
  return $c->reply->openapi(
    200 => {this_stack => $c->match->stack->[-1], whatever => $c->param('whatever')});
  },
  'whatever';

plugin OpenAPI => {url => 'data://main/echo.json'};

my $t = Test::Mojo->new;
$t->get_ok('/api/echo?bool=false')->status_is(200)->json_is('/bool' => Mojo::JSON->false);
$t->get_ok('/api/echo?bool=true')->status_is(200)->json_is('/bool' => Mojo::JSON->true);
$t->get_ok('/api/echo')->status_is(200)->json_is('/bool' => Mojo::JSON->true);

$t->get_ok('/api/echo/something')->status_is(200)->json_is('/this_stack/whatever' => 'something')
  ->json_is('/whatever' => 'something');

done_testing;

__DATA__
@@ echo.json
{
  "swagger": "2.0",
  "info": { "version": "0.8", "title": "Pets" },
  "schemes": [ "http" ],
  "basePath": "/api",
  "paths": {
    "/echo/{whatever}": {
      "get": {
        "x-mojo-name": "whatever",
        "parameters": [
          { "in": "path", "name": "whatever", "type": "string", "required": true }
        ],
        "responses": {
          "200": {
            "description": "Echo response",
            "schema": { "type": "object" }
          }
        }
      }
    },
    "/echo": {
      "get": {
        "x-mojo-name": "echo",
        "parameters": [
          { "in": "query", "name": "bool", "type": "boolean", "default": true }
        ],
        "responses": {
          "200": {
            "description": "Echo response",
            "schema": { "type": "object" }
          }
        }
      }
    }
  }
}
