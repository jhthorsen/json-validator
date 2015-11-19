use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

plan skip_all => 'Fail on Win32' if $^O eq 'MSWin32';

$ENV{MOJO_APP_LOADER}  = 1;
$ENV{SWAGGER_API_FILE} = 't/data/petstore.json';
my $t = Test::Mojo->new('Swagger2::Editor');

$t->get_ok('/')->status_is(200)->text_is('title', 'Swagger2 - Editor')->element_exists('#editor')
  ->element_exists('#preview')->element_exists('#preview .pod-container')->element_exists('h2#showPetById')
  ->element_exists('script[src="ace.js"]')->text_is('h2#showPetById a', 'showPetById')
  ->content_like(qr{xhr\.open\("POST", "/", true\);});

$t->post_ok('/', '{"info":{"version":42}}')->status_is(200)->content_like(qr{<p>42</p>});

done_testing;
