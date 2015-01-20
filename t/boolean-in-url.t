use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;
use t::Api;

plugin Swagger2 => {controller => 't::Api', url => 't/data/boolean-in-url.json'};

my $t = Test::Mojo->new;
$t->get_ok('/boolean-in-url/false?q1=true')->status_is(200);
like $t->tx->res->body, qr{"p1":false}, 'p1 false';
like $t->tx->res->body, qr{"q1":true},  'q1 true';

$t->get_ok('/boolean-in-url/true')->status_is(200);
like $t->tx->res->body, qr{"p1":true}, 'p1 true';
like $t->tx->res->body, qr{"q1":null}, 'q1 null';

$t->get_ok('/boolean-in-url/1')->status_is(200);
like $t->tx->res->body, qr{"p1":true}, 'p1 1';

$t->get_ok('/boolean-in-url/0')->status_is(200);
like $t->tx->res->body, qr{"p1":false}, 'p1 0';

done_testing;
