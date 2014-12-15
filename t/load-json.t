use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions 'catfile';
use Swagger2;

my $json_file = catfile qw( t data petstore.json );
my $swagger   = Swagger2->new;

plan skip_all => "Cannot read $json_file" unless -r $json_file;

is $swagger->url, '', 'no url set';
is $swagger->base_url, 'http://example.com/', 'no base_url set';
is $swagger->load('t/data/petstore.json'), $swagger, 'load()';
is $swagger->tree->get('/swagger'), '2.0', 'tree.swagger';
is $swagger->url, 't/data/petstore.json', 'url';
is $swagger->base_url, 'http://petstore.swagger.wordnik.com/api', 'base_url';

like $swagger->to_string, qr{"summary":"finds pets in the system"}, 'to_string';
like $swagger->to_string('json'), qr{"summary":"finds pets in the system"}, 'to_string json';

use Mojolicious::Lite;
get '/api-spec' => sub { shift->render(format => 'json', text => Mojo::Util::slurp($json_file)); };
my $t          = Test::Mojo->new;
my $server_url = $t->ua->server->url('http');
$swagger = Swagger2->new;
$swagger->ua($t->ua);
$swagger->load($server_url->path('/api-spec')->to_abs);
is $swagger->base_url, 'http://petstore.swagger.wordnik.com/api', 'loaded from server';

done_testing;
