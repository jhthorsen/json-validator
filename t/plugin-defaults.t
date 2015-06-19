use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;
use t::Api;

plugin Swagger2 => {controller => 't::Api', url => 't/data/with-defaults.json'};

my $t = Test::Mojo->new;
$t->get_ok('/ip?x=123')->status_is(200)->json_is('/ip', '1.2.3.4')->json_is('/x', '123');
$t->get_ok('/ip/2.3.4.5')->status_is(200)->json_is('/ip', '2.3.4.5')->json_is('/x', 'xyz');
$t->get_ok('/ip/2345')->status_is(400)->json_is('/ip', undef);

done_testing;
