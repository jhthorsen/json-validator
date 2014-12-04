use Mojo::Base -strict;
use Test::More;
use Swagger2;
use File::Spec::Functions 'catfile';

my $swagger = Swagger2->new;

isa_ok($swagger->url, 'Mojo::URL');
is $swagger->url, '', 'no url set';
is $swagger->load(catfile qw( t data petstore.json )), $swagger, 'load()';
is $swagger->tree->get('/swagger'), '2.0', 'tree.swagger';

like $swagger->to_string, qr{"summary":"finds pets in the system"}, 'to_string';
like $swagger->to_string('json'), qr{"summary":"finds pets in the system"}, 'to_string json';

done_testing;
