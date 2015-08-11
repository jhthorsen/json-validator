use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;

my $spec;

{
  use Mojolicious::Lite;
  my $route = app->routes->under->to(
    cb => sub {
      my $c = shift;
      $spec = $c->stash('swagger');
      return 1 if $c->param('secret');
      return $c->render(json => {error => {code => 401, message => "Not authenticated"}}, status => 401);
    }
  );
  plugin Swagger2 => {url => 't/data/petstore.json', route => $route};
}

my $t = Test::Mojo->new;

$t->get_ok('/api/pets')->status_is(401)->json_is('/error/message', 'Not authenticated');

isa_ok($spec, 'Swagger2');
is $spec->tree->get('/info/title'), 'Swagger Petstore', 'got swagger';

$t::Api::RES = [{id => 123, name => "kit-cat"}];
$t->get_ok('/api/pets?secret=whatever')->status_is(200)->json_is('/0/id', 123)->json_is('/0/name', 'kit-cat');

done_testing;
