use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Test::Warnings;
use File::Spec::Functions;
use t::Api;

use Mojolicious::Lite;
plugin Swagger2 => {url => 't/data/bodytest.json'};

my $t = Test::Mojo->new;
$t::Api::RES = {};

# EXPERIMENTAL
ok $t->app->routes->lookup('t_api_add_pet'), 'add route add_pet';

# invalid input
$t->post_ok('/api/pets' => json => {id => 123})->status_is(400)->json_is('/errors/0/message', 'Missing property.')
  ->json_is('/errors/0/path', '/pet/name');

# invalid input
$t->post_ok('/api/pets' => json => {id => "123", name => "kit-cat"})->status_is(400)
  ->json_is('/errors/0/message', 'Expected integer - got string.')->json_is('/errors/0/path', '/pet/id');

# valid input and output
$t::Api::RES = [{id => 123, name => "kit-cat"}];
$t->post_ok('/api/pets' => json => {id => 123, name => "kit-cat"})->status_is(200)->json_is('/0/id', 123);

# do it again to check if clobbered
$t->post_ok('/api/pets' => json => {id => 123, name => "kit-cat"})->status_is(200)->json_is('/0/id', 123);

# invalid output
$t::Api::RES = [{id => "123", name => "kit-cat"}];
$t->post_ok('/api/pets' => json => {id => 123, name => "kit-cat"})->status_is(500)->json_is('/errors/0/path', '/0/id')
  ->json_is('/errors/0/message', 'Expected integer - got string.');

# invalid output
$t::Api::RES = {some_parent_key => {id => "123", name => "kit-cat"}};
$t->get_ok('/api/pets' => json => {id => 123, name => "kit-cat"})->status_is(500)
  ->json_is('/errors/0/path', '/some_parent_key/id')->json_is('/errors/0/message', 'Expected integer - got string.');

# invalid output
$t::Api::RES = {};
$t->post_ok('/api/pets' => json => {id => 123, name => "kit-cat"})->status_is(500)->json_is('/errors/0/path', '/')
  ->json_is('/errors/0/message', 'Expected array - got object.');

# no output rules defined
$t::Api::CODE = 204;
$t->post_ok('/api/pets' => json => {id => 123, name => "kit-cat"})->status_is(500)->json_is('/valid', 0)
  ->json_is('/errors/0/path', '/')->json_is('/errors/0/message', 'No validation rules defined.');

# empty document
$t::Api::CODE = 201;
$t->get_ok('/api/pets')->status_is(201)->content_is('');

done_testing;
