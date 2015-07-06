use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

use lib 't/blog/lib';

# RUN=1 BLOG_PG_URL=postgresql://username@/test perl t/blog.t daemon
if ($ENV{RUN}) {
  require Mojolicious::Commands;
  Mojolicious::Commands->start_app('Blog');
  exit;
}

plan skip_all => $@ unless my $t = eval { Test::Mojo->new('Blog') };

$t->app->pg->migrations->migrate(0)->migrate unless $ENV{KEEP_DATABASE};
$t->get_ok('/')->status_is(302);

$t->get_ok('/api/posts')->content_is('[]');

$t->post_ok('/api/posts', json => {title => 'test 123', body => undef})->status_is(400)
  ->json_is('/errors/0/message', 'Expected string - got null.')->json_is('/errors/0/path', '/entry/body');
$t->post_ok('/api/posts', json => {title => 'test 123', body => 'Cool blog post!'})->status_is(200)
  ->json_like('/id', qr{\d+});

my $id = $t->tx->res->json->{id};
$t->get_ok("/api/posts/$id")->status_is(200)->json_is('/title', 'test 123')->json_is('/body', 'Cool blog post!');
$t->get_ok('/api/posts')->status_is(200)->json_is('/0/title', 'test 123')->json_is('/0/body', 'Cool blog post!');

$t->put_ok("/api/posts/$id", json => {title => 'foo', body => 'Still awesome'})->status_is(200)->content_is('{}');

$t->delete_ok("/api/posts/$id")->status_is(200)->content_is('{}');
$t->get_ok("/api/posts/$id")->status_is(404)->json_is('/errors/0/message', 'Blog post not found.')
  ->json_is('/errors/0/path', '/id');

done_testing;
