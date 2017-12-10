use Mojo::Base -strict;
use JSON::Validator::OpenAPI;
use Mojolicious;
use Test::More;

my $validator = JSON::Validator::OpenAPI->new;
$validator->ua->server->app(Mojolicious->new);
$validator->ua->server->app->routes->get(
  '/api' => sub {
    my $c = shift;
    $c->render(
      json => {
        swagger => $c->param('fail') ? undef : '2.0',
        info     => {version => '0.8', title => 'Test client spec'},
        schemes  => ['http'],
        host     => 'api.example.com',
        basePath => '/v1',
        paths    => {},
      }
    );
  }
);

eval { $validator->load_and_validate_schema('/api') };

# Some CPAN testers says: [JSON::Validator] GET http://127.0.0.1:61594/api == Service Unavailable at JSON/Validator.pm line 274.
plan skip_all => $@ if $@ =~ /Service Unavailable/i;
is $@, '', 'loaded valid schema from app';

eval { $validator->load_and_validate_schema('/api?fail=1') };
like $@, qr{got null}, 'loaded invalido schema from app';

done_testing;
