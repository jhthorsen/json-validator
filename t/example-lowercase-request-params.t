use Mojo::Base -strict;
use Test::Mojo;
use Test::More;
use t::Api;

use Mojolicious::Lite;
plugin Swagger2 => {url => 't/data/petstore.json'};

# This is just an example of a hook to "normalize" all
# the input parameters.
hook before_routes => sub {
  my $c = shift;

  for my $m (qw(body_params query_params)) {
    my $p = $c->req->$m;
    $p->param(lc $_ => $p->param($_)) for @{$p->names};    # normalize
  }
};

my $t = Test::Mojo->new;

# both "LiMIt" and "limit" are now acceptable
$t->get_ok('/api/pets?LiMIt=foo')->status_is(400)->json_is('/errors/0/path', '/limit')
  ->json_is('/errors/0/message', 'Expected integer - got string.');

done_testing;
