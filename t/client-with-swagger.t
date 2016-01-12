use t::Api;
use Swagger2::Client;
use Test::More;

my $client = Swagger2::Client->generate(Swagger2->new('t/data/petstore.json'));

use Mojolicious::Lite;
app->log->level('error') unless $ENV{HARNESS_IS_VERBOSE};
plugin Swagger2 => {url => 't/data/petstore.json'};

isa_ok($client->base_url, 'Mojo::URL');
isa_ok($client->ua,       'Mojo::UserAgent');
isa_ok($client->_swagger, 'Swagger2');
can_ok($client, qw( list_pets listPets ));

is $client->base_url, 'http://petstore.swagger.wordnik.com/api', 'base_url';
$client->ua(app->ua);

# sync
$client->base_url->host($client->ua->server->url->host);
$client->base_url->port($client->ua->server->url->port);

$t::Api::RES = {id => 123, name => "kit-cat"};
my $res = $client->showPetById({petId => 42});
is_deeply($res->json, {id => 42, name => "kit-cat"}, 'list_pets async ok');

done_testing;
