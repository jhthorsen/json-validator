use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use File::Spec::Functions;
use Mojolicious::Lite;
use t::Api;

plugin Swagger2 => {url => 't/data/not-implemented.json'};

my $t = Test::Mojo->new;

$t->get_ok('/not-implemented')->status_is(501)->json_is('/valid', Mojo::JSON->false)
  ->json_is('/errors/0/message', 'Controller not implemented.')->json_is('/errors/0/path', '/');

eval 'package t::NotImplemented; use Mojo::Base "Mojolicious::Controller"; $INC{"t/NotImplemented.pm"}=1;';
$t->get_ok('/not-implemented')->status_is(501)->json_is('/errors/0/message', 'Method "noOp" not implemented.');

*t::NotImplemented::no_op = sub { my ($c, $args, $cb) = @_; $c->$cb({}); };
$t->get_ok('/not-implemented')->status_is(200)->content_is('{}');

done_testing;
