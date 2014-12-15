use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions 'catfile';
use Swagger2;

my $json_file = catfile qw( t data petstore.json );
my $swagger   = Swagger2->new;

plan skip_all => "Cannot read $json_file" unless -r $json_file;

is $swagger->parse(Mojo::Util::slurp($json_file)), $swagger, 'load()';
is $swagger->tree->get('/swagger'), '2.0', 'tree.swagger';
is $swagger->url, 'http://127.0.0.1/#', 'url';
is $swagger->base_url, 'http://petstore.swagger.wordnik.com/api', 'base_url';

like $swagger->to_string, qr{"summary":"finds pets in the system"}, 'to_string';
like $swagger->to_string('json'), qr{"summary":"finds pets in the system"}, 'to_string json';

done_testing;
