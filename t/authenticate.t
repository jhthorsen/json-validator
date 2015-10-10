use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use t::Api;

my $spec;

{
  use Mojolicious::Lite;
  my $route = app->routes->under('/protected')->to(
    cb => sub {
      my $c = shift;
      $spec = $c->stash('swagger');
      return 1 if $c->param('secret');
      $c->render(json => {error => {code => 401, message => "Not authenticated"}}, status => 401);
      return undef;
    }
  );
  plugin Swagger2 => {url => 't/data/petstore.json', route => $route};
}

my $t = Test::Mojo->new;

$t->get_ok('/protected/pets')->status_is(401)->json_is('/error/message', 'Not authenticated');

$t::Api::RES = [{id => 123, name => "kit-cat"}];
$t->get_ok('/protected/pets?secret=whatever')->status_is(200)->json_is('/0/id', 123)->json_is('/0/name', 'kit-cat');

# fetch expanded specification
is $t->app->url_for('swagger_petstore'), '/protected/68a6b7026f824e06ab539499f1c68732.json', 'spec url';

$t->get_ok('/protected/68a6b7026f824e06ab539499f1c68732.json?secret=whatever')->status_is(200)
  ->json_is('/basePath', '/protected')->json_is('/paths/~1pets/get/parameters/0/in', 'query');

done_testing;
