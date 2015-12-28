use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

plan skip_all => 'Skipping editor test on Win32' if $^O eq 'Win32';

$ENV{MOJO_APP_LOADER}  = 1;
$ENV{SWAGGER_API_FILE} = 't/data/petstore.json';

plan skip_all => 'Cannot read/write petstore.json' unless -w $ENV{SWAGGER_API_FILE};

my $t = Test::Mojo->new('Swagger2::Editor');

$t->get_ok('/')->status_is(200)->text_is('title', 'Swagger2 - Editor')->element_exists('#editor')
  ->element_exists('#preview')->element_exists('#preview .pod-container')->element_exists('h2#showPetById')
  ->element_exists('script[src="ace.js"]')->text_is('h2#showPetById a', 'showPetById')
  ->content_like(qr{xhr\.open\("POST", "/", true\);});

my $spec = Mojo::Util::slurp($ENV{SWAGGER_API_FILE});
$spec =~ s!"1\.0\.0"!"42"!;
$t->post_ok('/', $spec)->status_is(200)->content_like(qr{<p>42</p>});

# "git checkout t/data/petstore.json"
$spec =~ s!"42"!"1.0.0"!;
$t->post_ok('/', $spec)->status_is(200);

done_testing;
