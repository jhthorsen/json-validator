use Mojo::Base -strict;
use JSON::Validator;
use Mojolicious;
use Test::More;

my $jv = JSON::Validator->new;
$jv->ua->server->app(Mojolicious->new);
$jv->ua->server->app->log(Mojo::Log->new->level('fatal'));
$jv->ua->server->app->routes->get(
  '/spec' => sub {
    my $c = shift;
    die 'not cached' if $c->stash('from_cache');
    $c->render(json => {'$ref' => 'http://swagger.io/v2/schema.json'});
  }
);

# Some CPAN testers says "Service Unavailable"
eval { $jv->schema('/spec') };
plan skip_all => $@ if $@ =~ /\sGET\s/i;

is $jv->store->ua, $jv->ua, 'shared ua';
is $@, '', 'loaded schema from app';
is $jv->get('/properties/swagger/enum/0'), '2.0', 'loaded schema structure';

is_deeply [sort keys %{$jv->store->schemas}],
  ['/spec', 'http://json-schema.org/draft-04/schema', 'http://swagger.io/v2/schema.json'], 'schemas in store';

$jv->ua->server->app->defaults(from_cache => 1);
ok $jv->schema('/spec'), 'loaded from cache';

$jv->store->schemas({});
eval { $jv->schema('/spec') };
like $@, qr{Internal Server Error}, 'cache cleared';

done_testing;
