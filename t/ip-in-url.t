use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;

plugin Swagger2 => {url => 't/data/ip-in-url.json'};

my $t = Test::Mojo->new;
$t->get_ok('/ip/1.2.3.4/stuff')->status_is(200)->json_is('/ip', '1.2.3.4');

done_testing;
