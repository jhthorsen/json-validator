use Mojo::Base -strict;
use Test::More;
use Swagger2;

my $swagger = Swagger2->new;
isa_ok($swagger->url,      'Mojo::URL');
isa_ok($swagger->base_url, 'Mojo::URL');
isa_ok($swagger->tree,     'Mojo::JSON::Pointer');
isa_ok($swagger->ua,       'Mojo::UserAgent');
is $swagger->url, '', 'no default url';

$swagger = Swagger2->new('http://example.com/api-spec');
is $swagger->url, 'http://example.com/api-spec', 'url from new()';

done_testing;
