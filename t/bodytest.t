use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Test::Warnings;
use File::Spec::Functions;
use t::Api;

my $json_file = 't/data/bodytest.json';

use Mojolicious::Lite;
plugin Swagger2 => {controller => 't::Api', url => $json_file};

my $t = Test::Mojo->new;
ok $t->app->routes->lookup('add_pet'),    'add route add_pet';
ok $t->app->routes->lookup('update_pet'), 'add route update_pet';

$t::Api::RES = {id => "123", name => "kit-cat"};
$t->post_ok('/api/pets' => json => $t::Api::RES)->status_is(200)->json_is('/id', '123')->json_is('/name', 'kit-cat');

# do it again to check if clobbered
$t->post_ok('/api/pets' => json => $t::Api::RES)->status_is(200)->json_is('/id', '123')->json_is('/name', 'kit-cat');

$t::Api::RES = {id => "123", name => "kit-cat"};
$t->put_ok('/api/pets' => json => $t::Api::RES)->status_is(200)->json_is('/id', '123')->json_is('/name', 'kit-cat');

done_testing;
