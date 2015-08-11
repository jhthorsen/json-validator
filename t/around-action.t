use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;
use t::Api;

plugin Swagger2 => {url => 't/data/around-action.json'};

my $t = Test::Mojo->new;

$t::Api::CODE = 401;
$t::Api::RES = [{id => 123, name => "kit-cat"}];
$t->get_ok('/api/pets')->status_is(401)->json_is('/operationId', 'listPets')->json_is('/x-mojo-controller', 't::Api')
  ->json_is('/x-mojo-around-action', 't::Api::authenticate')->json_is('/responses/200/description', 'anything');

$t::Api::CODE = 200;
$t->get_ok('/api/pets')->status_is(200);

done_testing;
