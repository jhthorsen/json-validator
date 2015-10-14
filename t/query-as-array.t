use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;
use t::Api;

plugin Swagger2 => {url => 't/data/query-as-array.json'};

my $t = Test::Mojo->new;

$t->get_ok('/array?foo=1,2,3')->status_is(200)->json_is('/foo', [1, 2, 3]);
$t->get_ok('/array?foo=1')->status_is(200)->json_is('/foo', [1]);

done_testing;
