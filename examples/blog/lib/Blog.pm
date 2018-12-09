package Blog;
use Mojo::Base 'Mojolicious';

use Blog::Model::Posts;
use Mojo::ByteStream;

sub startup {
  my $self = shift;

  # Configuration
  $self->secrets([$ENV{BLOG_SECRET} || $^T]);

  # Model
  my $storage
    = $ENV{BLOG_STORAGE} ? Mojo::File->new($ENV{BLOG_STORAGE}) : $self->home->child('posts');
  $self->helper(posts => sub { state $posts = Blog::Model::Posts->new(storage => $storage) });

  $self->helper(markdown => \&_helper_poor_mans_markdown);

  # Controller
  my $r = $self->routes;
  $r->get('/' => sub { shift->redirect_to('posts') });
  $r->get('/posts')->to('posts#index');
  $r->get('/posts/create')->to('posts#create')->name('create_post');
  $r->post('/posts')->to('posts#store')->name('store_post');
  $r->get('/posts/:id')->to('posts#show')->name('show_post');
  $r->get('/posts/:id/edit')->to('posts#edit')->name('edit_post');
  $r->post('/posts/:id')->to('posts#update')->name('update_post');
  $r->delete('/posts/:id')->to('posts#remove')->name('remove_post');
}

sub _helper_poor_mans_markdown {
  my $c = shift;

  return Mojo::ByteStream->new(
    join '',
    map {
      my $tag = s!^\s*#\s+!! ? 'h2' : 'p';
      s!(https?://)(\S+)!<a href="$1$2">$2</a>!sg;
      "<$tag>$_</$tag>"
    } split /\n\n/,
    $_[0]
  );
}

1;
