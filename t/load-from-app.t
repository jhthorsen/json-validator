use Mojo::Base -strict;
use JSON::Validator;
use Mojolicious;
use Test::More;

my $jv = JSON::Validator->new;
$jv->ua->server->app(Mojolicious->new);
$jv->ua->server->app->routes->get(
  '/spec' => sub {
    shift->render(json => {'$ref' => 'http://swagger.io/v2/schema.json'});
  }
);

# Some CPAN testers says: [JSON::Validator] GET http://127.0.0.1:61594/api == Service Unavailable at JSON/Validator.pm
eval { $jv->schema('/spec') };
plan skip_all => $@ if $@ =~ /\sGET\s/i;

is $@, '', 'loaded schema from app';
is $jv->get('/properties/swagger/enum/0'), '2.0', 'loaded schema structure';

done_testing;
