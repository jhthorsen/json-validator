use Mojo::Base -strict;
use Test::More;
use Swagger2;
use File::Spec::Functions 'catfile';

plan skip_all => $@ unless eval { Swagger2::LoadYAML("---\nfoo: bar") };

my $swagger = Swagger2->new;

is $swagger->load('t/data/petstore.yaml'), $swagger, 'load()';
is $swagger->tree->get('/swagger'), '2.0', 'tree.swagger';

like $swagger->to_string('json'), qr{"host":"petstore\.swagger\.wordnik\.com"}, 'to_string json';
like $swagger->to_string('yaml'), qr{\s-\sapplication/json}, 'to_string yaml';

is $swagger->tree->get('/paths/~1pets/post/responses/default/schema/$ref'), 'Error', 'Error ref';
my $expanded = eval { $swagger->expand };
ok $expanded, 'expanded plain $ref';
is $expanded->tree->get('/paths/~1pets/post/responses/default/schema/properties/message/type'), 'string',
  'expanded default response';

done_testing;
