use Mojo::Base -strict;
use Mojolicious;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use lib '.';
use t::Api;

#Run this test 11 times, to make sure that we can reproduce the bug which happens 50% of time.
#If /pets/{petnumber} is added to Mojolicious before /pets/status, /pets/{petnumber} overlaps
#/pets/status and all requests which should go to /pets/status are instead put to /pets/{petnumber}.
#Making sure we introduce new routes shortest route first

subtest "Lenghtwise Route introduction" => \&testRandomRouteIntroduction;

sub testRandomRouteIntroduction {
  foreach (0 .. 10) {
    my $app = Mojolicious->new;
    $app->plugin(Swagger2 => {url => "data://main/lenghtwise.json"});
    my $t = Test::Mojo->new($app);

    $t::Api::CODE = 200;
    $t::Api::RES = {stat_tus => 'ok'};
    $t->get_ok('/api/pets/status')->status_is(200)->json_is('/status/stat_tus', 'ok');

    $t->get_ok('/api/pets/5')->status_is(200)->json_is('/stat_tus', 'ok');
  }
}

done_testing;

__DATA__
@@ lenghtwise.json
{
  "swagger": "2.0",
  "info": {
    "version": "0.9",
    "title": "sort by length"
  },
  "basePath": "/api",
  "paths": {
    "/pets/status": {
      "get": {
        "x-mojo-controller": "t::Api",
        "operationId": "status",
        "responses": {
          "200": {"description": "anything"}
        }
      }
    },
    "/pets/{petnumber}": {
      "get": {
        "x-mojo-controller": "t::Api",
        "operationId": "getPet",
        "parameters": [
          {
            "name": "petnumber",
            "in": "path",
            "required": true,
            "type": "integer"
          }
        ],
        "responses": {
          "200": {"description": "anything"}
        }
      }
    }
  }
}
