use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions 'catfile';

$ENV{MOJO_APP_LOADER}  = 1;
$ENV{SWAGGER_API_FILE} = catfile qw( t data petstore.json );
my $t = Test::Mojo->new(require Mojolicious::Command::swagger2);

$t->get_ok('/')->status_is(200)->text_is('title', 'Edit petstore')->element_exists('#editor')
  ->element_exists('#preview')->element_exists('#preview .pod-container')->element_exists('h2#showPetById')
  ->text_is('h2#showPetById', 'showPetById')->content_like(qr{xhr\.open\("POST", "/perldoc/petstore", true\);});

$t->post_ok('/perldoc/petstore', '{"info":{"version":42}}')->status_is(200)->content_like(qr{<p>42</p>});

done_testing;
