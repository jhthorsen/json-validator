use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Test::Warnings;
use File::Spec::Functions;

my $json_file = catfile qw( t data bodytest.yaml );

use Mojolicious::Lite;
plugin Swagger2 => {controller => 't::Api', url => $json_file};

my $t = Test::Mojo->new;
ok $t->app->routes->lookup('add_pet_post'), 'add route add_pet_post';
ok $t->app->routes->lookup('update_pet_put'), 'add route update_pet_put';

$t::Api::RES = {id => "123", name => "kit-cat"};
$t->post_ok('/api/pets' => json => $t::Api::RES)->status_is(200)->json_is('/id', '123')
  ->json_is('/name', 'kit-cat');

# do it again to check if clobbered
$t->post_ok('/api/pets' => json => $t::Api::RES)->status_is(200)->json_is('/id', '123')
  ->json_is('/name', 'kit-cat');

$t::Api::RES = {id => "123", name => "kit-cat"};
$t->put_ok('/api/pets' => json => $t::Api::RES)->status_is(200)->json_is('/id', '123')
  ->json_is('/name', 'kit-cat');

done_testing;
