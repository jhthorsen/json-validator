use Mojo::Base -strict;

use Mojo::JSON qw(true false);
use Test::Mojo;
use Test::More;

$ENV{BLOG_STORAGE} = Mojo::File->new('testing')->to_string;
my $t = Test::Mojo->new('Blog');

# No posts yet
$t->get_ok('/')->status_is(302);
$t->get_ok($t->tx->res->headers->location)->status_is(200)
  ->text_is('title' => 'Blog')->text_is('a.btn-primary' => 'New post')
  ->text_is('h2', 'No posts');

# Invalid input
$t->post_ok('/posts.json' => json => {})->status_is(400)
  ->json_is('/errors/0/path', '/author')->json_is('/errors/1/path', '/body')
  ->json_is('/errors/2/path', '/published')
  ->json_is('/errors/3/path', '/title');

# Create a new post
$t->get_ok('/posts/create')->status_is(200)->text_is('title' => 'New post')
  ->element_exists('form input[name=title]')
  ->element_exists('form textarea[name=body]');
$t->post_ok(
  '/posts.json' => json => {
    author    => 'jhthorsen@cpan.org',
    published => false,
    title     => 'Testing',
    body      => 'This is a test.'
  }
)->status_is(200)->json_has('/id');

# Read the post
my $id = $t->tx->res->json->{id} or die 'Something is seriously wrong';
$t->get_ok("/posts/$id")->status_is(200)->text_is('title' => 'Testing')
  ->text_is('article h1' => 'Testing')
  ->text_like('article p' => qr/This is a test/)->text_is('.btn' => 'Edit');
$t->get_ok("/posts/$id.json")->status_is(200)
  ->json_is('/author', 'jhthorsen@cpan.org')->json_is('/id', $id)
  ->json_is('/title', 'Testing')->json_like('/body', qr{This is a test})
  ->content_like(qr{"published":false\b});
$t->get_ok('/posts.json')->status_is(200)
  ->json_is('/posts/0/author', 'jhthorsen@cpan.org')
  ->json_is('/posts/0/id', $id)->json_is('/posts/0/title', 'Testing')
  ->json_like('/posts/0/body', qr{This is a test});

# Update the post
$t->get_ok("/posts/$id/edit")->status_is(200)->text_is('title' => 'Edit post')
  ->element_exists('form input[name=title][value=Testing]')
  ->text_like('form textarea[name=body]' => qr/This is a test/);
$t->post_ok(
  "/posts/$id.json" => json => {
    author    => 'jhthorsen@cpan.org',
    published => true,
    title     => 'Again',
    body      => 'It works.'
  }
)->status_is(200);
$t->get_ok("/posts/$id.json")->status_is(200)
  ->json_is('/author', 'jhthorsen@cpan.org')->json_is('/id', $id)
  ->json_is('/title', 'Again')->json_like('/body', qr{It works})
  ->content_like(qr{"published":true\b});
$t->get_ok('/posts')->status_is(200)->text_is('title' => 'Blog')
  ->text_is('article h1 a' => 'Again')->text_like('article p' => qr/It works/);

# Delete the post
$t->delete_ok("/posts/$id.json")->status_is(200)->json_is('/removed', true);
$t->delete_ok("/posts/$id.json")->status_is(200)->json_is('/removed', false);

# Cleanup
Mojo::File->new($ENV{BLOG_STORAGE})->remove_tree;

done_testing;
