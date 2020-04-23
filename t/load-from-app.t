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

is $jv->{schemas}{'/spec'}{title}, 'A JSON Schema for Swagger 2.0 API.',
  'registered this schema for reuse';

is $jv->{schemas}{'http://swagger.io/v2/schema.json'}{title},
  'A JSON Schema for Swagger 2.0 API.',
  'registered this referenced schema for reuse';

is $jv->{schemas}{'http://json-schema.org/draft-04/schema'}{description},
  'Core schema meta-schema', 'registered this referenced schema for reuse';

done_testing;
