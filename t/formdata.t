use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Test::Warnings;
use File::Spec::Functions;
use t::Api;

use Mojolicious::Lite;
plugin Swagger2 => {url => 't/data/formdata.json'};

my $t = Test::Mojo->new;
$t::Api::RES = {};

# invalid input
$t->post_ok('/api/pets' => form => {id => 123})->status_is(400)->json_is('/errors/0/message', 'Missing property.')
  ->json_is('/errors/0/path', '/name');

# invalid input
$t->post_ok('/api/pets' => form => {id => "invalid", name => "kit-cat"})->status_is(400)
  ->json_is('/errors/0/message', 'Expected integer - got string.')->json_is('/errors/0/path', '/id');

# valid input and output
$t::Api::RES = [{id => 123, name => "kit-cat"}];
$t->post_ok('/api/pets' => form => {id => 123, name => "kit-cat"})->status_is(200)->json_is('/0/id', 123);

# do it again to check if clobbered
$t->post_ok('/api/pets' => form => {id => 123, name => "kit-cat"})->status_is(200)->json_is('/0/id', 123);

done_testing;
