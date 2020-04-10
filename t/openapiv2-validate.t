use lib '.';
use Mojo::Base -strict;
use t::OpenApiApp;
use JSON::Validator::Schema::OpenAPIv2;
use Test::More;
use Test::Mojo;

my $app = t::OpenApiApp->new->schema(
  JSON::Validator::Schema::OpenAPIv2->new->data(
    Mojo::File->new(__FILE__)->dirname->child(qw(spec v2-petstore.json))
  )
);

my %res;
$app->hook(
  make_response => sub {
    my ($c, $res) = @_;
    $res->{$_} = $res{$_} for keys %res;
    %res = ();
  }
);

my $t   = Test::Mojo->new($app);
my $cat = {id => 42, name => 'Goma'};

$res{headers}{'x-next'} = '/pets?page=1';
$res{openapi} = $cat;
$t->get_ok('/pets')->status_is(200)
  ->json_is('/req',        [{exists => 1, name => 'limit', value => 20}])
  ->json_is('/req_errors', [])->json_is('/res', $cat)
  ->json_is('/res_errors',
  [{path => '/body', message => 'Expected array - got object.'}]);

$res{openapi} = [$cat];
$t->get_ok('/pets')->status_is(200)->json_is('/res', [$cat])
  ->json_is('/res_errors', []);

$res{openapi} = {code => 42};
$t->get_ok('/pets?status=500')->status_is(500)
  ->json_is('/res_errors',
  [{path => '/body/message', message => 'Missing property.'}]);

$t->get_ok('/pets?limit=foo')->status_is(200)->json_is('/req', undef)
  ->json_is('/req_errors',
  [{path => '/limit', message => 'Expected integer - got string.'}])
  ->json_is('/res_errors', []);

$t->post_ok('/pets?status=201')->json_is('/req', undef)
  ->json_is('/req_errors', [{path => '/body', message => 'Missing property.'}])
  ->json_is('/res_errors', []);

$t->post_ok('/pets?status=201', json => {id => 42})->json_is('/req', undef)
  ->json_is('/req_errors',
  [{path => '/body/name', message => 'Missing property.'}])
  ->json_is('/res_errors', []);

$t->post_ok('/pets?status=201', json => $cat)->json_is(
  '/req',
  [{
    content_type => 'application/json',
    exists       => 1,
    name         => 'body',
    value        => $cat,
  }]
)->json_is('/req_errors', [])->json_is('/res_errors', []);

$t->get_ok('/pets/42')
  ->json_is('/req', [{exists => 1, name => 'petId', value => '42'}])
  ->json_is('/req_errors', [])->json_is('/res_errors', []);

done_testing;
