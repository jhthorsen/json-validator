use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;
BEGIN { $ENV{SWAGGER2_YAML_MODULE} = 'YAML::Tiny' }
use t::Api;

plan skip_all => 'Could not load YAML::Tiny' unless eval 'require YAML::Tiny;1';

plugin Swagger2 => {controller => 't::Api', url => 't/data/petstore.yaml'};

# this test checks that "require: false" is indeed false

my $t = Test::Mojo->new;
ok $t->app->routes->lookup('list_pets'), 'add route list_pets';

$t::Api::RES = [{id => 123, name => "kit-cat"}];
$t->get_ok('/v1/pets')->status_is(200)->json_is('/0/id', 123)->json_is('/0/name', 'kit-cat');

done_testing;
