package Blog;
use Mojo::Base 'Mojolicious';

use Blog::Model::Posts;
use Mojo::Pg;

$ENV{BLOG_PG_URL} ||= 'postgresql://postgres@/test';

sub startup {
  my $self = shift;

  # Configuration
  $self->secrets([split /:/, $ENV{BLOG_SECRETS} || 'super:s3cret']);

  # Model
  $self->helper(pg => sub { state $pg = Mojo::Pg->new($ENV{BLOG_PG_URL}) });
  $self->helper(posts => sub { state $posts = Blog::Model::Posts->new(pg => shift->pg) });

  # Migrate to latest version if necessary
  my $path = $self->home->rel_file('migrations/blog.sql');
  $self->pg->migrations->name('blog')->from_file($path)->migrate;

  # Swagger API endpoints
  # /api             *       api
  #   +/posts        POST    "store"
  #   +/posts        GET     "list"
  #   +/posts/(:id)  PUT     "update"
  #   +/posts/(:id)  DELETE  "remove"
  #   +/posts/(:id)  GET     "show"
  $self->plugin(swagger2 => {url => $self->home->rel_file('api.json')});

  # Regular web pages
  # /                GET
  # /posts           GET     posts
  # /posts/create    GET     "create_post"
  # /posts           POST    "store_post"
  # /posts/:id       GET     "show_post"
  # /posts/:id/edit  GET     "edit_post"
  # /posts/:id       PUT     "update_post"
  # /posts/:id       DELETE  "remove_post"
  my $r = $self->routes;
  $r->get('/' => sub { shift->redirect_to('posts') });
  $r->get('/posts')->to('posts#list');
  $r->get('/posts/create')->to('posts#create')->name('create_post');
  $r->post('/posts')->to('posts#store')->name('store_post');
  $r->get('/posts/:id')->to('posts#show')->name('show_post');
  $r->get('/posts/:id/edit')->to('posts#edit')->name('edit_post');
  $r->put('/posts/:id')->to('posts#update')->name('update_post');
  $r->delete('/posts/:id')->to('posts#remove')->name('remove_post');
}

1;
