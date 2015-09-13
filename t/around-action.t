use Mojo::Base -strict;
use Mojolicious;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use t::Api;

for my $file (qw( around-action inherit-path inherit-global )) {
  my $app = Mojolicious->new;
  $app->plugin(Swagger2 => {url => "data://main/$file.json"});
  my $t = Test::Mojo->new($app);

  $t::Api::CODE = 401;
  $t::Api::RES = [{id => 123, name => "kit-cat"}];
  $t->get_ok('/api/pets')->status_is(401)->json_is('/operationId', 'listPets')->json_is('/x-mojo-controller', 't::Api')
    ->json_is('/x-mojo-around-action', 't::Api::authenticate')->json_is('/responses/200/description', 'anything');

  $t::Api::CODE = 200;
  $t->get_ok('/api/pets')->status_is(200);
}

done_testing;

__DATA__
@@ around-action.json
{
  "swagger": "2.0",
  "basePath": "/api",
  "paths": {
    "/pets": {
      "get": {
        "x-mojo-controller": "t::Api",
        "x-mojo-around-action": "t::Api::authenticate",
        "operationId": "listPets",
        "responses": {
          "200": {"description": "anything"}
        }
      }
    }
  }
}
@@ inherit-path.json
{
  "swagger": "2.0",
  "basePath": "/api",
  "paths": {
    "/pets": {
      "x-mojo-around-action": "t::Api::authenticate",
      "x-mojo-controller": "t::Api",
      "get": {
        "operationId": "listPets",
        "responses": {
          "200": {"description": "anything"}
        }
      }
    }
  }
}
@@ inherit-global.json
{
  "swagger": "2.0",
  "basePath": "/api",
  "x-mojo-around-action": "t::Api::authenticate",
  "x-mojo-controller": "t::Api",
  "paths": {
    "/pets": {
      "get": {
        "operationId": "listPets",
        "responses": {
          "200": {"description": "anything"}
        }
      }
    }
  }
}
