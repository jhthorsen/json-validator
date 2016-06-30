use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use Mojo::JSON qw(false true);
use Mojolicious::Controller;
use JSON::Validator::OpenAPI;

my $t = Test::Mojo->new;
my $c = Mojolicious::Controller->new(tx => Mojo::Transaction::HTTP->new);

my $openapi = JSON::Validator::OpenAPI->new;
my $status  = 200;
my ($req, $schema, @errors, $input);

$schema = {responses => {200 => {}}};
is_deeply [$openapi->validate_response($c, $schema, 200, {})], [], 'valid';

done_testing;
