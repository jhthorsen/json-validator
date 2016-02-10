use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;
use t::Api;

plugin Swagger2 => {url => 't/data/petstore.json'};
hook around_action => sub {
  my ($next, $c) = @_;
  $c->stash(petId => 'will_not_change_id_from_path');
  $next->();
};

my $t = Test::Mojo->new;

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

# Allow negative integers in query string
$t->get_ok('/api/pets?limit=-100')->status_is(200);

$t::Api::RES = {name => "kit-cat"};
$t->post_ok('/api/pets/42')->status_is(200)->json_is('/id', 42)->json_is('/name', 'kit-cat');

$t->post_ok('/api/pets/foo')->status_is(400)->json_is('/errors/0/path', '/petId')
  ->json_is('/errors/0/message', 'Expected integer - got string.')->json_is('/errors/1', undef);

$t->get_ok('/api')->status_is(200)->json_is('/info/title', 'Swagger Petstore');
my $api_spec = $t->tx->res->json;
like $api_spec->{host}, qr{:\d+$}, 'petstore.swagger.wordnik.com is replaced';
ok !exists $api_spec->{'id'}, 'no id in expanded spec';
ok !exists $api_spec->{'paths'}{'/pets'}{'x-mojo-controller'},    'no x-mojo-controller in expanded spec';
ok !exists $api_spec->{'paths'}{'/pets'}{'x-mojo-around-action'}, 'no x-mojo-around-action in expanded spec';

{
  local $TODO = 'Should rendered spec contain x-mojo-?';
  $t->json_is('/paths/~1pets/get/x-mojo-controller', 't::Api');
}

done_testing;
