use t::Api;
use Swagger2::Client;
use Test::More;

use Mojolicious::Lite;
app->log->level('error') unless $ENV{HARNESS_IS_VERBOSE};
plugin Swagger2 => {url => 't/data/petstore.json'};

my $client = Swagger2::Client->generate('t/data/petstore.json');
my $ua     = app->ua;
my $err;

isa_ok($client->base_url, 'Mojo::URL');
isa_ok($client->ua,       'Mojo::UserAgent');
isa_ok($client->_swagger, 'Swagger2');
can_ok($client, qw( list_pets listPets ));

is $client->base_url, 'http://petstore.swagger.wordnik.com/api', 'base_url';
$client->ua($ua);

# sync
$client->base_url->host($ua->server->url->host);
$client->base_url->port($ua->server->url->port);

$t::Api::RES = [{id => 123, name => "kit-cat"}];
my $res = $client->list_pets;
is_deeply($res->json, [{id => 123, name => "kit-cat"}], 'list_pets ok');

eval { $client->list_pets({limit => 'foo'}) };
like $@, qr{^Invalid input: /limit: Expected integer - got string}, 'list_pets invalid input';

$t::Api::RES = [{id => 'foo', name => "kit-cat"}];
eval { $client->list_pets };
like $@, qr{^Internal Server Error:.*"path":"\W+0\W+id"}, 'list_pets invalid response';

# sync post
$t::Api::RES = {id => 123, name => 'kit-cat'};
eval { $client->add_pet };
like $@, qr{^Invalid input: /data: Expected object - got null}, 'add_pet invalid input';

$res = $client->add_pet({data => {name => 'm4'}});
is $res->json->{name}, 'm4', 'add_pet';

# async
$t::Api::RES = [{id => 123, name => "kit-cat"}];
$client->base_url->host($ua->server->nb_url->host);
$client->base_url->port($ua->server->nb_url->port);

$t::Api::RES = [{id => 123, name => "kit-cat"}];
$client->list_pets(sub { (my $client, $err, $res) = @_; Mojo::IOLoop->stop });
Mojo::IOLoop->start;
is_deeply($res->json, [{id => 123, name => "kit-cat"}], 'list_pets async ok');

$client->list_pets({limit => 'foo'}, sub { (my $client, $err, $res) = @_ });
is_deeply($err, ['/limit: Expected integer - got string.'], 'list_pets async invalid input');
is $res, undef, 'list_pets async invalid input';

$t::Api::RES = [{id => 'foo', name => "kit-cat"}];
$client->list_pets(sub { (my $client, $err, $res) = @_; Mojo::IOLoop->stop });
Mojo::IOLoop->start;
isa_ok($res, 'Mojo::Message::Response');
is $res->json->{errors}[0]{message}, 'Expected integer - got string.', 'errors';
is_deeply($err, 'Internal Server Error', 'list_pets async invalid output');

# with path
$t::Api::RES = {id => 123, name => "kit-cat"};
$client->show_pet_by_id(sub { (my $client, $err, $res) = @_; Mojo::IOLoop->stop });
is_deeply($err, ['/petId: Expected integer - got null.'], 'show_pet_by_id async invalid input');

$client->show_pet_by_id({petId => 0}, sub { (my $client, $err, $res) = @_; Mojo::IOLoop->stop });
Mojo::IOLoop->start;
is_deeply($res->json, {id => 0, name => "kit-cat"}, 'list_pets async ok');

done_testing;
