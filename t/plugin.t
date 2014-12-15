use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;

use Mojolicious::Lite;
plugin Swagger2 => {controller => 't::Api', url => 't/data/petstore.json'};

my $t = Test::Mojo->new;
ok $t->app->routes->lookup('list_pets_get'), 'add route list_pets_get';

$t::Api::RES = [{foo => 123, name => "kit-cat"}];
$t->get_ok('/api/pets')->status_is(500)->json_is('/errors/0/path', '/0/id')
  ->json_is('/errors/0/message', 'Missing property.')->json_is('/errors/1', undef);

$t::Api::RES = [{id => "123", name => "kit-cat"}];
$t->get_ok('/api/pets')->status_is(500)->json_is('/errors/0/path', '/0/id')
  ->json_is('/errors/0/message', 'Expected integer - got string.')->json_is('/errors/1', undef);

$t::Api::RES = [{id => 123, name => "kit-cat"}];
$t->get_ok('/api/pets')->status_is(200)->json_is('/0/id', 123)->json_is('/0/name', 'kit-cat');

$t::Api::RES = [{id => 123, name => "kit-cat"}];
$t->get_ok('/api/pets?limit=foo')->status_is(400)->json_is('/errors/0/path', '/limit')
  ->json_is('/errors/0/message', 'Expected integer - got string.')->json_is('/errors/1', undef);

$t::Api::RES = {name => "kit-cat"};
$t->get_ok('/api/pets/42')->status_is(200)->json_is('/id', 42)->json_is('/name', 'kit-cat');

$t->get_ok('/api/pets/foo')->status_is(400)->json_is('/errors/0/path', '/petId')
  ->json_is('/errors/0/message', 'Expected integer - got string.')->json_is('/errors/1', undef);

done_testing;
