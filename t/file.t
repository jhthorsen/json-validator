use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;

plugin Swagger2 => {url => 't/data/pod-as-string.json'};

my $t = Test::Mojo->new;
$t->get_ok('/api/file-example')->status_is(404);
$t->post_ok('/api/file-example')->status_is(200)->content_like(qr{This response contains raw binary or text data});

done_testing;
