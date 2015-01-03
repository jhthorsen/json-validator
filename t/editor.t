use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions 'catfile';

plan skip_all => 'http://www.cpantesters.org/cpan/report/bd54f97b-7e00-1014-8144-e0ed229b6c94' if $^O eq 'Win32';

$ENV{MOJO_APP_LOADER}  = 1;
$ENV{SWAGGER_API_FILE} = catfile qw( t data petstore.json );
my $t = Test::Mojo->new('Swagger2::Editor');

$t->get_ok('/')->status_is(200)->text_is('title', 'Swagger2 - Editor')->element_exists('#editor')
  ->element_exists('#preview')->element_exists('#preview .pod-container')->element_exists('h2#showPetById')
  ->text_is('h2#showPetById', 'showPetById')->content_like(qr{xhr\.open\("POST", "/", true\);});

$t->post_ok('/', '{"info":{"version":42}}')->status_is(200)->content_like(qr{<p>42</p>});

done_testing;
