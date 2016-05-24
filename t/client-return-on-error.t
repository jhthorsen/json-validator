use t::Api;
use Swagger2::Client;
use Test::More;

use Mojolicious::Lite;
app->log->level('error') unless $ENV{HARNESS_IS_VERBOSE};
plugin Swagger2 => {url => 't/data/petstore.json'};

my $client = Swagger2::Client->generate('t/data/petstore.json');
my $ua     = app->ua;

# sync
$client->ua($ua);
$client->base_url->host($ua->server->url->host);
$client->base_url->port($ua->server->url->port);

my $res = $client->return_on_error(1)->add_pet;

is $res->code, 400, 'blocking 400';
is $res->json->{errors}[0]{message}, 'Expected object - got null.', 'expected';
is $res->headers->content_type, 'application/json',
    'Content type set to application/json';
    
$t::Api::RES = {};
$res = $client->show_pet_by_id({petId => 42});
is $res->code, 500, 'blocking 500';
is $res->json->{errors}[0]{message}, 'Missing property.', 'missing';

done_testing;
